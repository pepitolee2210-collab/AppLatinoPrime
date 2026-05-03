import { jsonResponse, preflight, readJson } from "../_shared/http.ts";
import { errorStatus, getFunctionContext } from "../_shared/supabase.ts";

type CreateFormSessionBody = {
  caseId?: string | null;
  formCode: string;
  language?: string;
  profileSnapshot?: Record<string, unknown>;
};

Deno.serve(async (req) => {
  const cors = preflight(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  try {
    const { userClient, user } = await getFunctionContext(req);
    const body = await readJson<CreateFormSessionBody>(req);
    const formCode = body.formCode?.trim().toUpperCase();

    if (!formCode) {
      return jsonResponse({ error: "form_code_required" }, 400);
    }

    const { data: definition, error: definitionError } = await userClient
      .from("form_definitions")
      .select("id, agency, form_code, review_requirement")
      .eq("form_code", formCode)
      .eq("enabled", true)
      .single();

    if (definitionError || !definition) {
      return jsonResponse({ error: "form_not_available" }, 404);
    }

    const { data: edition, error: editionError } = await userClient
      .from("form_editions")
      .select("id, edition_label, validation_schema, field_map")
      .eq("form_definition_id", definition.id)
      .eq("status", "active")
      .order("effective_from", { ascending: false })
      .limit(1)
      .single();

    if (editionError || !edition) {
      return jsonResponse({ error: "active_edition_missing" }, 404);
    }

    const { data: session, error: insertError } = await userClient
      .from("form_sessions")
      .insert({
        user_id: user.id,
        case_id: body.caseId ?? null,
        form_edition_id: edition.id,
        status: "in_progress",
        language: body.language ?? "es",
        current_step: "identity",
        profile_snapshot: body.profileSnapshot ?? {},
        legal_review_required: definition.review_requirement
      })
      .select("id, status, legal_review_required, created_at")
      .single();

    if (insertError || !session) {
      throw insertError ?? new Error("session_insert_failed");
    }

    const { data: questions, error: questionsError } = await userClient
      .from("form_questions")
      .select("question_key, label_es, label_en, help_text_es, data_type, required, display_order, validation_rule")
      .eq("form_edition_id", edition.id)
      .order("display_order", { ascending: true });

    if (questionsError) {
      throw questionsError;
    }

    return jsonResponse({
      edition,
      form: definition,
      questions: questions ?? [],
      session
    });
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "unknown_error" }, errorStatus(error));
  }
});
