import { describe, it, expect, vi, afterEach } from "vitest";

const savedEnv = { ...process.env };

afterEach(() => {
  process.env = { ...savedEnv };
  vi.resetModules();
});

async function loadConfig(env: Record<string, string>) {
  Object.assign(process.env, env);
  vi.resetModules();
  return (await import("./env")) as typeof import("./env");
}

describe("production secret policy", () => {
  it("rejects identical access and refresh secrets in production", async () => {
    await expect(
      loadConfig({
        NODE_ENV: "production",
        JWT_SECRET: "a".repeat(20),
        JWT_REFRESH_SECRET: "a".repeat(20)
      })
    ).rejects.toThrow(/distinct/i);
  });

  it("rejects short secrets in production", async () => {
    await expect(
      loadConfig({
        NODE_ENV: "production",
        JWT_SECRET: "short",
        JWT_REFRESH_SECRET: "b".repeat(20)
      })
    ).rejects.toThrow(/at least 16/i);
  });

  it("accepts distinct long secrets in production", async () => {
    const { config } = await loadConfig({
      NODE_ENV: "production",
      JWT_SECRET: "a".repeat(20),
      JWT_REFRESH_SECRET: "b".repeat(20)
    });
    expect(config.isProd).toBe(true);
  });
});
