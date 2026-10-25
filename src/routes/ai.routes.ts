import { Router } from "express";
import { requireAuth } from "../middleware/guard";
import { validate } from "../middleware/validate";
import { aiSchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function aiRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { ai } = ctx.services;

  router.get("/conversations", requireAuth, (req, res, next) => {
    try {
      const conversations = ai.listConversationsForUser(req.auth!.userId);
      res.json({ conversations });
    } catch (error) {
      next(error);
    }
  });

  router.post("/chat", requireAuth, validate(aiSchema), async (req, res, next) => {
    try {
      const result = await ai.chat(req.auth!.userId, req.body.elderId ?? req.auth!.userId, req.body.question);
      res.json({
        ...result,
        ifEmergency: result.conversation.emergencyDetected ? "Use SOS or emergency services immediately." : undefined
      });
    } catch {
      next({ statusCode: 502, message: "AI service is temporarily unavailable." });
    }
  });

  return router;
}
