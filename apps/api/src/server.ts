import cors from "cors";
import express from "express";
import helmet from "helmet";
import morgan from "morgan";
import { ZodError } from "zod";
import { config } from "./config";
import { casesRouter } from "./routes/cases";
import { dashboardRouter } from "./routes/dashboard";
import { documentsRouter } from "./routes/documents";
import { filingsRouter } from "./routes/filings";
import { servicesRouter } from "./routes/services";
import { subscriptionsRouter } from "./routes/subscriptions";

const app = express();

app.use(helmet());
app.use(cors({ origin: config.WEB_ORIGIN, credentials: true }));
app.use(express.json({ limit: "1mb" }));
app.use(morgan(config.NODE_ENV === "production" ? "combined" : "dev"));

app.get("/health", (_req, res) => {
  res.json({ ok: true, service: "usa-latino-prime-api" });
});

app.use("/v1/dashboard", dashboardRouter);
app.use("/v1/documents", documentsRouter);
app.use("/v1/filings", filingsRouter);
app.use("/v1/cases", casesRouter);
app.use("/v1/services", servicesRouter);
app.use("/v1/subscriptions", subscriptionsRouter);

app.use((error: unknown, _req: express.Request, res: express.Response, next: express.NextFunction) => {
  void next;
  if (error instanceof ZodError) {
    res.status(400).json({ error: "validation_error", issues: error.issues });
    return;
  }

  const message = error instanceof Error ? error.message : "Unexpected error";
  const status = message.includes("not configured") ? 503 : 500;
  res.status(status).json({ error: "server_error", message });
});

app.listen(config.PORT, () => {
  console.log(`MiCaso Prime API listening on http://localhost:${config.PORT}`);
});
