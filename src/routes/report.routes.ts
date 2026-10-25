import { Router } from "express";
import { requireAuth } from "../middleware/guard";
import { createRequireElderAccess } from "../middleware/requireElderAccess";
import { periodQuerySchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function reportRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { reports, reportPdf } = ctx.services;
  const requireElderAccess = createRequireElderAccess({ circles: ctx.services.circles });

  router.get("/summary/:elderId", requireAuth, requireElderAccess, (req, res, next) => {
    try {
      const period = periodQuerySchema.safeParse(req.query.period);
      if (!period.success) {
        res.status(400).json({ message: "Invalid period. Use weekly or monthly." });
        return;
      }
      res.json(reports.buildSummary(req.params.elderId, period.data));
    } catch (error) {
      next(error);
    }
  });

  router.get("/summary/:elderId/pdf", requireAuth, requireElderAccess, async (req, res, next) => {
    try {
      const period = periodQuerySchema.safeParse(req.query.period);
      if (!period.success) {
        res.status(400).json({ message: "Invalid period. Use weekly or monthly." });
        return;
      }
      const summary = reports.buildSummary(req.params.elderId, period.data);
      const pdf = await reportPdf.generate(summary);
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader("Content-Disposition", `attachment; filename=carecircle-${period}-report.pdf`);
      res.send(pdf);
    } catch {
      next({ statusCode: 500, message: "Unable to generate report PDF." });
    }
  });

  return router;
}
