export type Role = "elder" | "family" | "caregiver" | "admin";
export type InstructionPriority = "low" | "medium" | "high" | "urgent";

export interface CareInstruction {
  id: string;
  elderId: string;
  caregiverId: string;
  title: string;
  message: string;
  priority: InstructionPriority;
  category: string;
  scheduledAt?: string;
  createdAt: string;
}
export type NotificationCategory =
  | "otp"
  | "medication"
  | "vital"
  | "hydration"
  | "exercise"
  | "appointment"
  | "ai"
  | "sos"
  | "system"
  | "careInstruction";

export interface Profile {
  dateOfBirth?: string;
  photoUrl?: string;
  contactNumber?: string;
  medicalConditions?: string[];
  allergies?: string[];
}

export interface User {
  id: string;
  name: string;
  email: string;
  passwordHash: string;
  role: Role;
  verified: boolean;
  profile: Profile;
  fcmTokens: string[];
  otpCode?: string;
  otpExpiresAt?: string;
  refreshTokenVersion: number;
  createdAt: string;
}

export interface AuthContext {
  userId: string;
  email: string;
  role: Role;
  tokenVersion?: number;
}

export interface CareCircleMember {
  userId: string;
  relation: "elder" | "family" | "caregiver" | "admin" | "other";
  acceptedAt?: string;
}

export interface CareCircle {
  id: string;
  elderId: string;
  name: string;
  inviteCode: string;
  createdByUserId: string;
  createdAt: string;
  members: CareCircleMember[];
}

export type VitalType = "bloodPressure" | "bloodSugar" | "heartRate" | "weight" | "temperature";

export interface VitalReading {
  id: string;
  elderId: string;
  loggedByUserId: string;
  type: VitalType;
  value: number;
  unit: string;
  systolic?: number;
  diastolic?: number;
  status: "normal" | "abnormal";
  thresholdNote: string;
  createdAt: string;
}

export interface MedicationPlan {
  id: string;
  elderId: string;
  createdByUserId: string;
  name: string;
  dosage: string;
  frequency: string;
  reminderTime: string;
  active: boolean;
  createdAt: string;
}

export interface MedicationLog {
  id: string;
  medicationId: string;
  elderId: string;
  loggedByUserId: string;
  status: "taken" | "snoozed" | "skipped" | "missed";
  dueAt: string;
  loggedAt: string;
}

export interface HydrationLog {
  id: string;
  elderId: string;
  loggedByUserId: string;
  amountMl: number;
  createdAt: string;
}

export interface ExerciseLog {
  id: string;
  elderId: string;
  loggedByUserId: string;
  activityType: string;
  minutes: number;
  createdAt: string;
}

export interface Appointment {
  id: string;
  elderId: string;
  createdByUserId: string;
  doctorName: string;
  specialty: string;
  dateTime: string;
  notes?: string;
  reminderTimes: string[];
  createdAt: string;
}

export interface Conversation {
  id: string;
  userId: string;
  elderId?: string;
  question: string;
  answer: string;
  emergencyDetected: boolean;
  createdAt: string;
}

export interface Notification {
  id: string;
  userId: string;
  elderId?: string;
  category: NotificationCategory;
  title: string;
  body: string;
  deliveredAt: string;
  readAt?: string;
  metadata?: Record<string, string | number | boolean>;
}

export interface StoredFileRecord {
  id: string;
  name: string;
  mimeType: string;
  size: number;
  path: string;
  uploadedAt: string;
}

export interface SosEvent {
  id: string;
  elderId: string;
  triggeredByUserId: string;
  status: "active" | "acknowledged" | "resolved";
  location?: string;
  createdAt: string;
  acknowledgedAt?: string;
  resolvedAt?: string;
}

export interface ReportSummary {
  elderId: string;
  period: "weekly" | "monthly";
  generatedAt: string;
  vitalsCount: number;
  abnormalVitalsCount: number;
  medicationAdherencePercent: number;
  hydrationMl: number;
  exerciseMinutes: number;
  appointmentCount: number;
  activeSosCount: number;
  summary: string;
}

export interface DashboardCard {
  label: string;
  value: string;
  tone: "normal" | "attention" | "alert";
}

export interface DashboardPayload {
  role: Role;
  title: string;
  cards: DashboardCard[];
  actions: string[];
}

export interface SystemStore {
  users: User[];
  careCircles: CareCircle[];
  careInstructions: CareInstruction[];
  vitals: VitalReading[];
  medicationPlans: MedicationPlan[];
  medicationLogs: MedicationLog[];
  hydrationLogs: HydrationLog[];
  exerciseLogs: ExerciseLog[];
  appointments: Appointment[];
  conversations: Conversation[];
  notifications: Notification[];
  sosEvents: SosEvent[];
  files: StoredFileRecord[];
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}
