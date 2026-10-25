import { Router } from "express";
import { requireAuth } from "../middleware/guard";
import { createRequireElderAccess } from "../middleware/requireElderAccess";
import { validate } from "../middleware/validate";
import { vitalSchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function healthRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { health } = ctx.services;
  const requireElderAccess = createRequireElderAccess({ circles: ctx.services.circles });

  router.post("/vitals", requireAuth, validate(vitalSchema), requireElderAccess, (req, res, next) => {
    try {
      const result = health.logVital({ ...req.body, loggedByUserId: req.auth!.userId });
      res.status(201).json({ reading: result.reading, alerted: result.alerted, deduplicated: result.deduplicated });
    } catch (error) {
      next(error);
    }
  });

  router.get("/vitals/:elderId", requireAuth, requireElderAccess, (req, res, next) => {
    try {
      res.json({
        readings: health.getVitalsForElder(req.params.elderId),
        overview: health.getOverview(req.params.elderId)
      });
    } catch (error) {
      next(error);
    }
  });

  return router;
}
