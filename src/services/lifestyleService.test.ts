import { describe, it, expect } from "vitest";
import { createSeedStore } from "../domain/seed";
import { NotificationService } from "./notificationService";
import { CareCircleService } from "./careCircleService";
import {
  LifestyleService,
  DAILY_HYDRATION_GOAL_ML,
  WEEKLY_EXERCISE_GOAL_MINUTES
} from "./lifestyleService";
import { hydrationSchema, exerciseSchema, appointmentUpdateSchema, appointmentCancelSchema } from "../validation/schemas";

function createContext() {
  const store = createSeedStore();
  const notifications = new NotificationService(store);
  const circles = new CareCircleService(store, notifications);
  const lifestyle = new LifestyleService(store, circles, notifications);
  // Start log-free so aggregation assertions reflect only test activity.
  store.hydrationLogs.length = 0;
  store.exerciseLogs.length = 0;
  return { store, notifications, circles, lifestyle };
}

const ELDER = "user-elder-1";
const BY = "user-elder-1";

describe("hydration validation", () => {
  it("accepts valid intake values", () => {
    for (const amountMl of [150, 250, 250.5, 2000]) {
      expect(hydrationSchema.safeParse({ elderId: ELDER, amountMl }).success).toBe(true);
    }
  });

  it.each([
    ["zero", 0],
    ["negative", -250],
    ["string", "250"],
    ["missing", undefined],
    ["NaN-like text", "two-fifty"]
  ])("rejects %s intake", (_label, amountMl) => {
    expect(hydrationSchema.safeParse({ elderId: ELDER, amountMl }).success).toBe(false);
  });

  it("rejects a missing elderId", () => {
    expect(hydrationSchema.safeParse({ amountMl: 250 }).success).toBe(false);
  });
});

describe("exercise validation", () => {
  it("accepts valid activities", () => {
    expect(exerciseSchema.safeParse({ elderId: ELDER, activityType: "Walking", minutes: 30 }).success).toBe(true);
    expect(exerciseSchema.safeParse({ elderId: ELDER, activityType: "Yoga", minutes: 12.5 }).success).toBe(true);
  });

  it.each([
    ["zero minutes", { elderId: ELDER, activityType: "Walking", minutes: 0 }],
    ["negative minutes", { elderId: ELDER, activityType: "Walking", minutes: -10 }],
    ["string minutes", { elderId: ELDER, activityType: "Walking", minutes: "30" }],
    ["short activity", { elderId: ELDER, activityType: "X", minutes: 30 }],
    ["missing activity", { elderId: ELDER, minutes: 30 }],
    ["missing elderId", { activityType: "Walking", minutes: 30 }]
  ])("rejects %s", (_label, body) => {
    expect(exerciseSchema.safeParse(body).success).toBe(false);
  });
});

describe("hydration summaries", () => {
  it("aggregates multiple same-day entries against the in-project daily goal", () => {
    const { lifestyle } = createContext();
    expect(DAILY_HYDRATION_GOAL_ML).toBe(2000);
    lifestyle.logHydration({ elderId: ELDER, loggedByUserId: BY, amountMl: 250 });
    lifestyle.logHydration({ elderId: ELDER, loggedByUserId: BY, amountMl: 500 });
    const summary = lifestyle.getHydrationSummary(ELDER);
    expect(summary.totalMl).toBe(750);
    expect(summary.goalMl).toBe(DAILY_HYDRATION_GOAL_ML);
    expect(summary.progressPercent).toBe(Math.round((750 / 2000) * 100));
  });

  it("caps progress at 100 for excess intake without dropping the total", () => {
    const { lifestyle } = createContext();
    lifestyle.logHydration({ elderId: ELDER, loggedByUserId: BY, amountMl: 2500 });
    const summary = lifestyle.getHydrationSummary(ELDER);
    expect(summary.totalMl).toBe(2500);
    expect(summary.progressPercent).toBe(100);
  });

  it("rolls over at the local day boundary", () => {
    const { store, lifestyle } = createContext();
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);
    store.hydrationLogs.push({
      id: "yesterday",
      elderId: ELDER,
      loggedByUserId: BY,
      amountMl: 999,
      createdAt: new Date(startOfToday.getTime() - 1).toISOString()
    });
    lifestyle.logHydration({ elderId: ELDER, loggedByUserId: BY, amountMl: 250 });
    const summary = lifestyle.getHydrationSummary(ELDER);
    expect(summary.totalMl).toBe(250);
  });

  it("isolates totals per elder", () => {
    const { lifestyle } = createContext();
    lifestyle.logHydration({ elderId: ELDER, loggedByUserId: BY, amountMl: 250 });
    expect(lifestyle.getHydrationSummary("user-family-1").totalMl).toBe(0);
  });

  it("treats rapid identical submissions as one event", () => {
    const { store, lifestyle } = createContext();
    const first = lifestyle.logHydration({ elderId: ELDER, loggedByUserId: BY, amountMl: 250 });
    const second = lifestyle.logHydration({ elderId: ELDER, loggedByUserId: BY, amountMl: 250 });
    expect(first.duplicate).toBe(false);
    expect(second.duplicate).toBe(true);
    expect(second.log.id).toBe(first.log.id);
    expect(store.hydrationLogs.filter((l) => l.elderId === ELDER)).toHaveLength(1);
    expect(lifestyle.getHydrationSummary(ELDER).totalMl).toBe(250);
  });

  it("stores distinct amounts separately", () => {
    const { store, lifestyle } = createContext();
    lifestyle.logHydration({ elderId: ELDER, loggedByUserId: BY, amountMl: 250 });
    const other = lifestyle.logHydration({ elderId: ELDER, loggedByUserId: BY, amountMl: 500 });
    expect(other.duplicate).toBe(false);
    expect(store.hydrationLogs.filter((l) => l.elderId === ELDER)).toHaveLength(2);
  });
});

describe("exercise summaries", () => {
  it("aggregates the current week against the in-project weekly goal", () => {
    const { lifestyle } = createContext();
    expect(WEEKLY_EXERCISE_GOAL_MINUTES).toBe(150);
    lifestyle.logExercise({ elderId: ELDER, loggedByUserId: BY, activityType: "walking", minutes: 30 });
    lifestyle.logExercise({ elderId: ELDER, loggedByUserId: BY, activityType: "yoga", minutes: 45 });
    const summary = lifestyle.getExerciseSummary(ELDER);
    expect(summary.totalMinutes).toBe(75);
    expect(summary.weeklyGoalMinutes).toBe(WEEKLY_EXERCISE_GOAL_MINUTES);
    expect(summary.progressPercent).toBe(50);
  });

  it("excludes logs from prior weeks", () => {
    const { store, lifestyle } = createContext();
    store.exerciseLogs.push({
      id: "old",
      elderId: ELDER,
      loggedByUserId: BY,
      activityType: "walking",
      minutes: 120,
      createdAt: new Date(Date.now() - 8 * 24 * 60 * 60 * 1000).toISOString()
    });
    lifestyle.logExercise({ elderId: ELDER, loggedByUserId: BY, activityType: "walking", minutes: 30 });
    expect(lifestyle.getExerciseSummary(ELDER).totalMinutes).toBe(30);
  });

  it("treats rapid identical submissions as one event", () => {
    const { store, lifestyle } = createContext();
    const input = { elderId: ELDER, loggedByUserId: BY, activityType: "walking", minutes: 30 };
    const first = lifestyle.logExercise(input);
    const second = lifestyle.logExercise(input);
    expect(first.duplicate).toBe(false);
    expect(second.duplicate).toBe(true);
    expect(store.exerciseLogs.filter((l) => l.elderId === ELDER)).toHaveLength(1);
    expect(lifestyle.getExerciseSummary(ELDER).totalMinutes).toBe(30);
  });

  it("keeps distinct activities and durations as separate records", () => {
    const { store, lifestyle } = createContext();
    lifestyle.logExercise({ elderId: ELDER, loggedByUserId: BY, activityType: "walking", minutes: 30 });
    lifestyle.logExercise({ elderId: ELDER, loggedByUserId: BY, activityType: "walking", minutes: 45 });
    lifestyle.logExercise({ elderId: ELDER, loggedByUserId: BY, activityType: "yoga", minutes: 30 });
    expect(store.exerciseLogs.filter((l) => l.elderId === ELDER)).toHaveLength(3);
    expect(lifestyle.getExerciseSummary(ELDER).totalMinutes).toBe(105);
  });
});

describe("appointment update schemas", () => {
  it("requires elderId and at least one updatable field", () => {
    expect(
      appointmentUpdateSchema.safeParse({ elderId: ELDER, doctorName: "Dr. Rao" }).success
    ).toBe(true);
    expect(appointmentUpdateSchema.safeParse({ elderId: ELDER }).success).toBe(false);
    expect(appointmentUpdateSchema.safeParse({ doctorName: "Dr. Rao" }).success).toBe(false);
    expect(
      appointmentUpdateSchema.safeParse({ elderId: ELDER, doctorName: "X" }).success
    ).toBe(false);
    expect(
      appointmentUpdateSchema.safeParse({ elderId: ELDER, dateTime: "tomorrow" }).success
    ).toBe(false);
    expect(appointmentCancelSchema.safeParse({ elderId: ELDER }).success).toBe(true);
    expect(appointmentCancelSchema.safeParse({}).success).toBe(false);
  });
});

describe("appointment management", () => {
  function createAppointment(lifestyle: LifestyleService, dateTime: string) {
    return lifestyle.createAppointment({
      elderId: ELDER,
      createdByUserId: ELDER,
      doctorName: "Dr. Rao",
      specialty: "Cardiology",
      dateTime,
      notes: "Bring reports"
    });
  }

  it("reads an appointment by ID within the elder's scope", () => {
    const { lifestyle } = createContext();
    const created = createAppointment(lifestyle, new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString());
    expect(lifestyle.getAppointment(ELDER, created.id).doctorName).toBe("Dr. Rao");
    expect(() => lifestyle.getAppointment(ELDER, "no-such-id")).toThrow(/not found/i);
    expect(() => lifestyle.getAppointment("user-family-1", created.id)).toThrow(/not found/i);
  });

  it("updates fields and recalculates reminders on reschedule", () => {
    const { lifestyle } = createContext();
    const created = createAppointment(lifestyle, new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString());
    const renamed = lifestyle.updateAppointment(ELDER, created.id, { doctorName: "Dr. Rao Jr" });
    expect(renamed.doctorName).toBe("Dr. Rao Jr");
    expect(renamed.reminderTimes).toEqual(created.reminderTimes);

    const nextWeek = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    const rescheduled = lifestyle.updateAppointment(ELDER, created.id, { dateTime: nextWeek });
    expect(rescheduled.dateTime).toBe(new Date(nextWeek).toISOString());
    expect(rescheduled.reminderTimes[0]).toBe(
      new Date(new Date(nextWeek).getTime() - 24 * 60 * 60 * 1000).toISOString()
    );
    expect(rescheduled.remindersSent).toEqual([]);
  });

  it("rejects invalid updates and updates to cancelled appointments", () => {
    const { lifestyle } = createContext();
    const created = createAppointment(lifestyle, new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString());
    expect(() => lifestyle.updateAppointment(ELDER, "nope", { doctorName: "Dr. X" })).toThrow(/not found/i);
    expect(() => lifestyle.updateAppointment(ELDER, created.id, { dateTime: "soon-ish" })).toThrow();
    lifestyle.cancelAppointment(ELDER, created.id);
    expect(() => lifestyle.updateAppointment(ELDER, created.id, { doctorName: "Dr. X" })).toThrow(/cancelled/i);
  });

  it("cancels idempotently and reports unknown IDs", () => {
    const { lifestyle } = createContext();
    const created = createAppointment(lifestyle, new Date(Date.now() + 48 * 60 * 60 * 1000).toISOString());
    const first = lifestyle.cancelAppointment(ELDER, created.id);
    expect(first.appointment.status).toBe("cancelled");
    expect(first.alreadyCancelled).toBe(false);
    const second = lifestyle.cancelAppointment(ELDER, created.id);
    expect(second.alreadyCancelled).toBe(true);
    expect(() => lifestyle.cancelAppointment(ELDER, "nope")).toThrow(/not found/i);
    expect(() => lifestyle.cancelAppointment("user-family-1", created.id)).toThrow(/not found/i);
  });
});

describe("appointment reminders", () => {
  function futureAppointment(lifestyle: LifestyleService, hoursAhead: number) {
    return lifestyle.createAppointment({
      elderId: ELDER,
      createdByUserId: ELDER,
      doctorName: "Dr. Rao",
      specialty: "Cardiology",
      dateTime: new Date(Date.now() + hoursAhead * 60 * 60 * 1000).toISOString()
    });
  }

  function reminderTitles(store: ReturnType<typeof createSeedStore>): string[] {
    // One broadcast reaches every circle member with the same reminderTime
    // metadata, so delivery is counted per distinct reminder timestamp.
    return [
      ...new Set(
        store.notifications
          .filter((n) => n.category === "appointment" && n.title === "Appointment reminder")
          .map((n) => (n.metadata as Record<string, string>)?.reminderTime ?? "")
      )
    ];
  }

  it("fires the due T-24h reminder exactly once across ticks", () => {
    const { store, notifications, lifestyle } = createContext();
    futureAppointment(lifestyle, 24);
    const before = notifications.listForUser("user-family-1").length;

    lifestyle.checkAndSendAppointmentReminders();
    expect(notifications.listForUser("user-family-1").length).toBe(before + 1);
    expect(reminderTitles(store)).toHaveLength(1);

    lifestyle.checkAndSendAppointmentReminders();
    lifestyle.checkAndSendAppointmentReminders(Date.now() + 60 * 1000);
    expect(notifications.listForUser("user-family-1").length).toBe(before + 1);
    expect(reminderTitles(store)).toHaveLength(1);
  });

  it("survives restarts via persisted delivery records", () => {
    const { store, notifications, lifestyle } = createContext();
    const created = futureAppointment(lifestyle, 24);
    lifestyle.checkAndSendAppointmentReminders();
    expect(created.remindersSent).toHaveLength(1);

    // A fresh service over the same persisted store must not duplicate.
    const restarted = new LifestyleService(store, new CareCircleService(store, notifications), notifications);
    const before = notifications.listForUser("user-family-1").length;
    restarted.checkAndSendAppointmentReminders();
    expect(notifications.listForUser("user-family-1").length).toBe(before);
  });

  it("skips cancelled, past, and invalid appointments without crashing", () => {
    const { store, notifications, lifestyle } = createContext();
    const cancelled = futureAppointment(lifestyle, 24);
    lifestyle.cancelAppointment(ELDER, cancelled.id);
    const past = lifestyle.createAppointment({
      elderId: ELDER,
      createdByUserId: ELDER,
      doctorName: "Dr. Old",
      specialty: "General",
      dateTime: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString()
    });
    store.appointments.push({
      id: "broken",
      elderId: ELDER,
      createdByUserId: ELDER,
      doctorName: "Dr. Broken",
      specialty: "General",
      dateTime: "not-a-date",
      reminderTimes: ["also-not-a-date"],
      status: "scheduled",
      createdAt: new Date().toISOString()
    });
    void past;
    const before = store.notifications.length;
    lifestyle.checkAndSendAppointmentReminders();
    expect(store.notifications.length).toBe(before);
    expect(notifications.listForUser("user-family-1").length).toBe(
      notifications.listForUser("user-family-1").length
    );
  });

  it("withholds reminders for appointments without a circle", () => {
    const { store, lifestyle } = createContext();
    const before = store.notifications.length;
    lifestyle.createAppointment({
      elderId: "user-family-1",
      createdByUserId: "user-family-1",
      doctorName: "Dr. Solo",
      specialty: "General",
      dateTime: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
    });
    lifestyle.checkAndSendAppointmentReminders();
    expect(store.notifications.length).toBe(before);
  });
});
