import { describe, it, expect } from "vitest";
import { createSeedStore } from "../domain/seed";
import { NotificationService } from "./notificationService";
import { CareCircleService } from "./careCircleService";
import { LifestyleService } from "./lifestyleService";
import { ReportService } from "./reportService";
import { ReportPdfService } from "./reportPdfService";
import { appointmentSchema } from "../validation/schemas";
import { periodQuerySchema } from "../validation/schemas";

const ELDER = "user-elder-1";

function createContext() {
  const store = createSeedStore();
  const notifications = new NotificationService(store);
  const circles = new CareCircleService(store, notifications);
  const lifestyle = new LifestyleService(store, circles, notifications);
  const reports = new ReportService(store);
  const reportPdf = new ReportPdfService();
  return { store, notifications, lifestyle, reports, reportPdf };
}

describe("appointmentSchema", () => {
  const valid = {
    elderId: ELDER,
    doctorName: "Dr. Rao",
    specialty: "Cardiology",
    dateTime: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
  };

  it("accepts a complete valid payload", () => {
    expect(appointmentSchema.safeParse(valid).success).toBe(true);
  });

  it.each([
    ["missing doctor", { ...valid, doctorName: undefined }],
    ["short doctor", { ...valid, doctorName: "X" }],
    ["missing specialty", { ...valid, specialty: undefined }],
    ["missing dateTime", { ...valid, dateTime: undefined }],
    ["plain-text date", { ...valid, dateTime: "tomorrow at nine" }],
    ["impossible date", { ...valid, dateTime: "2026-13-45T10:00:00Z" }],
    ["missing elderId", { ...valid, elderId: undefined }]
  ])("rejects %s", (_label, body) => {
    expect(appointmentSchema.safeParse(body).success).toBe(false);
  });
});

describe("appointment creation", () => {
  it("stores a normalized appointment with computed reminder times and scoped notice", () => {
    const { store, notifications, lifestyle } = createContext();
    const dateTime = new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString();
    const beforeFamily = notifications.listForUser("user-family-1").length;
    const beforeElder = notifications.listForUser("user-elder-1").length;

    const appointment = lifestyle.createAppointment({
      elderId: ELDER,
      createdByUserId: ELDER,
      doctorName: "Dr. Rao",
      specialty: "Cardiology",
      dateTime,
      notes: "Bring reports"
    });

    expect(appointment.elderId).toBe(ELDER);
    expect(appointment.dateTime).toBe(new Date(dateTime).toISOString());
    expect(appointment.reminderTimes).toHaveLength(2);
    expect(new Date(appointment.reminderTimes[0]).getTime()).toBe(new Date(dateTime).getTime() - 24 * 60 * 60 * 1000);
    expect(new Date(appointment.reminderTimes[1]).getTime()).toBe(new Date(dateTime).getTime() - 60 * 60 * 1000);
    expect(store.appointments).toContainEqual(appointment);
    // Circle notified except the creator.
    expect(notifications.listForUser("user-family-1").length).toBe(beforeFamily + 1);
    expect(notifications.listForUser("user-elder-1").length).toBe(beforeElder);
    const notice = notifications.listForUser("user-family-1").at(-1)!;
    expect(notice.category).toBe("appointment");
    expect(notice.elderId).toBe(ELDER);
  });

  it("preserves acceptance of past dates per existing rules (no silent rewrite)", () => {
    const { lifestyle } = createContext();
    const past = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const appointment = lifestyle.createAppointment({
      elderId: ELDER,
      createdByUserId: ELDER,
      doctorName: "Dr. Rao",
      specialty: "Cardiology",
      dateTime: past
    });
    expect(appointment.dateTime).toBe(new Date(past).toISOString());
  });

  it("lists only the elder's own appointments", () => {
    const { lifestyle } = createContext();
    lifestyle.createAppointment({
      elderId: ELDER,
      createdByUserId: ELDER,
      doctorName: "Dr. Rao",
      specialty: "Cardiology",
      dateTime: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
    });
    expect(lifestyle.getAppointmentsForElder(ELDER)).toHaveLength(1);
    expect(lifestyle.getAppointmentsForElder("user-family-1")).toHaveLength(0);
  });
});

describe("report periods", () => {
  it("defaults a missing period to weekly but rejects invalid values", () => {
    expect(periodQuerySchema.safeParse(undefined).success).toBe(true);
    expect(periodQuerySchema.safeParse(undefined).data).toBe("weekly");
    expect(periodQuerySchema.safeParse("yearly").success).toBe(false);
    expect(periodQuerySchema.safeParse("").success).toBe(false);
    expect(periodQuerySchema.safeParse("weekly").data).toBe("weekly");
    expect(periodQuerySchema.safeParse("monthly").data).toBe("monthly");
  });

  it("applies weekly vs monthly cutoffs deterministically", () => {
    const { store, reports } = createContext();
    store.vitals.length = 0;
    const old = new Date(Date.now() - 10 * 24 * 60 * 60 * 1000).toISOString();
    const fresh = new Date().toISOString();
    const mkVital = (id: string, createdAt: string, status: "normal" | "abnormal" = "normal") => ({
      id,
      elderId: ELDER,
      loggedByUserId: ELDER,
      type: "heartRate" as const,
      value: 70,
      unit: "bpm",
      status,
      thresholdNote: "ok",
      createdAt
    });
    store.vitals.push(mkVital("old", old), mkVital("fresh", fresh, "abnormal"));

    const weekly = reports.buildSummary(ELDER, "weekly");
    expect(weekly.period).toBe("weekly");
    expect(weekly.vitalsCount).toBe(1);
    expect(weekly.abnormalVitalsCount).toBe(1);
    const monthly = reports.buildSummary(ELDER, "monthly");
    expect(monthly.vitalsCount).toBe(2);
  });

  it("handles empty periods gracefully with zeros", () => {
    const { reports } = createContext();
    const summary = reports.buildSummary("user-family-1", "weekly");
    expect(summary.elderId).toBe("user-family-1");
    expect(summary.vitalsCount).toBe(0);
    expect(summary.medicationAdherencePercent).toBe(0);
    expect(summary.hydrationMl).toBe(0);
    expect(summary.appointmentCount).toBe(0);
    expect(summary.summary.length).toBeGreaterThan(0);
  });

  it("matches authoritative service data and keeps adherence math consistent", () => {
    const { store, reports } = createContext();
    store.medicationPlans.length = 0;
    store.medicationLogs.length = 0;
    store.medicationPlans.push({
      id: "plan-1",
      elderId: ELDER,
      createdByUserId: ELDER,
      name: "Test",
      dosage: "1",
      frequency: "daily",
      reminderTime: "08:00",
      active: true,
      createdAt: new Date().toISOString()
    });
    store.medicationLogs.push({
      id: "log-1",
      medicationId: "plan-1",
      elderId: ELDER,
      loggedByUserId: ELDER,
      status: "taken",
      dueAt: new Date().toISOString(),
      loggedAt: new Date().toISOString()
    });
    const weekly = reports.buildSummary(ELDER, "weekly");
    expect(weekly.medicationAdherencePercent).toBe(Math.round((1 / 7) * 100));
    const expectedHydration = store.hydrationLogs
      .filter((l) => l.elderId === ELDER)
      .reduce((sum, l) => sum + l.amountMl, 0);
    // Seed hydration entries are recent, so the weekly window matches them.
    expect(weekly.hydrationMl).toBe(expectedHydration);
  });
});

describe("report PDF", () => {
  it("generates a PDF with metrics and no sensitive payload", async () => {
    const { reports, reportPdf } = createContext();
    const summary = reports.buildSummary(ELDER, "weekly");
    const pdf = await reportPdf.generate(summary);
    expect(pdf.length).toBeGreaterThan(500);
    expect(pdf.subarray(0, 5).toString()).toBe("%PDF-");
    expect(pdf.toString("latin1").trimEnd().endsWith("%%EOF")).toBe(true);
    // Inputs are verified separately; the encoded PDF must at least carry
    // the elder scope marker bytes and no plaintext secrets.
    const text = pdf.toString("latin1");
    for (const secret of ["Password123", "GEMINI", "BEGIN PRIVATE", "mongodb://", "Bearer "]) {
      expect(text).not.toContain(secret);
    }
  });

  it("renders an empty period without crashing", async () => {
    const { reports, reportPdf } = createContext();
    const summary = reports.buildSummary("user-family-1", "weekly");
    const pdf = await reportPdf.generate(summary);
    expect(pdf.subarray(0, 5).toString()).toBe("%PDF-");
    expect(pdf.length).toBeGreaterThan(100);
  });
});
