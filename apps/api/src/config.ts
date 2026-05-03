import "dotenv/config";
import { z } from "zod";

const configSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(4000),
  DATABASE_URL: z.string().optional(),
  WEB_ORIGIN: z.string().default("http://localhost:5173"),
  STRIPE_SECRET_KEY: z.string().optional(),
  STRIPE_WEBHOOK_SECRET: z.string().optional(),
  USCIS_CLIENT_ID: z.string().optional(),
  USCIS_CLIENT_SECRET: z.string().optional(),
  USCIS_TOKEN_URL: z.string().default("https://api-int.uscis.gov/oauth/accesstoken"),
  USCIS_CASE_STATUS_URL: z.string().default("https://api-int.uscis.gov/case-status")
});

export const config = configSchema.parse(process.env);
