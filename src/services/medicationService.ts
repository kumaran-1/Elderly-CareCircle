import crypto from "crypto";
import type { MedicationLog, MedicationPlan, SystemStore } from "../domain/types";
import type { CareCircleService } from "./careCircleService";
import type { NotificationService } from "./notificationService";

export interface MedicationPlanInput {
  elderId: string;
  createdByUserId: string;
  name: string;
  dosage: string;
  frequency: string;
  reminderTime: string;
}

export interface MedicationLogInput {
  medicationId: string;
  elderId: string;
  loggedByUserId: string;
  status: MedicationLog["status"];
  dueAt?: string;
}

export class MedicationService {
  constructor(
    private readonly store: SystemStore,
    private readonly circles: CareCircleService,
    private readonly notifications: NotificationService,
    private readonly onChange: () => void = () => undefined
  ) {}

  createPlan(input: MedicationPlanInput): MedicationPlan {
    const plan: MedicationPlan = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      createdByUserId: input.createdByUserId,
      name: input.name,
      dosage: input.dosage,
      frequency: input.frequency,
      reminderTime: input.reminderTime,
      active: true,
      createdAt: new Date().toISOString()
    };

    this.store.medicationPlans.push(plan);
    this.onChange();
    return plan;
  }

  logDose(input: MedicationLogInput): { log: MedicationLog; adherencePercent: number } {
    const log: MedicationLog = {
      id: crypto.randomUUID(),
      medicationId: input.medicationId,
      elderId: input.elderId,
      loggedByUserId: input.loggedByUserId,
      status: input.status,
      dueAt: input.dueAt ?? new Date().toISOString(),
      loggedAt: new Date().toISOString()
    };

    this.store.medicationLogs.push(log);
    this.onChange();
    const summary = this.getSummary(input.elderId);
    const circle = this.circles.getCircleByElderId(input.elderId);

    if (circle && (input.status === "missed" || input.status === "skipped")) {
      this.notifications.broadcastToCareCircle(circle, {
        elderId: input.elderId,
        category: "medication",
        title: input.status === "missed" ? "Medication missed" : "Medication skipped",
        body: `Medication ${input.status} for elder profile ${input.elderId}.`,
        metadata: { status: input.status }
      }, input.loggedByUserId);
    }

    return { log, adherencePercent: summary.adherencePercent };
  }

  getPlansForElder(elderId: string): MedicationPlan[] {
    return this.store.medicationPlans.filter((plan) => plan.elderId === elderId);
  }

  getLogsForElder(elderId: string): MedicationLog[] {
    return this.store.medicationLogs.filter((log) => log.elderId === elderId);
  }

  getSummary(elderId: string) {
    const logs = this.getLogsForElder(elderId);
    const completed = logs.filter((log) => log.status === "taken").length;
    const total = Math.max(logs.length, this.getPlansForElder(elderId).length || 0);
    const adherencePercent = total === 0 ? 0 : Math.round((completed / total) * 100);

    return {
      elderId,
      totalScheduled: total,
      taken: completed,
      missed: logs.filter((log) => log.status === "missed").length,
      adherencePercent
    };
  }
}
