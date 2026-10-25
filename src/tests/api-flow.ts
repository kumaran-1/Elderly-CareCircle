import assert from "node:assert/strict";
import { createServer } from "node:http";
import { createSeedStore } from "../domain/seed";
import { createApp } from "../app";
import { AuthService } from "../services/authService";
import { CareCircleService } from "../services/careCircleService";
import { HealthService } from "../services/healthService";
import { MedicationService } from "../services/medicationService";
import { LifestyleService } from "../services/lifestyleService";
import { NotificationService } from "../services/notificationService";
import { AiService } from "../services/aiService";
import { SosService } from "../services/sosService";
import { ReportService } from "../services/reportService";

async function main() {
  const store = createSeedStore();
  const notifications = new NotificationService(store);
  const circles = new CareCircleService(store, notifications);
  const auth = new AuthService(store, notifications);
  const health = new HealthService(store, circles, notifications);
  const medication = new MedicationService(store, circles, notifications);
  const lifestyle = new LifestyleService(store, circles, notifications);
  const ai = new AiService(store);
  const sos = new SosService(store, circles, notifications);
  const reports = new ReportService(store);
  const app = createApp(store, { auth, circles, health, medication, lifestyle, notifications, ai, sos, reports });
  const server = createServer(app);

  await new Promise<void>((resolve) => server.listen(0, resolve));
  const address = server.address();
  assert.ok(address && typeof address !== "string");
  const baseUrl = `http://127.0.0.1:${address.port}`;

  try {
    const healthResponse = await request(baseUrl, "/health");
    assert.equal(healthResponse.status, 200);

    const loginResponse = await request(baseUrl, "/auth/login", "POST", {
      email: "rajendran@example.com",
      password: "Password123!"
    });
    assert.equal(loginResponse.status, 200);
    const loginBody = loginResponse.body as { tokens: { accessToken: string; refreshToken: string } };
    const authHeaders = { Authorization: `Bearer ${loginBody.tokens.accessToken}` };

    const dashboardResponse = await request(baseUrl, "/dashboard", "GET", undefined, authHeaders);
    assert.equal(dashboardResponse.status, 200);

    const vitalResponse = await request(baseUrl, "/health/vitals", "POST", {
      elderId: "user-elder-1",
      type: "bloodPressure",
      value: 150,
      unit: "mmHg",
      systolic: 150,
      diastolic: 95
    }, authHeaders);
    assert.equal(vitalResponse.status, 201);
    assert.equal((vitalResponse.body as { alerted: boolean }).alerted, true);

    const pdfResponse = await fetch(`${baseUrl}/reports/summary/user-elder-1/pdf?period=weekly`, {
      headers: authHeaders
    });
    assert.equal(pdfResponse.status, 200);
    assert.equal(pdfResponse.headers.get("content-type"), "application/pdf");
    assert.equal((await pdfResponse.arrayBuffer()).byteLength > 100, true);

    const refreshResponse = await request(baseUrl, "/auth/refresh", "POST", {
      refreshToken: loginBody.tokens.refreshToken
    });
    assert.equal(refreshResponse.status, 200);
    assert.ok((refreshResponse.body as { tokens: { accessToken: string } }).tokens.accessToken);

    const adminLogin = await request(baseUrl, "/auth/login", "POST", {
      email: "admin@example.com",
      password: "Password123!"
    });
    const adminToken = (adminLogin.body as { tokens: { accessToken: string } }).tokens.accessToken;
    const privateDataResponse = await request(baseUrl, "/health/vitals/user-elder-1", "GET", undefined, {
      Authorization: `Bearer ${adminToken}`
    });
    assert.equal(privateDataResponse.status, 403);

    const adminRegistration = await request(baseUrl, "/auth/register", "POST", {
      name: "Unauthorized Admin",
      email: "unauthorized-admin@example.com",
      password: "Password123!",
      role: "admin"
    });
    assert.equal(adminRegistration.status, 400);

    console.log("API CareCircle smoke test passed.");
  } finally {
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
}

async function request(
  baseUrl: string,
  path: string,
  method = "GET",
  body?: Record<string, unknown>,
  headers: Record<string, string> = {}
): Promise<{ status: number; body: unknown }> {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: { "Content-Type": "application/json", ...headers },
    body: body ? JSON.stringify(body) : undefined
  });
  return { status: response.status, body: await response.json() };
}

void main();