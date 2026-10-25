import { Router } from "express";
import { requireAuth } from "../middleware/guard";
import { validate } from "../middleware/validate";
import { deviceSchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function notificationRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { notifications } = ctx.services;

  router.get("/", requireAuth, (req, res, next) => {
    try {
      res.json({ notifications: notifications.listForUser(req.auth!.userId) });
    } catch (error) {
      next(error);
    }
  });

  router.post("/device", requireAuth, validate(deviceSchema), async (req, res, next) => {
    try {
      res.json({ tokens: await notifications.registerDevice(req.auth!.userId, req.body.token) });
    } catch (error) {
      next(error);
    }
  });

  router.post("/:id/read", requireAuth, (req, res, next) => {
    try {
      const notification = notifications.markRead(req.auth!.userId, req.params.id);
      if (!notification) {
        res.status(404).json({ message: "Notification not found." });
        return;
      }
      res.json({ notification });
    } catch (error) {
      next(error);
    }
  });

  return router;
}
