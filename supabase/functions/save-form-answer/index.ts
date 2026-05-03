import { jsonResponse, preflight, readJson } from "../_shared/http.ts";
import { errorStatus, getFunctionContext } from "../_shared/supabase.ts";

type SaveFormAnswerBody = {
  answer: unknown;
  questionKey: string;
  sessionId: string;
};

function isAnswered(value: unknown): boolean {
  if (value === null || value === undefined) return false;
  if (typeof value === "string") return value.trim().length > 0;
  return true;
}

Deno.serve(async (req) => {
  const cors = preflight(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  try {
    const { userClient } = await getFunctionContext(req);
    const body = await readJson<SaveFormAnswerBody>(req);

    if (!body.sessionId || !body.questionKey) {
      return jsonResponse({ error: "session_and_question_required" }, 400);
    }

    const { data: session, error: sessionError } = await userClient
      .from("form_sessions")
      .select("id, form_edition_id, legal_review_required")
      .eq("id", body.sessionId)
      .single();

    if (sessionError || !session) {
      return jsonResponse({ error: "session_not_found" }, 404);
    }

    const { data: question, error: questionError } = await userClient
      .from("form_questions")
      .select("question_key, required")
      .eq("form_edition_id", session.form_edition_id)
      .eq("question_key", body.questionKey)
      .single();

    if (questionError || !question) {
      return jsonResponse({ error: "question_not_found" }, 404);
    }

    const { error: upsertError } = await userClient.from("form_answers").upsert(
      {
        session_id: body.sessionId,
        question_key: body.questionKey,
        answer: body.answer,
        source: "user",
        confirmed_at: new Date().toISOString()
      },
      {
        onConflict: "session_id,question_key"
      }
    );

    if (upsertError) throw upsertError;

    const [{ data: requiredQuestions }, { data: answers }] = await Promise.all([
      userClient
        .from("form_questions")
        .select("question_key")
        .eq("form_edition_id", session.form_edition_id)
        .eq("required", true),
      userClient.from("form_answers").select("question_key, answer").eq("session_id", body.sessionId)
    ]);

    const answeredKeys = new Set(
      (answers ?? []).filter((item) => isAnswered(item.answer)).map((item) => item.question_key)
    );
    const missingFields = (requiredQuestions ?? [])
      .map((item) => item.question_key)
      .filter((questionKey) => !answeredKeys.has(questionKey));

    const requiresReview = body.questionKey === "protected_case_flag" && body.answer === true;
    const nextReview = requiresReview ? "required" : session.legal_review_required;
    const nextStatus = requiresReview ? "needs_expert_review" : missingFields.length > 0 ? "in_progress" : "needs_user_review";

    const { data: updated, error: updateError } = await userClient
      .from("form_sessions")
      .update({
        legal_review_required: nextReview,
        missing_fields: missingFields,
        status: nextStatus,
        current_step: missingFields[0] ?? "review"
      })
      .eq("id", body.sessionId)
      .select("id, status, missing_fields, legal_review_required, current_step")
      .single();

    if (updateError || !updated) {
      throw updateError ?? new Error("session_update_failed");
    }

    return jsonResponse({ session: updated });
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "unknown_error" }, errorStatus(error));
  }
});
