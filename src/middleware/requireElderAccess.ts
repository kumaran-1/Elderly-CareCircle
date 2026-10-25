import type { NextFunction, Request, Response } from "express";
import type { CareCircleService } from "../services/careCircleService";

export interface ElderAccessDeps {
  circles: CareCircleService;
}

function resolveElderId(req: Request): string | undefined {
  const query = req.query.elderId;
  if (typeof query === "string") {
    return query;
  }
  if (req.params.elderId) {
    return String(req.params.elderId);
  }
  if (req.body && typeof req.body.elderId === "string") {
    return req.body.elderId;
  }
  return undefined;
}

export function createRequireElderAccess({ circles }: ElderAccessDeps) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.auth) {
      res.status(401).json({ message: "Authentication required." });
      return;
    }

    const elderId = resolveElderId(req);
    if (!elderId) {
      res.status(400).json({ message: "An elderId is required." });
      return;
    }

    if (!circles.userHasAccessToElder(req.auth.userId, elderId)) {
      res.status(403).json({ message: "You are not linked to this elder's CareCircle." });
      return;
    }

    next();
  };
}
