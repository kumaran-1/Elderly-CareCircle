import assert from "node:assert/strict";
import { createSeedStore } from "../domain/seed";
import { AuthService } from "../services/authService";
import { CareCircleService } from "../services/careCircleService";
import { HealthService } from "../services/healthService";
import { MedicationService } from "../services/medicationService";
import { LifestyleService } from "../services/lifestyleService";
import { NotificationService } from "../services/notificationService";
import { AiService } from "../services/aiService";
import { SosService } from "../services/sosService";
import { ReportService } from "../services/reportService";

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

async function main() {
  const registerResult = auth.register({
    name: "Test Elder",
    email: "test.elder@example.com",
    password: "Password123!",
    role: "elder"
  });
  assert.equal(registerResult.user.email, "test.elder@example.com");

  const verified = auth.verifyOtp("test.elder@example.com", registerResult.otpCode);
  assert.ok(verified.tokens.accessToken.length > 10);

  const loginResult = auth.login({
    email: "rajendran@example.com",
    password: "Password123!"
  });
  assert.equal(loginResult.user.role, "elder");
  assert.ok(loginResult.tokens.accessToken.length > 10);

  const familyBefore = notifications.listForUser("user-family-1").length;
  const vitalResult = health.logVital({
    elderId: "user-elder-1",
    loggedByUserId: "user-elder-1",
    type: "bloodPressure",
    value: 150,
    unit: "mmHg",
    systolic: 150,
    diastolic: 95
  });
  assert.equal(vitalResult.alerted, true);
  assert.equal(notifications.listForUser("user-family-1").length, familyBefore + 1);

  const chat = await ai.chat("user-elder-1", "user-elder-1", "I have severe chest pain.");
  assert.equal(chat.conversation.emergencyDetected, true);

  const medicationPlan = medication.createPlan({
    elderId: "user-elder-1",
    createdByUserId: "user-caregiver-1",
    name: "Amlodipine",
    dosage: "5 mg",
    frequency: "Once daily",
    reminderTime: "08:00"
  });
  const medicationLog = medication.logDose({
    medicationId: medicationPlan.id,
    elderId: "user-elder-1",
    loggedByUserId: "user-elder-1",
    status: "taken"
  });
  assert.equal(medicationLog.adherencePercent >= 0, true);

  const hydration = lifestyle.logHydration({
    elderId: "user-elder-1",
    loggedByUserId: "user-elder-1",
    amountMl: 250
  });
assert.equal(hydration.log.amountMl, 250);
  const sosEvent = sos.create({
    elderId: "user-elder-1",
    triggeredByUserId: "user-elder-1",
    location: "Home"
  });
  assert.equal(sosEvent.event.status, "active");

  const report = reports.buildSummary("user-elder-1", "weekly");
  assert.equal(report.elderId, "user-elder-1");
  assert.ok(report.summary.length > 10);

  console.log("Core CareCircle smoke test passed.");
}

void main();