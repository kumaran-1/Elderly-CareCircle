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

  logHydration(input: HydrationInput): HydrationLog {
    const log: HydrationLog = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      loggedByUserId: input.loggedByUserId,
      amountMl: input.amountMl,
      createdAt: new Date().toISOString()
    };

    this.store.hydrationLogs.push(log);
    this.onChange();
    return log;
  }

  logExercise(input: ExerciseInput): ExerciseLog {
    const log: ExerciseLog = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      loggedByUserId: input.loggedByUserId,
      activityType: input.activityType,
      minutes: input.minutes,
      createdAt: new Date().toISOString()
    };

    this.store.exerciseLogs.push(log);
    this.onChange();
    return log;
  }

  createAppointment(input: AppointmentInput): Appointment {
    const date = new Date(input.dateTime);
    const reminderTimes = [new Date(date.getTime() - 24 * 60 * 60 * 1000), new Date(date.getTime() - 60 * 60 * 1000)].map((value) =>
      value.toISOString()
    );

    const appointment: Appointment = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      createdByUserId: input.createdByUserId,
      doctorName: input.doctorName,
      specialty: input.specialty,
      dateTime: date.toISOString(),
      notes: input.notes,
      reminderTimes,
      createdAt: new Date().toISOString()
    };

    this.store.appointments.push(appointment);
    this.onChange();

    const circle = this.circles.getCircleByElderId(input.elderId);
    if (circle) {
      this.notifications.broadcastToCareCircle(circle, {
        elderId: input.elderId,
        category: "appointment",
        title: "Appointment scheduled",
        body: `${input.doctorName} is scheduled on ${appointment.dateTime}.`,
        metadata: { doctorName: input.doctorName }
      }, input.createdByUserId);
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
}
