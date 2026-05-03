import { jsonResponse, preflight, readJson } from "../_shared/http.ts";
import { errorStatus, getFunctionContext } from "../_shared/supabase.ts";

type UscisCaseStatusBody = {
  caseId?: string;
  receiptNumber?: string;
};

Deno.serve(async (req) => {
  const cors = preflight(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  try {
    const { serviceClient, user, userClient } = await getFunctionContext(req);
    const body = await readJson<UscisCaseStatusBody>(req);
    const clientId = Deno.env.get("USCIS_CLIENT_ID");
    const clientSecret = Deno.env.get("USCIS_CLIENT_SECRET");
    const tokenUrl = Deno.env.get("USCIS_TOKEN_URL");
    const statusUrl = Deno.env.get("USCIS_CASE_STATUS_URL");

    if (!clientId || !clientSecret || !tokenUrl || !statusUrl) {
      return jsonResponse({ error: "uscis_api_not_configured" }, 503);
    }

    let receiptNumber = body.receiptNumber?.trim();
    let caseId = body.caseId;

    if (!receiptNumber && caseId) {
      const { data: immigrationCase, error: caseError } = await userClient
        .from("immigration_cases")
        .select("id, user_id, receipt_number")
        .eq("id", caseId)
        .single();

      if (caseError || !immigrationCase || immigrationCase.user_id !== user.id) {
        return jsonResponse({ error: "case_not_found" }, 404);
      }

      receiptNumber = immigrationCase.receipt_number ?? undefined;
    }

    if (!receiptNumber) {
      return jsonResponse({ error: "receipt_number_required" }, 400);
    }

    const tokenResponse = await fetch(tokenUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        grant_type: "client_credentials"
      })
    });

    if (!tokenResponse.ok) {
      return jsonResponse({ error: "uscis_token_failed" }, 502);
    }

    const tokenJson = await tokenResponse.json();
    const accessToken = tokenJson.access_token as string | undefined;

    if (!accessToken) {
      return jsonResponse({ error: "uscis_token_missing" }, 502);
    }

    const statusResponse = await fetch(statusUrl, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ receiptNumber })
    });

    const rawPayload = await statusResponse.json().catch(() => ({}));

    if (!statusResponse.ok) {
      return jsonResponse({ error: "uscis_status_failed", rawPayload }, 502);
    }

    const status = String(rawPayload.status ?? rawPayload.caseStatus ?? "unknown");

    if (caseId) {
      await serviceClient
        .from("immigration_cases")
        .update({
          last_checked_at: new Date().toISOString(),
          status,
          status_source: "USCIS_API"
        })
        .eq("id", caseId)
        .eq("user_id", user.id);

      await serviceClient.from("case_status_snapshots").insert({
        case_id: caseId,
        status,
        source: "USCIS_API",
        raw_payload: rawPayload
      });
    }

    return jsonResponse({
      receiptNumber,
      status,
      source: "USCIS_API"
    });
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "unknown_error" }, errorStatus(error));
  }
});
