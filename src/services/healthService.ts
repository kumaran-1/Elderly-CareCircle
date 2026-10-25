import crypto from "crypto";
import type { SystemStore, VitalReading, VitalType } from "../domain/types";
import type { CareCircleService } from "./careCircleService";
import type { NotificationService } from "./notificationService";

export interface VitalInput {
  elderId: string;
  loggedByUserId: string;
  type: VitalType;
  value: number;
  unit: string;
  systolic?: number;
  diastolic?: number;
}

export class HealthService {
  constructor(
    private readonly store: SystemStore,
    private readonly circles: CareCircleService,
    private readonly notifications: NotificationService,
    private readonly onChange: () => void = () => undefined
  ) {}

  logVital(input: VitalInput): { reading: VitalReading; alerted: boolean } {
    const evaluation = this.evaluate(input);
    const reading: VitalReading = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      loggedByUserId: input.loggedByUserId,
      type: input.type,
      value: input.value,
      unit: input.unit,
      systolic: input.systolic,
      diastolic: input.diastolic,
      status: evaluation.status,
      thresholdNote: evaluation.note,
      createdAt: new Date().toISOString()
    };

    this.store.vitals.push(reading);
    this.onChange();

    const circle = this.circles.getCircleByElderId(input.elderId);
    if (circle && evaluation.status === "abnormal") {
      this.notifications.broadcastToCareCircle(circle, {
        elderId: input.elderId,
        category: "vital",
        title: "Abnormal vital detected",
        body: evaluation.note,
        metadata: {
          vitalType: input.type,
          value: input.value,
          unit: input.unit
        }
      }, input.loggedByUserId);
    }

    return { reading, alerted: evaluation.status === "abnormal" };
  }

  getVitalsForElder(elderId: string): VitalReading[] {
    return this.store.vitals.filter((vital) => vital.elderId === elderId);
  }

  getOverview(elderId: string) {
    const readings = this.getVitalsForElder(elderId).sort((left, right) => right.createdAt.localeCompare(left.createdAt));
    const latest = readings[0];
    const abnormalCount = readings.filter((reading) => reading.status === "abnormal").length;

    return {
      elderId,
      latest,
      totalReadings: readings.length,
      abnormalCount,
      status: abnormalCount > 0 ? "attention" : "normal"
    };
  }

  private evaluate(input: VitalInput): { status: "normal" | "abnormal"; note: string } {
    if (input.type === "bloodPressure") {
      const systolic = input.systolic ?? input.value;
      const diastolic = input.diastolic ?? 0;
      if (systolic >= 140 || diastolic >= 90) {
        return { status: "abnormal", note: "Blood pressure is above the safe range." };
      }
      return { status: "normal", note: "Blood pressure is within range." };
    }

    if (input.type === "bloodSugar") {
      if (input.value >= 180) {
        return { status: "abnormal", note: "Blood sugar is above the safe range." };
      }
      return { status: "normal", note: "Blood sugar is within range." };
    }

    if (input.type === "heartRate") {
      if (input.value < 50 || input.value > 100) {
        return { status: "abnormal", note: "Heart rate is outside the normal range." };
      }
      return { status: "normal", note: "Heart rate is within range." };
    }

    if (input.type === "temperature") {
      if (input.value >= 38.0) {
        return { status: "abnormal", note: "Temperature is above the safe range." };
      }
      return { status: "normal", note: "Temperature is within range." };
    }

    if (input.type === "weight") {
      return { status: "normal", note: "Weight reading recorded." };
    }

    return { status: "normal", note: "Vital recorded." };
  }
}
