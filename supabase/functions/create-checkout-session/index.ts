import { jsonResponse, preflight, readJson } from "../_shared/http.ts";
import { errorStatus, getFunctionContext } from "../_shared/supabase.ts";

type CreateFreeServiceRequestBody = {
  caseId?: string | null;
  serviceType: "ANNUALITY_PAYMENT" | "EXPERT_REVIEW" | "SPECIAL_CASE_TRACKING";
};

Deno.serve(async (req) => {
  const cors = preflight(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  try {
    const { serviceClient, user, userClient } = await getFunctionContext(req);
    const body = await readJson<CreateFreeServiceRequestBody>(req);

    if (!body.serviceType) {
      return jsonResponse({ error: "service_required" }, 400);
    }

    await serviceClient
      .from("profiles")
      .upsert(
        {
          id: user.id,
          email: user.email ?? null,
          preferred_language: "es"
        },
        { onConflict: "id" }
      );

    const { data: service, error: serviceError } = await userClient
      .from("premium_services")
      .select("id, service_type, title, price_mode")
      .eq("service_type", body.serviceType)
      .eq("enabled", true)
      .single();

    if (serviceError || !service) {
      return jsonResponse({ error: "service_not_found" }, 404);
    }

    const { data: requestRow, error: requestError } = await userClient
      .from("premium_service_requests")
      .insert({
        user_id: user.id,
        case_id: body.caseId ?? null,
        service_id: service.id,
        status: service.price_mode === "free" ? "requested_free_test" : "requested",
        amount_cents: 0,
        notes: `Free testing request for ${service.title}`
      })
      .select("id, status, created_at")
      .single();

    if (requestError || !requestRow) {
      throw requestError ?? new Error("premium_request_insert_failed");
    }

    return jsonResponse({
      premiumServiceRequest: requestRow,
      premiumServiceRequestId: requestRow.id,
      priceMode: service.price_mode
    });
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "unknown_error" }, errorStatus(error));
  }
});
