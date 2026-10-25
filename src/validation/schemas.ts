import { z } from "zod";

const passwordValidation = z
  .string()
  .min(8, "Password must be at least 8 characters.")
  .regex(/[A-Z]/, "Password must contain at least one uppercase letter.")
  .regex(/[a-z]/, "Password must contain at least one lowercase letter.")
  .regex(/[0-9]/, "Password must contain at least one number.");

export const registerSchema = z.object({
  name: z.string().trim().min(2, "Name must be at least 2 characters."),
  email: z.string().trim().email(),
  password: passwordValidation,
  role: z.enum(["elder", "family", "caregiver"])
});

export const loginSchema = z.object({
  email: z.string().trim().email(),
  password: z.string().min(8)
});

export const verifyOtpSchema = z.object({
  email: z.string().trim().email(),
  otp: z.string().length(6)
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(1)
});

export const createCircleSchema = z.object({
  elderId: z.string().optional(),
  name: z.string().trim().min(2).optional()
});

export const inviteSchema = z.object({
  email: z.string().trim().email(),
  relation: z.enum(["family", "caregiver"])
});

export const acceptSchema = z.object({
  circleId: z.string().optional(),
  inviteCode: z.string().min(4),
  relation: z.enum(["family", "caregiver"])
});

export const vitalSchema = z.object({
  elderId: z.string(),
  type: z.enum(["bloodPressure", "bloodSugar", "heartRate", "weight", "temperature"]),
  value: z.number().finite().nonnegative(),
  unit: z.string().trim().min(1),
  systolic: z.number().finite().nonnegative().optional(),
  diastolic: z.number().finite().nonnegative().optional()
});

const timeOfDayPattern = /^([01]?\d|2[0-3]):[0-5]\d$/;

export const medicationSchema = z.object({
  elderId: z.string(),
  name: z.string().trim().min(2),
  dosage: z.string().trim().min(1),
  frequency: z.string().trim().min(1),
  reminderTime: z
    .string()
    .trim()
    .min(1)
    .refine(
      (value) => timeOfDayPattern.test(value) || !Number.isNaN(Date.parse(value)),
      "Reminder time must be HH:MM (24-hour) or a valid date-time."
    )
});

export const medicationLogSchema = z.object({
  elderId: z.string(),
  status: z.enum(["taken", "snoozed", "skipped", "missed"]),
  dueAt: z.string().optional()
});

export const hydrationSchema = z.object({
  elderId: z.string(),
  amountMl: z.number().positive()
});

export const exerciseSchema = z.object({
  elderId: z.string(),
  activityType: z.string().trim().min(2),
  minutes: z.number().positive()
});

export const appointmentSchema = z.object({
  elderId: z.string(),
  doctorName: z.string().trim().min(2),
  specialty: z.string().trim().min(2),
  dateTime: z.string().datetime(),
  notes: z.string().trim().optional()
});

export const appointmentUpdateSchema = z
  .object({
    elderId: z.string(),
    doctorName: z.string().trim().min(2).optional(),
    specialty: z.string().trim().min(2).optional(),
    dateTime: z.string().datetime().optional(),
    notes: z.string().trim().optional()
  })
  .refine(
    (value) =>
      value.doctorName !== undefined ||
      value.specialty !== undefined ||
      value.dateTime !== undefined ||
      value.notes !== undefined,
    "At least one field to update is required."
  );

export const appointmentCancelSchema = z.object({
  elderId: z.string()
});

export const uploadSchema = z.object({
  name: z.string().trim().min(1),
  mimeType: z.string().trim().min(1),
  contentBase64: z.string().min(1)
});

export const deviceSchema = z.object({
  token: z.string().min(10)
});

export const aiSchema = z.object({
  elderId: z.string().optional(),
  question: z.string().trim().min(2)
});

export const sosSchema = z.object({
  elderId: z.string(),
  location: z.string().trim().optional()
});

export const periodQuerySchema = z.enum(["weekly", "monthly"]).default("weekly");

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(8),
  newPassword: passwordValidation
});

export const careInstructionSchema = z.object({
  elderId: z.string(),
  title: z.string().trim().min(2, "Title must be at least 2 characters."),
  message: z.string().trim().min(2, "Message must be at least 2 characters."),
  priority: z.enum(["low", "medium", "high", "urgent"]),
  category: z.string().trim().min(1, "Category is required."),
  scheduledAt: z.string().datetime().optional()
});
