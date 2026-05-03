import { Router } from "express";
import { z } from "zod";
import { premiumServiceTypeSchema } from "@usa-latino-prime/shared";
import { demoPremiumServices } from "../demoData";
import { query } from "../db";

const serviceRequestSchema = z.object({
  userId: z.string().uuid(),
  serviceType: premiumServiceTypeSchema,
  caseId: z.string().uuid().optional(),
  notes: z.string().max(1200).optional()
});

export const servicesRouter = Router();

servicesRouter.get("/", async (_req, res, next) => {
  try {
    const rows = await query<{
      id: string;
      serviceType: "ANNUALITY_PAYMENT" | "EXPERT_REVIEW" | "SPECIAL_CASE_TRACKING";
      title: string;
      description: string;
      priceMode: "free" | "one_time" | "annual" | "manual_quote";
      enabled: boolean;
    }>(
      `
        select
          id::text,
          service_type as "serviceType",
          title,
          description,
          price_mode as "priceMode",
          enabled
        from premium_services
        where enabled = true
        order by created_at asc
      `
    );

    res.json(rows.length ? rows : demoPremiumServices);
  } catch (error) {
    next(error);
  }
});

servicesRouter.post("/requests", async (req, res, next) => {
  try {
    const input = serviceRequestSchema.parse(req.body);

    const serviceRows = await query<{ id: string }>(
      "select id::text from premium_services where service_type = $1 and enabled = true limit 1",
      [input.serviceType]
    );

    if (serviceRows.length === 0) {
      res.status(201).json({
        id: crypto.randomUUID(),
        userId: input.userId,
        serviceType: input.serviceType,
        status: "requested_free_test",
        nextStep: "free_flow_review"
      });
      return;
    }

    const inserted = await query<{ id: string; status: string }>(
      `
        insert into premium_service_requests (user_id, service_id, case_id, status, amount_cents, notes)
        values ($1, $2, $3, 'requested_free_test', 0, $4)
        returning id::text, status
      `,
      [input.userId, serviceRows[0]!.id, input.caseId ?? null, input.notes ?? null]
    );

    res.status(201).json({
      ...inserted[0],
      serviceType: input.serviceType,
      nextStep: "free_flow_review"
    });
  } catch (error) {
    next(error);
  }
});
