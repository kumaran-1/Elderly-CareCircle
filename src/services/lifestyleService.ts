
import crypto from "crypto";
import type { Appointment, ExerciseLog, HydrationLog, SystemStore } from "../domain/types";
import type { CareCircleService } from "./careCircleService";
import type { NotificationService } from "./notificationService";

export interface HydrationInput {
  elderId: string;
  loggedByUserId: string;
  amountMl: number;
}

export interface ExerciseInput {
  elderId: string;
  loggedByUserId: string;
  activityType: string;
  minutes: number;
}

export interface AppointmentInput {
  elderId: string;
  createdByUserId: string;
  doctorName: string;
  specialty: string;
  dateTime: string;
  notes?: string;
}

export class LifestyleService {
  constructor(
    private readonly store: SystemStore,
    private readonly circles: CareCircleService,
    private readonly notifications: NotificationService,
    private readonly onChange: () => void = () => undefined
  ) {}

  logHydration(input: HydrationInput): { log: HydrationLog; duplicate: boolean } {
    const now = new Date();
    const duplicate = this.store.hydrationLogs.find(
      (log) =>
        log.elderId === input.elderId &&
        log.loggedByUserId === input.loggedByUserId &&
        log.amountMl === input.amountMl &&
        now.getTime() - new Date(log.createdAt).getTime() >= 0 &&
        now.getTime() - new Date(log.createdAt).getTime() < 60_000
    );

    if (duplicate) return { log: duplicate, duplicate: true };

    const log: HydrationLog = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      loggedByUserId: input.loggedByUserId,
      amountMl: input.amountMl,
      createdAt: now.toISOString()
    };

    this.store.hydrationLogs.push(log);
    this.onChange();
    return { log, duplicate: false };
  }

  logExercise(input: ExerciseInput): { log: ExerciseLog; duplicate: boolean } {
    const now = new Date();
    const duplicate = this.store.exerciseLogs.find(
      (log) =>
        log.elderId === input.elderId &&
        log.loggedByUserId === input.loggedByUserId &&
        log.activityType === input.activityType &&
        log.minutes === input.minutes &&
        now.getTime() - new Date(log.createdAt).getTime() >= 0 &&
        now.getTime() - new Date(log.createdAt).getTime() < 60_000
    );

    if (duplicate) return { log: duplicate, duplicate: true };

    const log: ExerciseLog = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      loggedByUserId: input.loggedByUserId,
      activityType: input.activityType,
      minutes: input.minutes,
      createdAt: now.toISOString()
    };

    this.store.exerciseLogs.push(log);
    this.onChange();
    return { log, duplicate: false };
  }

  createAppointment(input: AppointmentInput): Appointment {
    const date = new Date(input.dateTime);
    if (Number.isNaN(date.getTime())) {
      throw new Error("Invalid appointment date.");
    }

    const appointment: Appointment = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      createdByUserId: input.createdByUserId,
      doctorName: input.doctorName,
      specialty: input.specialty,
      dateTime: date.toISOString(),
      notes: input.notes,
      reminderTimes: [
        new Date(date.getTime() - 24 * 60 * 60 * 1000).toISOString(),
        new Date(date.getTime() - 60 * 60 * 1000).toISOString()
      ],
      createdAt: new Date().toISOString()
    };

    this.store.appointments.push(appointment);
    this.onChange();

    const circle = this.circles.getCircleByElderId(input.elderId);
    if (circle) {
      this.notifications.broadcastToCareCircle(
        circle,
        {
          elderId: input.elderId,
          category: "appointment",
          title: "Appointment scheduled",
          body: `${input.doctorName} is scheduled on ${appointment.dateTime}.`,
          metadata: { doctorName: input.doctorName }
        },
        input.createdByUserId
      );
    }

    return appointment;
  }

  getHydrationSummary(elderId: string) {
    const logs = this.store.hydrationLogs.filter((log) => log.elderId === elderId);
    const total = logs.reduce((sum, log) => sum + log.amountMl, 0);
    return {
      elderId,
      totalMl: total,
      goalMl: 2000,
      progressPercent: Math.min(100, Math.round((total / 2000) * 100))
    };
  }

  getExerciseSummary(elderId: string) {
    const logs = this.store.exerciseLogs.filter((log) => log.elderId === elderId);
    const totalMinutes = logs.reduce((sum, log) => sum + log.minutes, 0);
    return {
      elderId,
      totalMinutes,
      weeklyGoalMinutes: 150,
      progressPercent: Math.min(100, Math.round((totalMinutes / 150) * 100))
    };
  }

  getAppointmentsForElder(elderId: string): Appointment[] {
    return this.store.appointments.filter((appointment) => appointment.elderId === elderId);
  }

  getAppointment(elderId: string, id: string): Appointment {
    const appointment = this.store.appointments.find(
      (item) => item.elderId === elderId && item.id === id
    );
    if (!appointment) throw new Error("Appointment not found.");
    return appointment;
  }

  updateAppointment(
    elderId: string,
    id: string,
    updates: Partial<Pick<Appointment, "doctorName" | "specialty" | "dateTime" | "notes">>
  ): Appointment {
    const appointment = this.getAppointment(elderId, id);

    if (updates.dateTime !== undefined) {
      const date = new Date(updates.dateTime);
      if (Number.isNaN(date.getTime())) throw new Error("Invalid appointment date.");
      appointment.dateTime = date.toISOString();
      appointment.reminderTimes = [
        new Date(date.getTime() - 24 * 60 * 60 * 1000).toISOString(),
        new Date(date.getTime() - 60 * 60 * 1000).toISOString()
      ];
    }

    if (updates.doctorName !== undefined) appointment.doctorName = updates.doctorName;
    if (updates.specialty !== undefined) appointment.specialty = updates.specialty;
    if (updates.notes !== undefined) appointment.notes = updates.notes;

    this.onChange();
    return appointment;
  }

  cancelAppointment(elderId: string, id: string): { cancelled: boolean; appointment: Appointment } {
    const appointment = this.getAppointment(elderId, id);
    this.store.appointments = this.store.appointments.filter((item) => item.id !== id);
    this.onChange();
    return { cancelled: true, appointment };
  }
}
