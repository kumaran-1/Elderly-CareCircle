import { Router } from "express";
import { requireAuth } from "../middleware/guard";
import { createRequireElderAccess } from "../middleware/requireElderAccess";
import { validate } from "../middleware/validate";
import { appointmentCancelSchema, appointmentSchema, appointmentUpdateSchema, exerciseSchema, hydrationSchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function lifestyleRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { lifestyle } = ctx.services;
  const requireElderAccess = createRequireElderAccess({ circles: ctx.services.circles });

  router.post("/hydration/logs", requireAuth, validate(hydrationSchema), requireElderAccess, (req, res, next) => {
    try {
      const result = lifestyle.logHydration({ ...req.body, loggedByUserId: req.auth!.userId });
      res
        .status(result.duplicate ? 200 : 201)
        .json({ log: result.log, summary: lifestyle.getHydrationSummary(req.body.elderId), duplicate: result.duplicate });
    } catch (error) {
      next(error);
    }
  });

  router.get("/hydration/summary/:elderId", requireAuth, requireElderAccess, (req, res, next) => {
    try {
      res.json(lifestyle.getHydrationSummary(req.params.elderId));
    } catch (error) {
      next(error);
    }
  });

  router.post("/exercise/logs", requireAuth, validate(exerciseSchema), requireElderAccess, (req, res, next) => {
    try {
      const result = lifestyle.logExercise({ ...req.body, loggedByUserId: req.auth!.userId });
      res
        .status(result.duplicate ? 200 : 201)
        .json({ log: result.log, summary: lifestyle.getExerciseSummary(req.body.elderId), duplicate: result.duplicate });
    } catch (error) {
      next(error);
    }
  });

  router.get("/exercise/summary/:elderId", requireAuth, requireElderAccess, (req, res, next) => {
    try {
      res.json(lifestyle.getExerciseSummary(req.params.elderId));
    } catch (error) {
      next(error);
    }
  });

  router.post("/appointments", requireAuth, validate(appointmentSchema), requireElderAccess, (req, res, next) => {
    try {
      const appointment = lifestyle.createAppointment({ ...req.body, createdByUserId: req.auth!.userId });
      res.status(201).json({ appointment });
    } catch (error) {
      next(error);
    }
  });

  router.get("/appointments/:elderId", requireAuth, requireElderAccess, (req, res, next) => {
    try {
      res.json({ appointments: lifestyle.getAppointmentsForElder(req.params.elderId) });
    } catch (error) {
      next(error);
    }
  });

  router.get("/appointments/:elderId/:id", requireAuth, requireElderAccess, (req, res, next) => {
    try {
      res.json({ appointment: lifestyle.getAppointment(req.params.elderId, req.params.id) });
    } catch (error) {
      next(error);
    }
  });

  router.patch("/appointments/:id", requireAuth, validate(appointmentUpdateSchema), requireElderAccess, (req, res, next) => {
    try {
      const appointment = lifestyle.updateAppointment(req.body.elderId, req.params.id, req.body);
      res.json({ appointment });
    } catch (error) {
      next(error);
    }
  });

  router.post("/appointments/:id/cancel", requireAuth, validate(appointmentCancelSchema), requireElderAccess, (req, res, next) => {
    try {
      const result = lifestyle.cancelAppointment(req.body.elderId, req.params.id);
      res.json(result);
    } catch (error) {
      next(error);
    }
  });

  return router;
}
