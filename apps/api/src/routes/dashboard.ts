import { Router } from "express";
import { dashboardSummarySchema } from "@usa-latino-prime/shared";
import { demoDashboard } from "../demoData";
import { query } from "../db";

export const dashboardRouter = Router();

dashboardRouter.get("/:userId", async (req, res, next) => {
  try {
    const rows = await query<{
      user_name: string;
      tier: "free" | "base" | "premium" | "expert";
      alert_id: string | null;
      kind: string | null;
      title: string | null;
      details: string | null;
      due_at: Date | null;
      severity: "green" | "yellow" | "red" | null;
      source: string | null;
    }>(
      `
        select
          u.full_name as user_name,
          coalesce(s.tier, 'free') as tier,
          cd.id::text as alert_id,
          cd.kind,
          cd.title,
          cd.details,
          cd.due_at,
          cd.severity,
          cd.source
        from users u
        left join user_subscriptions s on s.user_id = u.id
        left join critical_dates cd on cd.user_id = u.id and cd.acknowledged_at is null
        where u.id = $1
        order by cd.due_at asc nulls last
        limit 10
      `,
      [req.params.userId]
    );

    if (rows.length === 0) {
      res.json(dashboardSummarySchema.parse(demoDashboard));
      return;
    }

    const first = rows[0]!;
    const alerts = rows
      .filter((row) => row.alert_id)
      .map((row) => ({
        id: row.alert_id!,
        kind: row.kind as "court_hearing",
        title: row.title!,
        detail: row.details ?? "",
        dueAt: row.due_at!.toISOString(),
        dueLabel: formatDueLabel(row.due_at!),
        severity: row.severity ?? "yellow",
        source: row.source === "USCIS" || row.source === "EOIR" || row.source === "CBP" ? row.source : undefined
      }));

    const status = alerts.some((alert) => alert.severity === "red")
      ? "red"
      : alerts.some((alert) => alert.severity === "yellow")
        ? "yellow"
        : "green";

    res.json(
      dashboardSummarySchema.parse({
        userName: first.user_name.split(" ")[0],
        tier: first.tier,
        status,
        totals: {
          documentsExpiring: 0,
          pendingTasks: alerts.length,
          activeCases: 0,
          newMessages: 0
        },
        alerts
      })
    );
  } catch (error) {
    next(error);
  }
});

function formatDueLabel(date: Date): string {
  const diff = date.getTime() - Date.now();
  const days = Math.ceil(diff / 86_400_000);

  if (days < 0) return "vencido";
  if (days === 0) return "hoy";
  if (days === 1) return "1 dia";
  return `${days} dias`;
}
