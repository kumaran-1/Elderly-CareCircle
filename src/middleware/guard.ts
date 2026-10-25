import type { NextFunction, Request, Response } from "express";
import type { Role } from "../domain/types";

export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  if (!req.auth) {
    res.status(401).json({ message: "Authentication required." });
    return;
  }
  next();
}

export function requireRole(...roles: Role[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.auth) {
      res.status(401).json({ message: "Authentication required." });
      return;
    }
    if (!roles.includes(req.auth.role)) {
      res.status(403).json({ message: "You do not have access to this resource." });
      return;
    }
    next();
  };
}
