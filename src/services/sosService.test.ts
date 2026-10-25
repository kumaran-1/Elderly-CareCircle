import { describe, it, expect } from "vitest";
import { createSeedStore } from "../domain/seed";
import { NotificationService } from "./notificationService";
import { CareCircleService } from "./careCircleService";
import { SosService } from "./sosService";

function createContext() {
  const store = createSeedStore();
  const notifications = new NotificationService(store);
  const circles = new CareCircleService(store, notifications);
  const sos = new SosService(store, circles, notifications);
  return { store, circles, sos, notifications };
}

describe("SosService", () => {
  it("creates an active SOS event", () => {
    const { sos } = createContext();
    const { event } = sos.create({ elderId: "user-elder-1", triggeredByUserId: "user-elder-1", location: "Home" });
    expect(event.status).toBe("active");
    expect(event.location).toBe("Home");
  });

  it("acknowledges an active event", () => {
    const { sos } = createContext();
    const { event } = sos.create({ elderId: "user-elder-1", triggeredByUserId: "user-elder-1" });
    const acknowledged = sos.acknowledge(event.id, "user-family-1");
    expect(acknowledged.status).toBe("acknowledged");
    expect(acknowledged.acknowledgedAt).toBeDefined();
  });

  it("cannot acknowledge a resolved event", () => {
    const { sos } = createContext();
    const { event } = sos.create({ elderId: "user-elder-1", triggeredByUserId: "user-elder-1" });
    sos.acknowledge(event.id, "user-family-1");
    sos.resolve(event.id, "user-family-1");
    expect(() => sos.acknowledge(event.id, "user-family-1")).toThrow(/only active/i);
  });

  it("cannot resolve an already resolved event", () => {
    const { sos } = createContext();
    const { event } = sos.create({ elderId: "user-elder-1", triggeredByUserId: "user-elder-1" });
    sos.acknowledge(event.id, "user-family-1");
    sos.resolve(event.id, "user-family-1");
    expect(() => sos.resolve(event.id, "user-family-1")).toThrow(/already resolved/i);
  });

  it("cannot resolve an event that has not been acknowledged", () => {
    const { sos } = createContext();
    const { event } = sos.create({ elderId: "user-elder-1", triggeredByUserId: "user-elder-1" });
    expect(() => sos.resolve(event.id, "user-family-1")).toThrow(/acknowledged before/i);
  });

  it("throws when the event does not exist", () => {
    const { sos } = createContext();
    expect(() => sos.acknowledge("missing", "user-family-1")).toThrow(/not found/i);
  });
});

describe("CareCircleService access control", () => {
  it("grants a family member access to the linked elder", () => {
    const { circles } = createContext();
    expect(circles.userHasAccessToElder("user-family-1", "user-elder-1")).toBe(true);
  });

  it("grants a caregiver access to the linked elder", () => {
    const { circles } = createContext();
    expect(circles.userHasAccessToElder("user-caregiver-1", "user-elder-1")).toBe(true);
  });

  it("denies access to an unrelated user", () => {
    const { circles } = createContext();
    expect(circles.userHasAccessToElder("user-nonexistent", "user-elder-1")).toBe(false);
  });
});
