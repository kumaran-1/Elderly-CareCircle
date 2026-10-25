import { Router } from "express";
import { requireAuth } from "../middleware/guard";
import { validate } from "../middleware/validate";
import { changePasswordSchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function userRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { auth, dashboard } = ctx.services;

  router.get("/me", requireAuth, async (req, res, next) => {
    try {
      const user = await auth.getUserById(req.auth!.userId);
      if (!user) {
        res.status(404).json({ message: "User not found." });
        return;
      }
      res.json({ user: auth.publicUser(user), dashboard: await dashboard.build(req.auth!.userId) });
    } catch (error) {
      next(error);
    }
  });

  router.put("/me", requireAuth, async (req, res, next) => {
    try {
      const { name, profile } = req.body;
      const updated = await auth.updateProfile(req.auth!.userId, { name, profile });
      res.json({ user: updated });
    } catch (error) {
      next(error);
    }
  });

  router.put("/me/password", requireAuth, validate(changePasswordSchema), async (req, res, next) => {
    try {
      const { currentPassword, newPassword } = req.body;
      await auth.changePassword(req.auth!.userId, currentPassword, newPassword);
      res.json({ message: "Password changed successfully." });
    } catch (error) {
      next(error);
    }
  });

  router.get("/dashboard", requireAuth, async (req, res, next) => {
    try {
      res.json(await dashboard.build(req.auth!.userId));
    } catch (error) {
      next(error);
    }
  });

  return router;
}
