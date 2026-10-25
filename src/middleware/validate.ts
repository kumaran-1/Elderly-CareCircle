import type { NextFunction, Request, Response } from "express";
import type { ZodSchema } from "zod";

function sanitizeString(value: string): string {
  return value.replace(/<[^>]*>/g, "").trim();
}

// Credential fields must never be altered before validation/hashing:
// the client validates the exact string the user typed, so the backend
// must validate (and later hash) that same exact string.
const CREDENTIAL_KEYS = new Set(["password", "currentPassword", "newPassword"]);

function sanitizeValue(value: unknown): unknown {
  if (typeof value === "string") return sanitizeString(value);
  if (Array.isArray(value)) return value.map(sanitizeValue);
  if (value && typeof value === "object") {
    const result: Record<string, unknown> = {};
    for (const [key, val] of Object.entries(value)) {
      result[key] = CREDENTIAL_KEYS.has(key) ? val : sanitizeValue(val);
    }
    return result;
  }
  return value;
}

export function validate(schema: ZodSchema) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    req.body = sanitizeValue(req.body);
    const result = schema.safeParse(req.body);
    if (!result.success) {
      next({ zod: result.error });
      return;
    }
    req.body = result.data;
    next();
  };
}

export function validateParams(schema: ZodSchema) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req.params);
    if (!result.success) {
      next({ zod: result.error });
      return;
    }
    req.params = result.data;
    next();
  };
}

export function validateQuery(schema: ZodSchema) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req.query);
    if (!result.success) {
      next({ zod: result.error });
      return;
    }
    req.query = result.data;
    next();
  };
}
