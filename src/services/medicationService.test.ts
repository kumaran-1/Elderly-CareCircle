import { describe, it, expect } from "vitest";
import { config } from "../config";
import { createSeedStore } from "../domain/seed";
import { NotificationService } from "./notificationService";
import { CareCircleService } from "./careCircleService";
import { MedicationService, resolveReminderOccurrence } from "./medicationService";
import { medicationSchema, medicationLogSchema } from "../validation/schemas";

function createContext() {
  const store = createSeedStore();
  const notifications = new NotificationService(store);
  const circles = new CareCircleService(store, notifications);
  const medication = new MedicationService(store, circles, notifications);
  // Silence the seed plan so scheduler tests observe only their own plans.
  for (const plan of store.medicationPlans) plan.active = false;
  // Start log-free so adherence assertions reflect only test activity.
  store.medicationLogs.length = 0;
  return { store, notifications, circles, medication };
}

function hhmm(date: Date): string {
  return `${String(date.getHours()).padStart(2, "0")}:${String(date.getMinutes()).padStart(2, "0")}`;
}

function minutesAgo(minutes: number, now = Date.now()): Date {
  return new Date(now - minutes * 60 * 1000);
}

describe("medicationSchema reminder times", () => {
  it.each([["08:00"], ["8:05"], ["14:30"], ["20:00"], ["00:00"], ["23:59"]])("accepts %s", (reminderTime) => {
    expect(
      medicationSchema.safeParse({
        elderId: "user-elder-1",
        name: "Amlodipine",
        dosage: "5 mg",
        frequency: "Once daily",
        reminderTime
      }).success
    ).toBe(true);
  });

  it("accepts a full date-time", () => {
    expect(
      medicationSchema.safeParse({
        elderId: "user-elder-1",
        name: "Amlodipine",
        dosage: "5 mg",
        frequency: "Once daily",
        reminderTime: new Date().toISOString()
      }).success
    ).toBe(true);
  });

  it.each([["missing", {}], ["empty", ""], ["hour out of range", "25:00"], ["junk", "morning-ish"], ["date-only words", "08-00"]])(
    "rejects %s reminder",
    (_label, reminderTime) => {
      expect(
        medicationSchema.safeParse({
          elderId: "user-elder-1",
          name: "Amlodipine",
          dosage: "5 mg",
          frequency: "Once daily",
          ...(reminderTime === undefined ? {} : { reminderTime })
        }).success
      ).toBe(false);
    }
  );

  it("rejects short names and missing fields", () => {
    expect(
      medicationSchema.safeParse({ elderId: "user-elder-1", name: "A", dosage: "5 mg", frequency: "x", reminderTime: "08:00" })
        .success
    ).toBe(false);
  });

  it("rejects arbitrary dose statuses", () => {
    expect(
      medicationLogSchema.safeParse({ elderId: "user-elder-1", status: "gulped" }).success
    ).toBe(false);
    for (const status of ["taken", "snoozed", "skipped", "missed"]) {
      expect(medicationLogSchema.safeParse({ elderId: "user-elder-1", status }).success).toBe(true);
    }
  });
});

describe("resolveReminderOccurrence", () => {
  it("resolves 08:00 to today at 08:00 local time", () => {
    const now = new Date(2026, 4, 10, 12, 0, 0).getTime();
    const occurrence = resolveReminderOccurrence("08:00", now);
    expect(occurrence).not.toBeNull();
    const date = new Date(occurrence!);
    expect([date.getHours(), date.getMinutes()]).toEqual([8, 0]);
    expect([date.getFullYear(), date.getMonth(), date.getDate()]).toEqual([2026, 4, 10]);
  });

  it.each([["14:30", 14, 30], ["20:00", 20, 0]])("resolves %s", (input, hours, minutes) => {
    const occurrence = resolveReminderOccurrence(input, Date.now());
    const date = new Date(occurrence!);
    expect([date.getHours(), date.getMinutes()]).toEqual([hours, minutes]);
  });

  it("passes full date-times through and rejects garbage", () => {
    const iso = new Date(2026, 4, 10, 9, 30).toISOString();
    // Absolute ISO strings resolve to their own instant.
    expect(resolveReminderOccurrence(iso, Date.now())).toBe(Date.parse(iso));
    expect(resolveReminderOccurrence("not-a-time", Date.now())).toBeNull();
    expect(resolveReminderOccurrence("", Date.now())).toBeNull();
  });

  it("interprets HH:MM on the server-local calendar day across midnight", () => {
    // 23:50 local: 23:55 is later today, 00:05 already passed today.
    const late = new Date(2026, 4, 10, 23, 50, 0).getTime();
    const before = new Date(resolveReminderOccurrence("00:05", late)!);
    const after = new Date(resolveReminderOccurrence("23:55", late)!);
    expect([before.getHours(), before.getMinutes()]).toEqual([0, 5]);
    expect([after.getHours(), after.getMinutes()]).toEqual([23, 55]);
    expect([before.getFullYear(), before.getMonth(), before.getDate()]).toEqual([2026, 4, 10]);
    expect(after.getTime()).toBeGreaterThan(late);
    expect(before.getTime()).toBeLessThan(late);
  });
});

describe("MedicationService scheduler", () => {
  it("fires a time-of-day reminder once within the window", () => {
    const { store, notifications, medication } = createContext();
    const now = Date.now();
    const plan = medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-caregiver-1",
      name: "Morning Pill",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: hhmm(minutesAgo(2, now))
    });
    const before = notifications.listForUser("user-family-1").length;
    medication.checkAndSendReminders(now);
    expect(notifications.listForUser("user-family-1").length).toBe(before + 1);
    expect(plan.lastReminderAt).toBeDefined();
    // One broadcast reaches every circle member; the second tick must not
    // send anything further for the same occurrence.
    const reminders = () =>
      store.notifications.filter((n) => n.category === "medication" && n.title === "Medication reminder").length;
    const fired = reminders();

    medication.checkAndSendReminders(now + 60 * 1000);
    expect(notifications.listForUser("user-family-1").length).toBe(before + 1);
    expect(reminders()).toBe(fired);
  });

  it("handles multiple medications with different reminder times", () => {
    const { notifications, medication } = createContext();
    const now = Date.now();
    medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-caregiver-1",
      name: "Due Now",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: hhmm(minutesAgo(2, now))
    });
    medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-caregiver-1",
      name: "Due Later",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: hhmm(new Date(now + 3 * 60 * 60 * 1000))
    });
    const before = notifications.listForUser("user-family-1").length;
    medication.checkAndSendReminders(now);
    const bodies = notifications
      .listForUser("user-family-1")
      .slice(before)
      .map((n) => n.body);
    expect(bodies).toHaveLength(1);
    expect(bodies[0]).toContain("Due Now");
  });

  it("ignores future and long-missed reminders", () => {
    const { notifications, medication } = createContext();
    const now = Date.now();
    medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-caregiver-1",
      name: "Future",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: hhmm(new Date(now + 2 * 60 * 60 * 1000))
    });
    medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-caregiver-1",
      name: "Stale",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: hhmm(new Date(now - (config.medicationResponseWindowMinutes + 30) * 60 * 1000))
    });
    const before = notifications.listForUser("user-family-1").length;
    medication.checkAndSendReminders(now);
    expect(notifications.listForUser("user-family-1").length).toBe(before);
  });

  it("skips inactive plans", () => {
    const { store, notifications, medication } = createContext();
    const now = Date.now();
    const plan = medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-caregiver-1",
      name: "Paused",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: hhmm(minutesAgo(2, now))
    });
    plan.active = false;
    const before = notifications.listForUser("user-family-1").length;
    medication.checkAndSendReminders(now);
    expect(notifications.listForUser("user-family-1").length).toBe(before);
    expect(store.notifications.filter((n) => n.title === "Medication reminder")).toHaveLength(0);
  });

  it("does not remind when the dose was already taken", () => {
    const { notifications, medication } = createContext();
    const now = Date.now();
    const plan = medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-elder-1",
      name: "Early Dose",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: hhmm(minutesAgo(2, now))
    });
    medication.logDose({
      medicationId: plan.id,
      elderId: "user-elder-1",
      loggedByUserId: "user-elder-1",
      status: "taken"
    });
    const before = notifications.listForUser("user-family-1").length;
    medication.checkAndSendReminders(now);
    expect(notifications.listForUser("user-family-1").length).toBe(before);
  });

  it("re-arms the reminder after a snooze", () => {
    const { notifications, medication } = createContext();
    const now = Date.now();
    const plan = medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-elder-1",
      name: "Snoozed",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: hhmm(minutesAgo(2, now))
    });
    medication.checkAndSendReminders(now);
    const before = notifications.listForUser("user-family-1").length;
    const snooze = medication.logDose({
      medicationId: plan.id,
      elderId: "user-elder-1",
      loggedByUserId: "user-elder-1",
      status: "snoozed"
    });
    expect(snooze.duplicate).toBe(false);
    medication.checkAndSendReminders(now + 60 * 1000);
    expect(notifications.listForUser("user-family-1").length).toBe(before + 1);
  });
});

describe("MedicationService dose logging", () => {
  it("rejects logs for unknown plans or mismatched elders", () => {
    const { medication } = createContext();
    expect(() =>
      medication.logDose({ medicationId: "nope", elderId: "user-elder-1", loggedByUserId: "user-elder-1", status: "taken" })
    ).toThrow(/not found/i);
    const plan = medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-caregiver-1",
      name: "Scoped",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: "08:00"
    });
    expect(() =>
      medication.logDose({ medicationId: plan.id, elderId: "user-family-1", loggedByUserId: "user-family-1", status: "taken" })
    ).toThrow(/does not belong/i);
  });

  it("treats rapid duplicate submissions as one event", () => {
    const { store, medication } = createContext();
    const plan = medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-elder-1",
      name: "Double Tap",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: "08:00"
    });
    const input = { medicationId: plan.id, elderId: "user-elder-1", loggedByUserId: "user-elder-1", status: "taken" as const };
    const first = medication.logDose(input);
    const second = medication.logDose(input);
    expect(first.duplicate).toBe(false);
    expect(second.duplicate).toBe(true);
    expect(second.log.id).toBe(first.log.id);
    expect(store.medicationLogs.filter((l) => l.medicationId === plan.id)).toHaveLength(1);
  });

  it("calculates adherence from the underlying logs", () => {
    const { medication } = createContext();
    const plan = medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-caregiver-1",
      name: "Adherence",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: "08:00"
    });
    const by = (status: "taken" | "skipped" | "missed", user: string) =>
      medication.logDose({ medicationId: plan.id, elderId: "user-elder-1", loggedByUserId: user, status });
    by("taken", "user-elder-1");
    const summary = medication.getSummary("user-elder-1");
    // One active plan, one taken log: full adherence from the logs.
    expect(summary.totalScheduled).toBe(1);
    expect(summary.taken).toBe(1);
    expect(summary.adherencePercent).toBe(100);
    by("skipped", "user-caregiver-1");
    by("missed", "user-caregiver-1");
    const after = medication.getSummary("user-elder-1");
    expect(after.missed).toBe(1);
    expect(after.taken).toBe(1);
    expect(after.adherencePercent).toBe(100);
  });

  it("notifies the circle on missed doses without notifying outsiders", () => {
    const { notifications, medication } = createContext();
    const plan = medication.createPlan({
      elderId: "user-elder-1",
      createdByUserId: "user-caregiver-1",
      name: "Evening",
      dosage: "1 tablet",
      frequency: "Once daily",
      reminderTime: "20:00"
    });
    const beforeFamily = notifications.listForUser("user-family-1").length;
    const missed = medication.logDose({
      medicationId: plan.id,
      elderId: "user-elder-1",
      loggedByUserId: "user-caregiver-1",
      status: "missed"
    });
    expect(missed.duplicate).toBe(false);
    expect(notifications.listForUser("user-family-1").length).toBe(beforeFamily + 1);
    const alert = notifications.listForUser("user-family-1").at(-1)!;
    expect(alert.category).toBe("medication");
    expect(alert.elderId).toBe("user-elder-1");
  });
});
