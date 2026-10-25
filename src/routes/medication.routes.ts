import { Router } from "express";
import { requireAuth } from "../middleware/guard";
import { createRequireElderAccess } from "../middleware/requireElderAccess";
import { validate } from "../middleware/validate";
import { medicationLogSchema, medicationSchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function medicationRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { medication } = ctx.services;
  const requireElderAccess = createRequireElderAccess({ circles: ctx.services.circles });

  router.post("/", requireAuth, validate(medicationSchema), requireElderAccess, (req, res, next) => {
    try {
      const plan = medication.createPlan({ ...req.body, createdByUserId: req.auth!.userId });
      res.status(201).json({ medication: plan });
    } catch (error) {
      next(error);
    }
  });

  router.post("/:id/logs", requireAuth, validate(medicationLogSchema), requireElderAccess, (req, res, next) => {
    try {
      const result = medication.logDose({
        medicationId: req.params.id,
        elderId: req.body.elderId,
        loggedByUserId: req.auth!.userId,
        status: req.body.status,
        dueAt: req.body.dueAt
      });
      res.status(result.duplicate ? 200 : 201).json(result);
    } catch (error) {
      next(error);
    }
  });

  router.get("/summary/:elderId", requireAuth, requireElderAccess, (req, res, next) => {
    try {
      res.json({
        plans: medication.getPlansForElder(req.params.elderId),
        logs: medication.getLogsForElder(req.params.elderId),
        summary: medication.getSummary(req.params.elderId)
      });
    } catch (error) {
      next(error);
    }
  });

  return router;
}
