import { describe, it, expect } from "vitest";
import { createSeedStore } from "../domain/seed";
import { NotificationService } from "./notificationService";
import { CareCircleService } from "./careCircleService";
import { HealthService, type VitalInput } from "./healthService";
import { vitalSchema } from "../validation/schemas";

function createContext() {
  const store = createSeedStore();
  const notifications = new NotificationService(store);
  const circles = new CareCircleService(store, notifications);
  const health = new HealthService(store, circles, notifications);
  return { store, notifications, circles, health };
}

const base: Omit<VitalInput, "type" | "value" | "unit"> = {
  elderId: "user-elder-1",
  loggedByUserId: "user-elder-1"
};

describe("HealthService thresholds", () => {
  it.each([
    ["bloodPressure", 150, "mmHg", { systolic: 150, diastolic: 95 }, "abnormal"],
    ["bloodPressure", 140, "mmHg", { systolic: 140, diastolic: 90 }, "abnormal"],
    ["bloodPressure", 139, "mmHg", { systolic: 120, diastolic: 89 }, "normal"],
    ["bloodSugar", 180, "mg/dL", {}, "abnormal"],
    ["bloodSugar", 179.9, "mg/dL", {}, "normal"],
    ["heartRate", 49, "bpm", {}, "abnormal"],
    ["heartRate", 50, "bpm", {}, "normal"],
    ["heartRate", 100, "bpm", {}, "normal"],
    ["heartRate", 101, "bpm", {}, "abnormal"],
    ["temperature", 38, "°C", {}, "abnormal"],
    ["temperature", 37.9, "°C", {}, "normal"],
    ["weight", 68.5, "kg", {}, "normal"]
  ])("classifies %s=%s%s as %s", (type, value, unit, extra, expected) => {
    const { health } = createContext();
    const result = health.logVital({
      ...base,
      type: type as VitalInput["type"],
      value: value as number,
      unit: unit as string,
      ...(extra as { systolic?: number; diastolic?: number })
    });
    expect(result.reading.status).toBe(expected);
    expect(result.reading.value).toBe(value);
  });

  it("preserves decimals and the threshold note on the stored record", () => {
    const { store, health } = createContext();
    const result = health.logVital({ ...base, type: "temperature", value: 37.5, unit: "°C" });
    expect(result.reading.value).toBe(37.5);
    expect(result.reading.thresholdNote.length).toBeGreaterThan(0);
    expect(store.vitals).toContainEqual(result.reading);
  });
});

describe("vitalSchema validation", () => {
  it("accepts a complete valid payload", () => {
    const parsed = vitalSchema.safeParse({
      elderId: "user-elder-1",
      type: "heartRate",
      value: 72,
      unit: "bpm"
    });
    expect(parsed.success).toBe(true);
  });

  it.each([
    ["missing value", { elderId: "user-elder-1", type: "heartRate", unit: "bpm" }],
    ["string value", { elderId: "user-elder-1", type: "heartRate", value: "72", unit: "bpm" }],
    ["negative value", { elderId: "user-elder-1", type: "heartRate", value: -5, unit: "bpm" }],
    ["negative systolic", { elderId: "user-elder-1", type: "bloodPressure", value: 120, unit: "mmHg", systolic: -1, diastolic: 80 }],
    ["empty unit", { elderId: "user-elder-1", type: "heartRate", value: 72, unit: " " }],
    ["unknown type", { elderId: "user-elder-1", type: "oxygen", value: 98, unit: "%" }],
    ["missing elderId", { type: "heartRate", value: 72, unit: "bpm" }]
  ])("rejects %s", (_label, body) => {
    expect(vitalSchema.safeParse(body).success).toBe(false);
  });
});

describe("HealthService alerts", () => {
  it("alerts the Care Circle on abnormal values but not on normal ones", () => {
    const { notifications, health } = createContext();
    const beforeFamily = notifications.listForUser("user-family-1").length;
    const beforeCaregiver = notifications.listForUser("user-caregiver-1").length;
    const beforeElder = notifications.listForUser("user-elder-1").length;

    const abnormal = health.logVital({ ...base, type: "heartRate", value: 120, unit: "bpm" });
    expect(abnormal.alerted).toBe(true);
    expect(abnormal.deduplicated).toBe(false);
    expect(notifications.listForUser("user-family-1").length).toBe(beforeFamily + 1);
    expect(notifications.listForUser("user-caregiver-1").length).toBe(beforeCaregiver + 1);
    // The logger is excluded from their own alert broadcast.
    expect(notifications.listForUser("user-elder-1").length).toBe(beforeElder);

    const normal = health.logVital({ ...base, type: "heartRate", value: 72, unit: "bpm" });
    expect(normal.alerted).toBe(false);
    expect(notifications.listForUser("user-family-1").length).toBe(beforeFamily + 1);
  });

  it("suppresses repeat broadcasts of the identical abnormal measurement", () => {
    const { notifications, health } = createContext();
    const before = notifications.listForUser("user-family-1").length;

    const first = health.logVital({ ...base, type: "bloodSugar", value: 250, unit: "mg/dL" });
    expect(first.alerted).toBe(true);
    const second = health.logVital({ ...base, type: "bloodSugar", value: 250, unit: "mg/dL" });
    expect(second.alerted).toBe(false);
    expect(second.deduplicated).toBe(true);
    // Both readings are preserved; only one broadcast went out.
    expect(health.getVitalsForElder("user-elder-1").filter((v) => v.type === "bloodSugar" && v.value === 250)).toHaveLength(2);
    expect(notifications.listForUser("user-family-1").length).toBe(before + 1);
  });

  it("alerts again when the abnormal measurement changes", () => {
    const { notifications, health } = createContext();
    health.logVital({ ...base, type: "bloodSugar", value: 250, unit: "mg/dL" });
    const before = notifications.listForUser("user-family-1").length;
    const changed = health.logVital({ ...base, type: "bloodSugar", value: 260, unit: "mg/dL" });
    expect(changed.alerted).toBe(true);
    expect(changed.deduplicated).toBe(false);
    expect(notifications.listForUser("user-family-1").length).toBe(before + 1);
  });
});

describe("HealthService overview consistency", () => {
  it("uses the stored abnormal vocabulary across overview and dashboard inputs", () => {
    const { health } = createContext();
    // Seed data already contains one abnormal reading (vital-1).
    const initial = health.getOverview("user-elder-1");
    expect(initial.status).toBe("abnormal");
    expect(initial.abnormalCount).toBe(1);

    // A normal reading becomes latest without rewriting history.
    const normal = health.logVital({ ...base, type: "heartRate", value: 72, unit: "bpm" });
    const afterNormal = health.getOverview("user-elder-1");
    expect(afterNormal.latest?.id).toBe(normal.reading.id);
    expect(afterNormal.latest?.status).toBe("normal");
    expect(afterNormal.abnormalCount).toBe(1);
    expect(afterNormal.status).toBe("abnormal");

    health.logVital({ ...base, type: "heartRate", value: 130, unit: "bpm" });
    const overview = health.getOverview("user-elder-1");
    expect(overview.status).toBe("abnormal");
    expect(overview.abnormalCount).toBe(2);
    expect(overview.latest?.status).toBe("abnormal");
  });

  it("preserves history and resolves the latest reading deterministically", () => {
    const { store, health } = createContext();
    const first = health.logVital({ ...base, type: "weight", value: 70, unit: "kg" });
    const second = health.logVital({ ...base, type: "weight", value: 71, unit: "kg" });
    expect(health.getVitalsForElder("user-elder-1")).toContainEqual(first.reading);
    expect(health.getVitalsForElder("user-elder-1")).toContainEqual(second.reading);
    expect(health.getOverview("user-elder-1").latest?.id).toBe(second.reading.id);

    // Exact timestamp ties resolve to the most recently recorded reading.
    const stamp = new Date().toISOString();
    store.vitals.push(
      { ...first.reading, id: "tie-1", value: 72, createdAt: stamp },
      { ...first.reading, id: "tie-2", value: 73, createdAt: stamp }
    );
    expect(health.getOverview("user-elder-1").latest?.id).toBe("tie-2");
  });
});
