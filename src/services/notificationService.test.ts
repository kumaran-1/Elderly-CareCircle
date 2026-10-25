import { describe, it, expect } from "vitest";
import { createSeedStore } from "../domain/seed";
import { NotificationService } from "./notificationService";

function createContext() {
  const store = createSeedStore();
  const notifications = new NotificationService(store);
  return { store, notifications };
}

describe("NotificationService device registration", () => {
  it("stores a device token for a known user", async () => {
    const { notifications } = createContext();
    const tokens = await notifications.registerDevice("user-elder-1", "token-1234567890");
    expect(tokens).toContain("token-1234567890");
  });

  it("deduplicates repeat registration of the same token", async () => {
    const { store, notifications } = createContext();
    await notifications.registerDevice("user-elder-1", "token-1234567890");
    await notifications.registerDevice("user-elder-1", "token-1234567890");
    const user = store.users.find((u) => u.id === "user-elder-1")!;
    expect(user.fcmTokens.filter((t) => t === "token-1234567890")).toHaveLength(1);
  });

  it("keeps only the most recent tokens", async () => {
    const { store, notifications } = createContext();
    for (let i = 0; i < 6; i++) {
      await notifications.registerDevice("user-elder-1", `token-number-${i}-abcdef`);
    }
    const user = store.users.find((u) => u.id === "user-elder-1")!;
    expect(user.fcmTokens).toHaveLength(5);
    expect(user.fcmTokens).not.toContain("token-number-0-abcdef");
    expect(user.fcmTokens).toContain("token-number-5-abcdef");
  });

  it("rejects unknown users without storing anything", async () => {
    const { store, notifications } = createContext();
    const before = store.notifications.length;
    await expect(notifications.registerDevice("no-such-user", "token-1234567890")).rejects.toThrow(
      /user not found/i
    );
    expect(store.notifications.length).toBe(before);
  });

  it("scopes stored notifications to the addressed user only", () => {
    const { store, notifications } = createContext();
    notifications.create({
      userId: "user-family-1",
      elderId: "user-elder-1",
      category: "system",
      title: "Hello",
      body: "Scoped"
    });
    expect(notifications.listForUser("user-family-1").length).toBeGreaterThan(0);
    expect(
      store.notifications.filter((n) => n.userId !== "user-family-1" && n.title === "Hello")
    ).toHaveLength(0);
  });
});
