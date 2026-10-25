import { Router } from "express";
import rateLimit from "express-rate-limit";
import { config } from "../config";
import { requireAuth } from "../middleware/guard";
import { validate } from "../middleware/validate";
import { loginSchema, refreshSchema, registerSchema, verifyOtpSchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function authRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { auth } = ctx.services;

  router.use(
    rateLimit({
      windowMs: config.rateLimitWindowMs,
      limit: config.rateLimitMax,
      standardHeaders: "draft-7",
      legacyHeaders: false
    })
  );

  router.post("/register", validate(registerSchema), async (req, res, next) => {
    try {
      const { user, tokens } = await auth.register(req.body);
      res.status(201).json({
        message: "Account created successfully.",
        user,
        tokens
      });
    } catch (error) {
      next(error);
    }
  });

  router.post("/login", validate(loginSchema), async (req, res, next) => {
    try {
      const result = await auth.login(req.body);
      res.json({ message: "Login successful.", user: result.user, tokens: result.tokens });
    } catch (error) {
      next(error);
    }
  });

  router.post("/verify-otp", validate(verifyOtpSchema), async (req, res, next) => {
    try {
      const result = await auth.verifyOtp(req.body.email, req.body.otp);
      res.json({ message: "OTP verified successfully.", user: result.user, tokens: result.tokens });
    } catch (error) {
      next(error);
    }
  });

  router.post("/refresh", validate(refreshSchema), async (req, res, next) => {
    try {
      const claims = auth.authenticateRefreshToken(req.body.refreshToken);
      const user = await auth.getUserById(claims.userId);
      if (!user) {
        res.status(404).json({ message: "User not found." });
        return;
      }
      if (claims.tokenVersion !== user.refreshTokenVersion) {
        res.status(401).json({ message: "Refresh token has been revoked." });
        return;
      }
      res.json({ tokens: await auth.refresh(user.id) });
    } catch (error) {
      next(error);
    }
  });

  router.post("/logout", requireAuth, async (req, res, next) => {
    try {
      await auth.logout(req.auth!.userId);
      res.json({ message: "Logged out successfully." });
    } catch (error) {
      next(error);
    }
  });

  return router;
}
