import { Router } from "express";
import { z } from "zod";
import { filingTypeSchema } from "@usa-latino-prime/shared";
import { demoAutomations } from "../demoData";

const createFilingSchema = z.object({
  filingType: filingTypeSchema,
  profileSnapshot: z.record(z.string(), z.unknown()).default({})
});

export const filingsRouter = Router();

filingsRouter.get("/:userId", (_req, res) => {
  res.json(demoAutomations);
});

filingsRouter.post("/:userId", (req, res) => {
  const input = createFilingSchema.parse(req.body);
  const legalReviewRequired = input.filingType === "CHANGE_OF_VENUE" || input.filingType === "I765_RENEWAL";

  res.status(201).json({
    id: crypto.randomUUID(),
    userId: req.params.userId,
    filingType: input.filingType,
    status: legalReviewRequired ? "needs_review" : "ready_to_sign",
    legalReviewRequired,
    nextStep: legalReviewRequired ? "expert_review_queue" : "generate_pdf_for_signature"
  });
});
