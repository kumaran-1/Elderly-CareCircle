import type { NextFunction, Request, Response } from "express";
import { Router } from "express";
import { requireAuth } from "../middleware/guard";
import { validate } from "../middleware/validate";
import { acceptSchema, createCircleSchema, inviteSchema } from "../validation/schemas";
import type { RouteContext } from "./types";

export function careCircleRoutes(ctx: RouteContext): Router {
  const router = Router();
  const { auth, circles } = ctx.services;

  router.post("/", requireAuth, validate(createCircleSchema), async (req, res, next) => {
    try {
      const creator = await auth.getUserById(req.auth!.userId);
      if (!creator) {
        res.status(404).json({ message: "Creator not found." });
        return;
      }

      const elderId = req.body.elderId ?? creator.id;
      if (creator.role !== "elder" && creator.role !== "family") {
        res.status(403).json({ message: "Only elder or family users can create a CareCircle." });
        return;
      }

      const relation = creator.role === "elder" ? "elder" : "family";
      const { circle, created } = circles.createOrJoinCircle(elderId, creator.id, relation, req.body.name);
      res.status(created ? 201 : 200).json({ circle });
    } catch (error) {
      next(error);
    }
  });

  async function handleAccept(req: Request, res: Response, next: NextFunction, inviteCode: string): Promise<void> {
    try {
      const user = await auth.getUserById(req.auth!.userId);
      if (!user) {
        res.status(404).json({ message: "User not found." });
        return;
      }
      const result = circles.acceptInvitation(inviteCode, user.id, user.email, req.body.relation);
      res.json({ circle: circles.getCircle(result.circle.id), alreadyLinked: result.alreadyLinked });
    } catch (error) {
      next(error);
    }
  }

  // Explicit accept path used by the mobile client.
  router.post("/accept", requireAuth, validate(acceptSchema), (req, res, next) => {
    void handleAccept(req, res, next, req.body.inviteCode);
  });

  router.post("/:id/invite", requireAuth, validate(inviteSchema), (req, res, next) => {
    try {
      const circle = circles.getCircle(req.params.id);
      if (!circles.isCircleManager(circle.id, req.auth!.userId)) {
        res.status(403).json({ message: "Only the elder who owns this CareCircle can invite members." });
        return;
      }
      const result = circles.inviteMember(circle.id, req.body.email, req.body.relation, req.auth!.userId);
      res.status(result.created ? 201 : 200).json({
        circle: result.circle,
        invitation: {
          email: result.invitation.email,
          relation: result.invitation.relation,
          status: result.invitation.status,
          expiresAt: result.invitation.expiresAt
        }
      });
    } catch (error) {
      next(error);
    }
  });

  // Legacy path: the circle id segment is ignored in favor of the invite
  // code in the request body. Preserved for backward compatibility.
  router.post("/:id/accept", requireAuth, validate(acceptSchema), (req, res, next) => {
    void handleAccept(req, res, next, req.body.inviteCode ?? req.params.id);
  });

  router.get("/me", requireAuth, (req, res, next) => {
    try {
      const myCircles = circles.getCirclesForUser(req.auth!.userId).map((circle) => ({
        ...circle,
        members: circles.getMemberDetails(circle.id),
        ...(circle.elderId === req.auth!.userId
          ? {
              pendingInvitations: circles
                .getPendingForCircle(circle.id)
                .map((inv) => ({ email: inv.email, relation: inv.relation, createdAt: inv.createdAt, expiresAt: inv.expiresAt }))
            }
          : {})
      }));
      res.json({ circles: myCircles });
    } catch (error) {
      next(error);
    }
  });

  // Pending inbound invitations for the caller's own account.
  router.get("/invitations/me", requireAuth, async (req, res, next) => {
    try {
      const user = await auth.getUserById(req.auth!.userId);
      if (!user) {
        res.status(404).json({ message: "User not found." });
        return;
      }
      const invitations = circles.getPendingForEmail(user.email).map((inv) => {
        const circle = circles.getCircle(inv.circleId);
        return {
          circleId: circle.id,
          circleName: circle.name,
          elderId: circle.elderId,
          relation: inv.relation,
          inviteCode: circle.inviteCode,
          createdAt: inv.createdAt,
          expiresAt: inv.expiresAt
        };
      });
      res.json({ invitations });
    } catch (error) {
      next(error);
    }
  });

  router.delete("/:id/members/:userId", requireAuth, (req, res, next) => {
    try {
      const circle = circles.getCircle(req.params.id);
      if (!circles.isCircleManager(circle.id, req.auth!.userId)) {
        res.status(403).json({ message: "Only the elder who owns this CareCircle can remove members." });
        return;
      }
      const updated = circles.removeMember(circle.id, req.params.userId);
      res.json({ circle: updated });
    } catch (error) {
      next(error);
    }
  });

  return router;
}
