import { describe, it, expect } from "vitest";
import { FcmGateway } from "./fcmGateway";

describe("FcmGateway boundary", () => {
  it("stays disabled and reports undelivered without credentials", async () => {
    const gateway = new FcmGateway(undefined);
    await expect(gateway.send({ token: "device-token", title: "Hi", body: "Hello" })).resolves.toBe(false);
  });

  it("stays disabled on malformed credentials instead of throwing at startup", async () => {
    const gateway = new FcmGateway("not-json");
    await expect(gateway.send({ token: "device-token", title: "Hi", body: "Hello" })).resolves.toBe(false);
  });
});
