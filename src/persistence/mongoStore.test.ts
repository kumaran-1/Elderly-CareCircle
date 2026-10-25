import { describe, it, expect } from "vitest";
import { createEmptyStore } from "../domain/store";
import { snapshotWithoutUsers } from "./mongoStore";

describe("snapshotWithoutUsers", () => {
  it("strips user records while preserving every other collection", () => {
    const store = createEmptyStore();
    store.users.push({
      id: "u1",
      name: "Test",
      email: "test@example.com",
      passwordHash: "hash",
      role: "elder",
      verified: true,
      profile: {},
      fcmTokens: [],
      refreshTokenVersion: 0,
      createdAt: new Date().toISOString()
    });
    store.vitals.push({
      id: "v1",
      elderId: "u1",
      loggedByUserId: "u1",
      type: "heartRate",
      value: 70,
      unit: "bpm",
      status: "normal",
      thresholdNote: "ok",
      createdAt: new Date().toISOString()
    });

    const snapshot = snapshotWithoutUsers(store);
    expect(snapshot).not.toHaveProperty("users");
    expect(snapshot.vitals).toHaveLength(1);
    expect(snapshot.careCircles).toEqual([]);
    // The source store is untouched.
    expect(store.users).toHaveLength(1);
  });
});
