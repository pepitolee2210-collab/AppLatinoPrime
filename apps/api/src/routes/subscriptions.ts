import { Router } from "express";
import { z } from "zod";

const freeActivationSchema = z.object({
  userId: z.string().uuid(),
  email: z.string().email()
});

export const subscriptionsRouter = Router();

subscriptionsRouter.post("/checkout", async (req, res, next) => {
  try {
    const input = freeActivationSchema.parse(req.body);
    res.json({
      id: crypto.randomUUID(),
      userId: input.userId,
      email: input.email,
      status: "active_free_test",
      url: null
    });
  } catch (error) {
    next(error);
  }
});
