import { Router } from "express";
import { requireAuth } from "../middleware/guard";
import { validate } from "../middleware/validate";
import { uploadSchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function fileRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { fileStorage } = ctx.services;

  router.post("/upload", requireAuth, validate(uploadSchema), async (req, res, next) => {
    try {
      const file = await fileStorage.upload({ ...req.body, uploadedByUserId: req.auth!.userId });
      res.status(201).json({ file });
    } catch (error) {
      next(error);
    }
  });

router.get("/", requireAuth, async (req, res, next) => {    try {
res.json({
  files: await fileStorage.listFilesAsync(req.auth!.userId, req.auth!.role)
});    } catch (error) {
      next(error);
    }
  });

  return router;
}
