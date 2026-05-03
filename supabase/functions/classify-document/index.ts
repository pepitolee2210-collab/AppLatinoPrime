import { jsonResponse, preflight, readJson } from "../_shared/http.ts";
import { errorStatus, getFunctionContext } from "../_shared/supabase.ts";

type ClassifyDocumentBody = {
  documentId: string;
  fileName?: string;
  ocrText?: string;
};

function classify(text: string): { agency: string; confidence: number; docType: string } {
  const value = text.toLowerCase();

  if (value.includes("i-94") || value.includes("arrival/departure")) {
    return { agency: "CBP", confidence: 0.93, docType: "I94" };
  }

  if (value.includes("i-797") || value.includes("notice of action")) {
    return { agency: "USCIS", confidence: 0.91, docType: "I797C" };
  }

  if (value.includes("i-765") || value.includes("employment authorization")) {
    return { agency: "USCIS", confidence: 0.88, docType: "I765" };
  }

  if (value.includes("notice of hearing") || value.includes("immigration court")) {
    return { agency: "EOIR", confidence: 0.9, docType: "NOTICE_OF_HEARING" };
  }

  if (value.includes("ar-11") || value.includes("alien change of address")) {
    return { agency: "USCIS", confidence: 0.86, docType: "AR11" };
  }

  return { agency: "OTHER", confidence: 0.35, docType: "OTHER" };
}

Deno.serve(async (req) => {
  const cors = preflight(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  try {
    const { serviceClient, user, userClient } = await getFunctionContext(req);
    const body = await readJson<ClassifyDocumentBody>(req);

    if (!body.documentId) {
      return jsonResponse({ error: "document_required" }, 400);
    }

    const { data: document, error: documentError } = await userClient
      .from("user_documents")
      .select("id, user_id, title")
      .eq("id", body.documentId)
      .single();

    if (documentError || !document || document.user_id !== user.id) {
      return jsonResponse({ error: "document_not_found" }, 404);
    }

    const result = classify(`${body.fileName ?? ""}\n${document.title ?? ""}\n${body.ocrText ?? ""}`);

    await serviceClient.from("document_processing_jobs").insert({
      document_id: body.documentId,
      job_type: "classification",
      status: "completed",
      provider: "rules_v1",
      result
    });

    const { data: updated, error: updateError } = await userClient
      .from("user_documents")
      .update({
        agency: result.agency,
        doc_type: result.docType,
        extracted_fields: {
          classifier: "rules_v1",
          confidence: result.confidence
        },
        source_confidence: result.confidence,
        status: result.confidence >= 0.8 ? "classified" : "needs_review"
      })
      .eq("id", body.documentId)
      .select("id, agency, doc_type, status, source_confidence")
      .single();

    if (updateError || !updated) {
      throw updateError ?? new Error("document_update_failed");
    }

    return jsonResponse({ document: updated });
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "unknown_error" }, errorStatus(error));
  }
});
