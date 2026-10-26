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
import { CareInstructionService } from "../services/careInstructionService";
import { CarePlanService } from "../services/carePlanService";
import bcrypt from "bcryptjs";

async function main() {
  const store = createSeedStore();
  store.users.push({
    id: "user-admin-legacy",
    name: "Legacy Admin",
    email: "legacy-admin@example.com",
    passwordHash: bcrypt.hashSync("Password123!", 10),
    role: "admin",
    verified: true,
    profile: {},
    fcmTokens: [],
    refreshTokenVersion: 0,
    createdAt: new Date().toISOString()
  });
  const notifications = new NotificationService(store);
  const circles = new CareCircleService(store, notifications);
  const auth = new AuthService(store, notifications);
  const health = new HealthService(store, circles, notifications);
  const medication = new MedicationService(store, circles, notifications);
  const lifestyle = new LifestyleService(store, circles, notifications);
  const ai = new AiService(store);
  const sos = new SosService(store, circles, notifications);
  const reports = new ReportService(store);
  const careInstructions = new CareInstructionService(store, circles, notifications);
  const carePlan = new CarePlanService(store, circles, notifications);
  const app = createApp(store, { auth, circles, health, medication, lifestyle, notifications, ai, sos, reports, careInstructions, carePlan });
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
      email: "legacy-admin@example.com",
      password: "Password123!"
    });
    assert.equal(adminLogin.status, 403);

    const adminRegistration = await request(baseUrl, "/auth/register", "POST", {
      name: "Unauthorized Admin",
      email: "unauthorized-admin@example.com",
      password: "Password123!",
      role: "admin"
    });
    assert.equal(adminRegistration.status, 400);

    const caregiverLogin = await request(baseUrl, "/auth/login", "POST", {
      email: "suresh@example.com",
      password: "Password123!"
    });
    assert.equal(caregiverLogin.status, 200);
    const caregiverToken = (caregiverLogin.body as { tokens: { accessToken: string } }).tokens.accessToken;
    const caregiverHeaders = { Authorization: `Bearer ${caregiverToken}` };

    const createTaskResponse = await request(baseUrl, "/care-tasks", "POST", {
      elderId: "user-elder-1",
      assignedToUserId: "user-family-1",
      title: "Check evening blood pressure",
      notes: "Log the reading before dinner.",
      priority: "high"
    }, caregiverHeaders);
    assert.equal(createTaskResponse.status, 201);
    const createdTask = (createTaskResponse.body as { task: { id: string } }).task;

    const familyLogin = await request(baseUrl, "/auth/login", "POST", {
      email: "asha@example.com",
      password: "Password123!"
    });
    assert.equal(familyLogin.status, 200);
    const familyToken = (familyLogin.body as { tokens: { accessToken: string } }).tokens.accessToken;
    const familyHeaders = { Authorization: `Bearer ${familyToken}` };

    const tasksResponse = await request(baseUrl, "/care-tasks/elder/user-elder-1", "GET", undefined, familyHeaders);
    assert.equal(tasksResponse.status, 200);
    assert.equal((tasksResponse.body as { tasks: unknown[] }).tasks.length >= 1, true);

    const completeTaskResponse = await request(baseUrl, `/care-tasks/${createdTask.id}`, "PATCH", {
      elderId: "user-elder-1",
      status: "completed"
    }, familyHeaders);
    assert.equal(completeTaskResponse.status, 200);
    assert.equal((completeTaskResponse.body as { task: { status: string } }).task.status, "completed");

    const elderTaskResponse = await request(baseUrl, "/care-tasks", "POST", {
      elderId: "user-elder-1",
      assignedToUserId: "user-elder-1",
      title: "Drink a glass of water",
      priority: "medium"
    }, caregiverHeaders);
    assert.equal(elderTaskResponse.status, 201);
    const elderTaskId = (elderTaskResponse.body as { task: { id: string } }).task.id;

    const elderCompleteResponse = await request(baseUrl, `/care-tasks/${elderTaskId}`, "PATCH", {
      elderId: "user-elder-1",
      status: "completed"
    }, authHeaders);
    assert.equal(elderCompleteResponse.status, 200);
    assert.equal((elderCompleteResponse.body as { task: { status: string } }).task.status, "completed");

    const familyCreateCircle = await request(baseUrl, "/care-circles", "POST", {}, familyHeaders);
    assert.equal(familyCreateCircle.status, 403);

    const familyInvite = await request(baseUrl, "/care-circles/circle-1/invite", "POST", {
      email: "invitee@example.com",
      relation: "caregiver"
    }, familyHeaders);
    assert.equal(familyInvite.status, 403);

    const wrongCodeAccept = await request(baseUrl, "/care-circles/circle-1/accept", "POST", {
      inviteCode: "CIRCLE-WRONG-999",
      relation: "family"
    }, familyHeaders);
    assert.equal(wrongCodeAccept.status, 404);

    const createNoteResponse = await request(baseUrl, "/care-notes", "POST", {
      elderId: "user-elder-1",
      type: "handover",
      title: "Evening handover",
      body: "Blood pressure was stable. Dinner and medication completed.",
      shift: "evening"
    }, caregiverHeaders);
    assert.equal(createNoteResponse.status, 201);

    const notesResponse = await request(baseUrl, "/care-notes/elder/user-elder-1", "GET", undefined, familyHeaders);
    assert.equal(notesResponse.status, 200);
    assert.equal((notesResponse.body as { notes: unknown[] }).notes.length >= 1, true);

    const followUpAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    const appointmentResponse = await request(baseUrl, "/appointments", "POST", {
      elderId: "user-elder-1",
      doctorName: "Dr. Meera Krishnan",
      specialty: "Cardiology",
      dateTime: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString(),
      followUpAt,
      followUpNotes: "Review the latest blood pressure readings."
    }, familyHeaders);
    assert.equal(appointmentResponse.status, 201);
    assert.equal((appointmentResponse.body as { appointment: { followUpAt: string } }).appointment.followUpAt, followUpAt);

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