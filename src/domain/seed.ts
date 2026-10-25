import bcrypt from "bcryptjs";
import { config } from "../config";
import { createEmptyStore } from "./store";
import type {
  CareCircle,
  Conversation,
  ExerciseLog,
  HydrationLog,
  MedicationLog,
  MedicationPlan,
  Notification,
  SosEvent,
  SystemStore,
  StoredFileRecord,
  User,
  VitalReading
} from "./types";

const now = new Date();
const minutes = (value: number) => value * 60 * 1000;

const hash = (value: string | undefined) =>
  bcrypt.hashSync(value ?? "CareCircleDemo123", 10);

const makeUser = (input: Omit<User, "refreshTokenVersion" | "createdAt" | "fcmTokens"> & { fcmTokens?: string[] }): User => ({
  ...input,
  fcmTokens: input.fcmTokens ?? [],
  refreshTokenVersion: 0,
  createdAt: now.toISOString()
});

export const createSeedStore = (): SystemStore => {
  const store = createEmptyStore();

  const elder = makeUser({
    id: "user-elder-1",
    name: "Rajendran",
    email: "rajendran@example.com",
passwordHash: hash(config.demoPassword ?? "CareCircleDemo123"),    role: "elder",
    verified: true,
    profile: {
      dateOfBirth: "1948-04-12",
      contactNumber: "+91-90000-00001",
      medicalConditions: ["Hypertension"],
      allergies: ["Penicillin"]
    }
  });

  const family = makeUser({
    id: "user-family-1",
    name: "Asha",
    email: "asha@example.com",
passwordHash: hash(config.demoPassword ?? "CareCircleDemo123"),    role: "family",
    verified: true,
    profile: { contactNumber: "+91-90000-00002" }
  });

  const caregiver = makeUser({
    id: "user-caregiver-1",
    name: "Suresh",
    email: "suresh@example.com",
passwordHash: hash(config.demoPassword ?? "CareCircleDemo123"),    role: "caregiver",
    verified: true,
    profile: { contactNumber: "+91-90000-00003" }
  });

  const admin = makeUser({
    id: "user-admin-1",
    name: "Admin User",
    email: "admin@example.com",
    passwordHash: hash(config.demoPassword),
    role: "admin",
    verified: true,
    profile: { contactNumber: "+91-90000-00004" }
  });

  store.users.push(elder, family, caregiver, admin);

  const careCircle: CareCircle = {
    id: "circle-1",
    elderId: elder.id,
    name: "Rajendran Family Care Circle",
    inviteCode: "CIRCLE-RAJ-001",
    createdByUserId: elder.id,
    createdAt: now.toISOString(),
    members: [
      { userId: elder.id, relation: "elder", acceptedAt: now.toISOString() },
      { userId: family.id, relation: "family", acceptedAt: now.toISOString() },
      { userId: caregiver.id, relation: "caregiver", acceptedAt: now.toISOString() }
    ]
  };

  store.careCircles.push(careCircle);

  const vitals: VitalReading[] = [
    {
      id: "vital-1",
      elderId: elder.id,
      loggedByUserId: elder.id,
      type: "bloodPressure",
      value: 150,
      unit: "mmHg",
      systolic: 150,
      diastolic: 95,
      status: "abnormal",
      thresholdNote: "Blood pressure is above the safe range.",
      createdAt: new Date(now.getTime() - minutes(90)).toISOString()
    },
    {
      id: "vital-2",
      elderId: elder.id,
      loggedByUserId: caregiver.id,
      type: "heartRate",
      value: 78,
      unit: "bpm",
      status: "normal",
      thresholdNote: "Heart rate is within range.",
      createdAt: new Date(now.getTime() - minutes(40)).toISOString()
    }
  ];

  const medicationPlan: MedicationPlan = {
    id: "med-1",
    elderId: elder.id,
    createdByUserId: caregiver.id,
    name: "Amlodipine",
    dosage: "5 mg",
    frequency: "Once daily",
    reminderTime: "08:00",
    active: true,
    createdAt: new Date(now.getTime() - minutes(500)).toISOString()
  };

  const medicationLogs: MedicationLog[] = [
    {
      id: "medlog-1",
      medicationId: medicationPlan.id,
      elderId: elder.id,
      loggedByUserId: elder.id,
      status: "taken",
      dueAt: new Date(now.getTime() - minutes(480)).toISOString(),
      loggedAt: new Date(now.getTime() - minutes(479)).toISOString()
    }
  ];

  const hydrationLogs: HydrationLog[] = [
    {
      id: "hydration-1",
      elderId: elder.id,
      loggedByUserId: elder.id,
      amountMl: 250,
      createdAt: new Date(now.getTime() - minutes(70)).toISOString()
    },
    {
      id: "hydration-2",
      elderId: elder.id,
      loggedByUserId: elder.id,
      amountMl: 250,
      createdAt: new Date(now.getTime() - minutes(20)).toISOString()
    }
  ];

  const exerciseLogs: ExerciseLog[] = [
    {
      id: "exercise-1",
      elderId: elder.id,
      loggedByUserId: caregiver.id,
      activityType: "Walking",
      minutes: 30,
      createdAt: new Date(now.getTime() - minutes(100)).toISOString()
    }
  ];

  const conversations: Conversation[] = [
    {
      id: "chat-1",
      userId: elder.id,
      elderId: elder.id,
      question: "I have a mild headache. What should I do?",
      answer:
        "Drink water, rest in a quiet room, and monitor symptoms. If symptoms worsen or become severe, seek medical help. This guidance is general only and does not replace a clinician.",
      emergencyDetected: false,
      createdAt: new Date(now.getTime() - minutes(30)).toISOString()
    }
  ];

  const notifications: Notification[] = [
    {
      id: "notif-1",
      userId: family.id,
      elderId: elder.id,
      category: "vital",
      title: "Abnormal vital detected",
      body: "Rajendran logged blood pressure 150/95 mmHg.",
      deliveredAt: new Date(now.getTime() - minutes(85)).toISOString(),
      metadata: { severity: "high" }
    },
    {
      id: "notif-2",
      userId: caregiver.id,
      elderId: elder.id,
      category: "medication",
      title: "Medication taken",
      body: "Rajendran marked Amlodipine as taken.",
      deliveredAt: new Date(now.getTime() - minutes(478)).toISOString(),
      metadata: { adherence: 1 }
    }
  ];

  const sosEvents: SosEvent[] = [
    {
      id: "sos-1",
      elderId: elder.id,
      triggeredByUserId: elder.id,
      status: "resolved",
      location: "Home",
      createdAt: new Date(now.getTime() - minutes(200)).toISOString(),
      acknowledgedAt: new Date(now.getTime() - minutes(198)).toISOString(),
      resolvedAt: new Date(now.getTime() - minutes(190)).toISOString()
    }
  ];

  store.vitals.push(...vitals);
  store.medicationPlans.push(medicationPlan);
  store.medicationLogs.push(...medicationLogs);
  store.hydrationLogs.push(...hydrationLogs);
  store.exerciseLogs.push(...exerciseLogs);
  store.conversations.push(...conversations);
  store.notifications.push(...notifications);
  store.sosEvents.push(...sosEvents);

  const files: StoredFileRecord[] = [
    {
      id: "file-report-1",
      name: "weekly-summary-rajendran.pdf",
      mimeType: "application/pdf",
      size: 0,
      path: "seed://weekly-summary-rajendran.pdf",
      uploadedAt: now.toISOString()
    }
  ];

  store.files.push(...files);

  return store;
};
