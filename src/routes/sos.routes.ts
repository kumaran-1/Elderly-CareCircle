import { Router } from "express";
import { requireAuth } from "../middleware/guard";
import { createRequireElderAccess } from "../middleware/requireElderAccess";
import { validate } from "../middleware/validate";
import { sosSchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function sosRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { sos, circles } = ctx.services;
  const requireElderAccess = createRequireElderAccess({ circles });

  router.get("/", requireAuth, (req, res, next) => {
    try {
      const linkedElders = circles.getLinkedEldersForUser(req.auth!.userId);
      const allEvents = sos.getAllEvents();
      const events = allEvents.filter(
        (event) => linkedElders.includes(event.elderId) || event.triggeredByUserId === req.auth!.userId
      );
      res.json({ events });
    } catch (error) {
      next(error);
    }
  });

  router.post("/", requireAuth, validate(sosSchema), requireElderAccess, (req, res, next) => {
    try {
      res.status(201).json(sos.create({ ...req.body, triggeredByUserId: req.auth!.userId }));
    } catch (error) {
      next(error);
    }
  });

  router.post("/:id/acknowledge", requireAuth, (req, res, next) => {
    try {
      const event = sos.getEvent(req.params.id);
      if (!event) {
  return res.status(404).json({ message: "SOS event not found." });
}
      if (!circles.userHasAccessToElder(req.auth!.userId, event.elderId)) {
        res.status(403).json({ message: "You do not have access to this SOS event." });
        return;
      }
      res.json({ event: sos.acknowledge(req.params.id, req.auth!.userId) });
    } catch (error) {
      next(error);
    }
  });

  router.post("/:id/resolve", requireAuth, (req, res, next) => {
    try {
      const event = sos.getEvent(req.params.id);
      if (!event) {
  return res.status(404).json({ message: "SOS event not found." });
}
      if (!circles.userHasAccessToElder(req.auth!.userId, event.elderId)) {
        res.status(403).json({ message: "You do not have access to this SOS event." });
        return;
      }
      res.json({ event: sos.resolve(req.params.id, req.auth!.userId) });
    } catch (error) {
      next(error);
    }
  });

  return router;
}
