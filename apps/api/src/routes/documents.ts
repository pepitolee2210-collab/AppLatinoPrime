import { Router } from "express";
import { demoDocuments } from "../demoData";
import { query } from "../db";

export const documentsRouter = Router();

documentsRouter.get("/:userId", async (req, res, next) => {
  try {
    const rows = await query(
      `
        select
          id::text,
          title,
          agency,
          doc_type as "docType",
          created_at as "capturedAt",
          offline_allowed as "offlineAvailable",
          status
        from documents
        where user_id = $1
        order by created_at desc
        limit 25
      `,
      [req.params.userId]
    );

    res.json(rows.length ? rows : demoDocuments);
  } catch (error) {
    next(error);
  }
});

documentsRouter.post("/:userId/classify", async (req, res) => {
  res.status(202).json({
    status: "queued",
    userId: req.params.userId,
    pipeline: ["virus_scan", "ocr", "uscis_eoir_classifier", "field_extraction", "human_review_if_needed"]
  });
});
