import "dotenv/config";
import { config } from "./config";
import { createSeedStore } from "./domain/seed";
import { AuthService } from "./services/authService";
import { CareCircleService } from "./services/careCircleService";
import { HealthService } from "./services/healthService";
import { MedicationService } from "./services/medicationService";
import { LifestyleService } from "./services/lifestyleService";
import { NotificationService } from "./services/notificationService";
import { AiService } from "./services/aiService";
import { SosService } from "./services/sosService";
import { ReportService } from "./services/reportService";
import { CareInstructionService } from "./services/careInstructionService";
import { CarePlanService } from "./services/carePlanService";
import { createApp } from "./app";
import { FileStore } from "./persistence/fileStore";
import { MongoStore } from "./persistence/mongoStore";
import { FcmGateway } from "./services/fcmGateway";

async function bootstrap() {
  const persistence = config.mongodbUri
    ? await MongoStore.loadOrSeed(config.mongodbUri, createSeedStore)
    : await FileStore.loadOrSeed(createSeedStore);
  const store = persistence.value;
  await persistence.save();
  const persist = () => {
    void persistence.save();
  };

  const fcm = new FcmGateway(config.firebaseServiceAccountJson);
  const notifications = new NotificationService(store, persist, fcm);
  const circles = new CareCircleService(store, notifications, persist);
  const auth = new AuthService(store, notifications, persist);
  const health = new HealthService(store, circles, notifications, persist);
  const medication = new MedicationService(store, circles, notifications, persist);
  const lifestyle = new LifestyleService(store, circles, notifications, persist);
  const ai = new AiService(store);
  const sos = new SosService(store, circles, notifications, persist);
  const reports = new ReportService(store);
  const careInstructions = new CareInstructionService(store, circles, notifications, persist);
  const carePlan = new CarePlanService(store, circles, notifications, persist);

  const app = createApp(store, {
    auth,
    circles,
    health,
    medication,
    lifestyle,
    notifications,
    ai,
    sos,
    reports,
    careInstructions,
    carePlan
  }, {
    onChange: persist
  });

  app.listen(config.port, config.host, () => {
    const storage = config.mongodbUri ? "MongoDB" : "local JSON";
    console.log(`${config.appName} API running on http://localhost:${config.port} using ${storage} storage`);
  });

  const shutdown = async () => {
    await persistence.close?.();
    process.exit(0);
  };

  process.once("SIGINT", shutdown);
  process.once("SIGTERM", shutdown);
}

void bootstrap();
