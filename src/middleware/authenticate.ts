import type { NextFunction, Request, Response } from "express";
import type { AuthService } from "../services/authService";

export interface AuthDeps {
  auth: AuthService;
}

export function createAuthenticateMiddleware({ auth }: AuthDeps) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      next();
      return;
    }

    try {
      req.auth = auth.authenticate(header.slice("Bearer ".length));
    } catch (error) {
      res.status(401).json({ message: error instanceof Error ? error.message : "Unauthorized" });
      return;
    }

    next();
  };
}
