import { describe, it, expect } from "vitest";
import { createSeedStore } from "../domain/seed";
import { NotificationService } from "./notificationService";
import { AuthService } from "./authService";

function createContext() {
  const store = createSeedStore();
  const notifications = new NotificationService(store);
  const auth = new AuthService(store, notifications);
  return { store, auth };
}

describe("AuthService", () => {
  it("registers a user and returns a verified account with tokens", async () => {
    const { auth } = createContext();
    const result = await auth.register({
      name: "New Elder",
      email: "elder.new@example.com",
      password: "VerySecure123!",
      role: "elder"
    });

    expect(result.user.email).toBe("elder.new@example.com");
    expect(result.user.role).toBe("elder");
    expect(result.user.verified).toBe(true);
    expect(result.user).not.toHaveProperty("passwordHash");
    expect(result.user).not.toHaveProperty("otpCode");
    expect(result.tokens.accessToken.length).toBeGreaterThan(10);
    expect(result.tokens.refreshToken.length).toBeGreaterThan(10);
  });

  it("rejects duplicate registration", async () => {
    const { auth } = createContext();
    await expect(
      auth.register({ name: "Raj", email: "rajendran@example.com", password: "Password123!", role: "elder" })
    ).rejects.toThrow(/already exists/i);
  });

  it("rejects an invalid login", async () => {
    const { auth } = createContext();
    await expect(auth.login({ email: "rajendran@example.com", password: "wrong-password" })).rejects.toThrow(
      /invalid email or password/i
    );
  });

  it("lets a user log in and receive tokens", async () => {
    const { auth } = createContext();
    const result = await auth.login({ email: "rajendran@example.com", password: "Password123!" });
    expect(result.user.role).toBe("elder");
    expect(result.tokens.accessToken.length).toBeGreaterThan(10);
    expect(result.tokens.refreshToken.length).toBeGreaterThan(10);
  });
});
