import { Router } from "express";
import { z } from "zod";
import { fetchUscisCaseStatus } from "../services/uscisCaseStatus";

const receiptSchema = z.object({
  receiptNumber: z.string().trim().min(8).max(32)
});

export const casesRouter = Router();

casesRouter.post("/uscis/status", async (req, res, next) => {
  try {
    const { receiptNumber } = receiptSchema.parse(req.body);
    const result = await fetchUscisCaseStatus(receiptNumber);
    res.json(result);
  } catch (error) {
    next(error);
  }
});
