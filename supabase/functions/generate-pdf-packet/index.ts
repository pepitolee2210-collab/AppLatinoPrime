import { PDFDocument, rgb, StandardFonts } from "npm:pdf-lib@1.17.1";
import { jsonResponse, preflight, readJson } from "../_shared/http.ts";
import { errorStatus, getFunctionContext } from "../_shared/supabase.ts";

type GeneratePdfPacketBody = {
  flatten?: boolean;
  sessionId: string;
};

type FieldMapEntry = {
  answer_key?: string;
  checked_value?: string;
  pdf_field: string | null;
  type: "checkbox" | "choice" | "date" | "text";
};

type FieldMap = {
  fields?: Record<string, FieldMapEntry>;
  manual_fields?: string[];
  packet_kind?: string;
  requires_template_verification?: boolean;
};

type FormDefinition = {
  agency: string;
  form_code: string;
  official_page_source_id: string | null;
  review_requirement: "none" | "recommended" | "required";
  title: string;
};

type FormQuestion = {
  display_order: number;
  label_es: string;
  question_key: string;
};

type FormAnswer = {
  answer: unknown;
  question_key: string;
};

type OfficialSource = {
  title: string;
  url: string;
};

function normalizeDate(value: unknown): string {
  if (typeof value !== "string") return stringifyAnswer(value);

  const isoMatch = value.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!isoMatch) return value;

  return `${isoMatch[2]}/${isoMatch[3]}/${isoMatch[1]}`;
}

function stringifyAnswer(value: unknown): string {
  if (value === null || value === undefined) return "";
  if (typeof value === "boolean") return value ? "Si" : "No";
  if (typeof value === "string") return value;
  if (typeof value === "number") return String(value);
  return JSON.stringify(value);
}

function formatAnswer(value: unknown, config: FieldMapEntry): string {
  if (config.type === "date") return normalizeDate(value);
  return stringifyAnswer(value);
}

function safePdfText(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^\x09\x0a\x0d\x20-\x7e]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

function wrapText(value: string, maxChars: number): string[] {
  const words = safePdfText(value).split(" ").filter(Boolean);
  const lines: string[] = [];
  let current = "";

  for (const word of words) {
    if (!current) {
      current = word;
    } else if (`${current} ${word}`.length <= maxChars) {
      current = `${current} ${word}`;
    } else {
      lines.push(current);
      current = word;
    }
  }

  if (current) lines.push(current);
  return lines.length > 0 ? lines : [""];
}

async function loadOfficialTemplate(
  serviceClient: Awaited<ReturnType<typeof getFunctionContext>>["serviceClient"],
  templatePath: string,
  officialSourceId: string | null
): Promise<Blob> {
  const { data: storedTemplate } = await serviceClient.storage
    .from("official-templates")
    .download(templatePath);

  if (storedTemplate) return storedTemplate;

  if (!officialSourceId) {
    throw new Error("template_missing");
  }

  const { data: source, error: sourceError } = await serviceClient
    .from("official_sources")
    .select("url, authority, source_kind")
    .eq("id", officialSourceId)
    .single();

  if (sourceError || !source || source.authority !== "official" || source.source_kind !== "form_pdf") {
    throw new Error("template_missing");
  }

  const response = await fetch(source.url, {
    headers: {
      "User-Agent": "USA-Latino-Prime/1.0 official-form-sync"
    }
  });

  if (!response.ok) {
    throw new Error("template_missing");
  }

  const contentType = response.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("pdf")) {
    throw new Error("template_missing");
  }

  const templateBytes = new Uint8Array(await response.arrayBuffer());

  await serviceClient.storage
    .from("official-templates")
    .upload(templatePath, templateBytes, {
      contentType: "application/pdf",
      upsert: true
    });

  return new Blob([templateBytes], { type: "application/pdf" });
}

function drawWrappedText(
  page: any,
  text: string,
  options: {
    color?: ReturnType<typeof rgb>;
    font: any;
    lineHeight?: number;
    maxChars: number;
    size: number;
    x: number;
    y: number;
  }
): number {
  const lineHeight = options.lineHeight ?? options.size + 4;
  let y = options.y;

  for (const line of wrapText(text, options.maxChars)) {
    page.drawText(line, {
      x: options.x,
      y,
      size: options.size,
      font: options.font,
      color: options.color ?? rgb(0.08, 0.14, 0.18)
    });
    y -= lineHeight;
  }

  return y;
}

async function createSummaryPacketPdf(params: {
  answers: FormAnswer[];
  definition: FormDefinition;
  officialSource: OfficialSource | null;
  questions: FormQuestion[];
  reviewRequired: boolean;
  warnings: Array<{ field: string; reason: string }>;
}): Promise<{ pageCount: number; pdfBytes: Uint8Array }> {
  const pdfDoc = await PDFDocument.create();
  const regularFont = await pdfDoc.embedFont(StandardFonts.Helvetica);
  const boldFont = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
  const pageSize: [number, number] = [612, 792];
  const marginX = 54;
  const bottomY = 54;
  let page = pdfDoc.addPage(pageSize);
  let y = 742;

  const addPageIfNeeded = (needed = 34) => {
    if (y - needed >= bottomY) return;
    page = pdfDoc.addPage(pageSize);
    y = 742;
  };

  const draw = (
    text: string,
    options: {
      color?: ReturnType<typeof rgb>;
      font?: any;
      indent?: number;
      lineHeight?: number;
      size?: number;
    } = {}
  ) => {
    const size = options.size ?? 10;
    const x = marginX + (options.indent ?? 0);
    const maxChars = Math.max(24, Math.floor((pageSize[0] - x - marginX) / (size * 0.52)));
    addPageIfNeeded(size + 8);
    y = drawWrappedText(page, text, {
      x,
      y,
      size,
      maxChars,
      font: options.font ?? regularFont,
      color: options.color,
      lineHeight: options.lineHeight
    });
  };

  page.drawRectangle({
    x: 0,
    y: 716,
    width: pageSize[0],
    height: 76,
    color: rgb(0.0, 0.24, 0.34)
  });

  y = 754;
  draw("USA Latino Prime", { font: boldFont, size: 17, color: rgb(1, 1, 1), lineHeight: 19 });
  draw("Paquete de preparacion y revision", { size: 10, color: rgb(0.78, 0.94, 0.95) });
  y = 692;

  draw(`${params.definition.form_code} - ${params.definition.title}`, { font: boldFont, size: 15, lineHeight: 19 });
  draw(`Agencia: ${params.definition.agency}`, { size: 10 });
  draw(`Generado: ${new Date().toISOString()}`, { size: 9, color: rgb(0.38, 0.45, 0.5) });

  if (params.officialSource) {
    draw(`Fuente oficial: ${params.officialSource.title} - ${params.officialSource.url}`, {
      size: 9,
      color: rgb(0.04, 0.39, 0.46)
    });
  }

  if (params.definition.form_code === "ANNUAL_ASYLUM_FEE") {
    draw("Accion oficial: completar el pago en my.uscis.gov con A-Number y numero de recibo I-589.", {
      font: boldFont,
      size: 10,
      color: rgb(0.02, 0.36, 0.31)
    });
  }

  if (params.reviewRequired) {
    draw("Estado: requiere revision humana antes de usar este paquete.", {
      font: boldFont,
      size: 10,
      color: rgb(0.73, 0.27, 0.0)
    });
  }

  y -= 10;
  draw("Aviso operativo", { font: boldFont, size: 12 });
  draw(
    "Este PDF organiza respuestas del usuario y fuentes oficiales. No es asesoria legal y no reemplaza la presentacion, firma o pago en el canal gubernamental correspondiente.",
    { size: 9, color: rgb(0.33, 0.4, 0.45) }
  );

  y -= 8;
  draw("Respuestas guardadas", { font: boldFont, size: 12 });

  const answerByKey = new Map(params.answers.map((answer) => [answer.question_key, answer.answer]));
  const questionKeys = new Set(params.questions.map((question) => question.question_key));
  const orderedRows = params.questions
    .slice()
    .sort((a, b) => a.display_order - b.display_order)
    .filter((question) => answerByKey.has(question.question_key))
    .map((question) => ({
      key: question.question_key,
      label: question.label_es,
      answer: answerByKey.get(question.question_key)
    }));

  const extraRows = params.answers
    .filter((answer) => !questionKeys.has(answer.question_key))
    .map((answer) => ({
      key: answer.question_key,
      label: answer.question_key,
      answer: answer.answer
    }));

  const rows = [...orderedRows, ...extraRows];

  if (rows.length === 0) {
    draw("No hay respuestas guardadas todavia.", { size: 10 });
  } else {
    for (const row of rows) {
      addPageIfNeeded(38);
      draw(`${row.label}:`, { font: boldFont, size: 9, lineHeight: 12 });
      draw(stringifyAnswer(row.answer) || "Sin respuesta", { indent: 12, size: 9, lineHeight: 12 });
      y -= 2;
    }
  }

  if (params.warnings.length > 0) {
    y -= 8;
    draw("Advertencias", { font: boldFont, size: 12 });
    for (const warning of params.warnings) {
      draw(`${warning.field}: ${warning.reason}`, { size: 9, color: rgb(0.6, 0.31, 0.0) });
    }
  }

  return {
    pageCount: pdfDoc.getPageCount(),
    pdfBytes: await pdfDoc.save()
  };
}

Deno.serve(async (req) => {
  const cors = preflight(req);
  if (cors) return cors;

  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  try {
    const { serviceClient, user, userClient } = await getFunctionContext(req);
    const body = await readJson<GeneratePdfPacketBody>(req);

    if (!body.sessionId) {
      return jsonResponse({ error: "session_required" }, 400);
    }

    const { data: session, error: sessionError } = await userClient
      .from("form_sessions")
      .select("id, user_id, status, form_edition_id, legal_review_required")
      .eq("id", body.sessionId)
      .single();

    if (sessionError || !session || session.user_id !== user.id) {
      return jsonResponse({ error: "session_not_found" }, 404);
    }

    const { data: edition, error: editionError } = await serviceClient
      .from("form_editions")
      .select("id, edition_label, form_definition_id, pdf_template_path, official_pdf_source_id, field_map")
      .eq("id", session.form_edition_id)
      .single();

    if (editionError || !edition) {
      return jsonResponse({ error: "edition_not_found" }, 404);
    }

    const { data: definition, error: definitionError } = await serviceClient
      .from("form_definitions")
      .select("agency, form_code, official_page_source_id, review_requirement, title")
      .eq("id", edition.form_definition_id)
      .single();

    if (definitionError || !definition) {
      return jsonResponse({ error: "definition_not_found" }, 404);
    }

    let officialSource: OfficialSource | null = null;
    if (definition.official_page_source_id) {
      const { data: source } = await serviceClient
        .from("official_sources")
        .select("title, url")
        .eq("id", definition.official_page_source_id)
        .maybeSingle();
      officialSource = source ?? null;
    }

    const { data: answers, error: answersError } = await userClient
      .from("form_answers")
      .select("question_key, answer")
      .eq("session_id", body.sessionId);

    if (answersError) throw answersError;

    const { data: questions, error: questionsError } = await serviceClient
      .from("form_questions")
      .select("question_key, label_es, display_order")
      .eq("form_edition_id", edition.id)
      .order("display_order", { ascending: true });

    if (questionsError) throw questionsError;

    const fieldMap = (edition.field_map ?? {}) as FieldMap;
    const mappedFields = Object.entries(fieldMap.fields ?? {}).filter(([, config]) => Boolean(config.pdf_field));
    const canFillOfficialPdf =
      session.legal_review_required !== "required" &&
      !fieldMap.requires_template_verification &&
      mappedFields.length > 0 &&
      Boolean(edition.pdf_template_path);

    const warnings: Array<{ field: string; reason: string }> = [];
    let packetKind = "preparation_packet";
    let pageCount = 0;
    let pdfBytes: Uint8Array;
    let signatureRequired = false;

    if (canFillOfficialPdf) {
      try {
        const template = await loadOfficialTemplate(
          serviceClient,
          edition.pdf_template_path!,
          edition.official_pdf_source_id
        );
        const answerByKey = new Map((answers ?? []).map((item) => [item.question_key, item.answer]));
        const pdfDoc = await PDFDocument.load(await template.arrayBuffer(), { ignoreEncryption: true });
        const form = pdfDoc.getForm();

        for (const [questionKey, config] of mappedFields) {
          const pdfFieldName = config.pdf_field;
          if (!pdfFieldName) continue;
          const answerKey = config.answer_key ?? questionKey;

          try {
            if (config.type === "checkbox") {
              const field = form.getCheckBox(pdfFieldName);
              const value = answerByKey.get(answerKey);
              if (
                value === true ||
                value === "true" ||
                value === "yes" ||
                (config.checked_value !== undefined && String(value) === config.checked_value)
              ) {
                field.check();
              } else field.uncheck();
            } else if (config.type === "choice") {
              const field = form.getDropdown(pdfFieldName);
              const value = formatAnswer(answerByKey.get(answerKey), config);
              if (value) field.select(value);
            } else {
              const field = form.getTextField(pdfFieldName);
              field.setText(formatAnswer(answerByKey.get(answerKey), config));
            }
          } catch {
            warnings.push({ field: pdfFieldName, reason: "pdf_field_not_found" });
          }
        }

        if (body.flatten !== false) {
          form.flatten();
        }

        pdfBytes = await pdfDoc.save();
        pageCount = pdfDoc.getPageCount();
        packetKind = "official_pdf";
        signatureRequired = true;
      } catch (officialPdfError) {
        warnings.push({
          field: "official_pdf",
          reason:
            officialPdfError instanceof Error
              ? `official_pdf_generation_failed: ${officialPdfError.message}`
              : "official_pdf_generation_failed"
        });

        const summary = await createSummaryPacketPdf({
          answers: (answers ?? []) as FormAnswer[],
          definition: definition as FormDefinition,
          officialSource,
          questions: (questions ?? []) as FormQuestion[],
          reviewRequired: session.legal_review_required === "required",
          warnings
        });

        pdfBytes = summary.pdfBytes;
        pageCount = summary.pageCount;
        packetKind = "preparation_packet";
        signatureRequired = false;
      }
    } else {
      if (session.legal_review_required === "required") {
        warnings.push({ field: "legal_review", reason: "human_review_required_before_submission" });
      }

      if (fieldMap.requires_template_verification || mappedFields.length === 0) {
        warnings.push({ field: "packet", reason: "official_pdf_mapping_pending" });
      }

      const summary = await createSummaryPacketPdf({
        answers: (answers ?? []) as FormAnswer[],
        definition: definition as FormDefinition,
        officialSource,
        questions: (questions ?? []) as FormQuestion[],
        reviewRequired: session.legal_review_required === "required",
        warnings
      });

      pdfBytes = summary.pdfBytes;
      pageCount = summary.pageCount;
    }

    const storagePath = `${user.id}/${body.sessionId}/packet-${Date.now()}.pdf`;

    const { error: uploadError } = await serviceClient.storage
      .from("generated-packets")
      .upload(storagePath, pdfBytes, {
        contentType: "application/pdf",
        upsert: false
      });

    if (uploadError) throw uploadError;

    const { data: packet, error: packetError } = await serviceClient
      .from("generated_packets")
      .insert({
        user_id: user.id,
        session_id: body.sessionId,
        storage_bucket: "generated-packets",
        storage_path: storagePath,
        packet_type: "pdf",
        page_count: pageCount,
        signature_required: signatureRequired,
        generated_by: packetKind
      })
      .select("id, storage_bucket, storage_path, page_count, generated_at")
      .single();

    if (packetError || !packet) {
      throw packetError ?? new Error("packet_insert_failed");
    }

    const nextStatus =
      session.legal_review_required === "required"
        ? "needs_expert_review"
        : packetKind === "official_pdf"
          ? "ready_to_sign"
          : "exported";

    if (session.legal_review_required === "required") {
      const { data: existingReview } = await serviceClient
        .from("legal_review_requests")
        .select("id")
        .eq("session_id", body.sessionId)
        .limit(1)
        .maybeSingle();

      if (!existingReview) {
        await serviceClient.from("legal_review_requests").insert({
          user_id: user.id,
          session_id: body.sessionId,
          topic: `Revision ${definition.form_code}`,
          urgency: "yellow",
          status: "new",
          notes: "Auto-created when generating a preparation packet for a review-required workflow."
        });
      }
    }

    await serviceClient
      .from("form_sessions")
      .update({ status: nextStatus })
      .eq("id", body.sessionId)
      .eq("user_id", user.id);

    return jsonResponse({ packet, packet_kind: packetKind, next_status: nextStatus, warnings });
  } catch (error) {
    return jsonResponse({ error: error instanceof Error ? error.message : "unknown_error" }, errorStatus(error));
  }
});
