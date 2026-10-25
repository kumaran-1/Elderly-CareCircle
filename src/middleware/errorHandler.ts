import type { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";

export interface AppError extends Error {
  statusCode?: number;
  zod?: ZodError;
}

export function notFoundHandler(_req: Request, res: Response): void {
  res.status(404).json({ message: "Route not found." });
}

export function errorHandler(error: unknown, _req: Request, res: Response, _next: NextFunction): void {
  const err = error as AppError;

  if (err?.zod instanceof ZodError) {
    res.status(400).json({ message: "Validation failed.", issues: err.zod.issues });
    return;
  }

  const statusCode = typeof err?.statusCode === "number" ? err.statusCode : 500;
  res.status(statusCode).json({
    message: err && typeof err.message === "string" && err.message ? err.message : "Unexpected server error."
  });
}
