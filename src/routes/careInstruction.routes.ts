import { Router } from "express";
import { requireAuth, requireRole } from "../middleware/guard";
import { createRequireElderAccess } from "../middleware/requireElderAccess";
import { validate } from "../middleware/validate";
import { careInstructionSchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function careInstructionRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { careInstructions } = ctx.services;
  const requireElderAccess = createRequireElderAccess({ circles: ctx.services.circles });

  router.post("/", requireAuth, requireRole("caregiver"), validate(careInstructionSchema), requireElderAccess, (req, res, next) => {
    try {
      const instruction = careInstructions.create({
        ...req.body,
        caregiverId: req.auth!.userId
      });
      res.status(201).json({ instruction });
    } catch (error) {
      next(error);
    }
  });

  router.get("/elder/:elderId", requireAuth, requireElderAccess, (req, res, next) => {
    try {
      const records = careInstructions.getMedicalRecordsForElder(req.params.elderId);
      res.json(records);
    } catch (error) {
      next(error);
    }
  });

  router.get("/:elderId", requireAuth, requireElderAccess, (req, res, next) => {
    try {
      const instructions = careInstructions.getByElderId(req.params.elderId);
      res.json({ instructions });
    } catch (error) {
      next(error);
    }
  });

  router.get("/", requireAuth, (req, res, next) => {
    try {
      if (req.auth!.role === "caregiver") {
        const instructions = careInstructions.getByCaregiverId(req.auth!.userId);
        res.json({ instructions });
      } else {
        const elderIds = ctx.services.circles.getLinkedEldersForUser(req.auth!.userId);
        const instructions = elderIds.flatMap((elderId) => careInstructions.getByElderId(elderId));
        res.json({ instructions });
      }
    } catch (error) {
      next(error);
    }
  });

  return router;
}
