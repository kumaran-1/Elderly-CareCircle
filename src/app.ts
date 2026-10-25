import cors from "cors";
import express, { NextFunction, Request, Response } from "express";
import rateLimit from "express-rate-limit";
import { z } from "zod";
import type { SystemStore, Role } from "./domain/types";
import { AuthService } from "./services/authService";
import { CareCircleService } from "./services/careCircleService";
import { HealthService } from "./services/healthService";
import { MedicationService } from "./services/medicationService";
import { LifestyleService } from "./services/lifestyleService";
import { NotificationService } from "./services/notificationService";
import { AiService } from "./services/aiService";
import { SosService } from "./services/sosService";
import { ReportService } from "./services/reportService";
import { FileStorageService } from "./services/fileStorageService";
import { ReportPdfService } from "./services/reportPdfService";

export interface Services {
  auth: AuthService;
  circles: CareCircleService;
  health: HealthService;
  medication: MedicationService;
  lifestyle: LifestyleService;
  notifications: NotificationService;
  ai: AiService;
  sos: SosService;
  reports: ReportService;
}

export interface AppOptions {
  onChange?: () => void;
}

const registerSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8),
  role: z.enum(["elder", "family", "caregiver"])
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8)
});

const verifyOtpSchema = z.object({
  email: z.string().email(),
  otp: z.string().length(6)
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1)
});

const createCircleSchema = z.object({
  elderId: z.string().optional(),
  name: z.string().min(2).optional()
});

const inviteSchema = z.object({
  email: z.string().email(),
  relation: z.enum(["elder", "family", "caregiver", "admin", "other"])
});

const acceptSchema = z.object({
  inviteCode: z.string().min(4),
  relation: z.enum(["elder", "family", "caregiver", "admin", "other"]).default("family")
});

const vitalSchema = z.object({
  elderId: z.string(),
  type: z.enum(["bloodPressure", "bloodSugar", "heartRate", "weight", "temperature"]),
  value: z.number(),
  unit: z.string().min(1),
  systolic: z.number().optional(),
  diastolic: z.number().optional()
});

const medicationSchema = z.object({
  elderId: z.string(),
  name: z.string().min(2),
  dosage: z.string().min(1),
  frequency: z.string().min(1),
  reminderTime: z.string().min(1)
});

const medicationLogSchema = z.object({
  elderId: z.string(),
  status: z.enum(["taken", "snoozed", "skipped", "missed"]),
  dueAt: z.string().optional()
});

const hydrationSchema = z.object({
  elderId: z.string(),
  amountMl: z.number().positive()
});

const exerciseSchema = z.object({
  elderId: z.string(),
  activityType: z.string().min(2),
  minutes: z.number().positive()
});

const appointmentSchema = z.object({
  elderId: z.string(),
  doctorName: z.string().min(2),
  specialty: z.string().min(2),
  dateTime: z.string().datetime(),
  notes: z.string().optional()
});

const uploadSchema = z.object({
  name: z.string().min(1),
  mimeType: z.string().min(1),
  contentBase64: z.string().min(1)
});

const deviceSchema = z.object({
  token: z.string().min(10)
});

const aiSchema = z.object({
  elderId: z.string().optional(),
  question: z.string().min(2)
});

const sosSchema = z.object({
  elderId: z.string(),
  location: z.string().optional()
});

export function createApp(store: SystemStore, services: Services, options: AppOptions = {}) {
  const app = express();
  app.use(cors());
  app.use(express.json());
  app.use("/auth", rateLimit({ windowMs: 15 * 60 * 1000, limit: 30, standardHeaders: "draft-7", legacyHeaders: false }));

  const fileStorage = new FileStorageService();
  const reportPdf = new ReportPdfService();

  app.use((req: Request, res: Response, next: NextFunction) => {
    const header = req.headers.authorization;
    if (!header?.startsWith("Bearer ")) {
      next();
      return;
    }

    try {
      req.auth = services.auth.authenticate(header.slice("Bearer ".length));
    } catch (error) {
      res.status(401).json({ message: error instanceof Error ? error.message : "Unauthorized" });
      return;
    }

    next();
  });

  const requireAuth = (req: Request, res: Response): boolean => {
    if (!req.auth) {
      res.status(401).json({ message: "Authentication required." });
      return false;
    }

    return true;
  };

  const requireRole = (roles: Role[], req: Request, res: Response): boolean => {
    if (!requireAuth(req, res)) {
      return false;
    }

    if (!req.auth || !roles.includes(req.auth.role)) {
      res.status(403).json({ message: "You do not have access to this resource." });
      return false;
    }

    return true;
  };

  const ensureElderAccess = (req: Request, res: Response, elderId: string): boolean => {
    if (!requireAuth(req, res)) {
      return false;
    }

    if (!req.auth) {
      return false;
    }

    if (req.auth.role === "admin") {
      res.status(403).json({ message: "Admin users cannot access private elder health data." });
      return false;
    }

    if (!services.circles.userHasAccessToElder(req.auth.userId, elderId)) {
      res.status(403).json({ message: "You are not linked to this elder's CareCircle." });
      return false;
    }

    return true;
  };

  const getSafeUser = (userId: string) => {
    const user = services.auth.getUserById(userId);
    return user ? services.auth.publicUser(user) : undefined;
  };

  const buildDashboard = (userId: string) => {
    const user = services.auth.getUserById(userId);
    if (!user) {
      throw new Error("User not found.");
    }

    const cards: Array<{ label: string; value: string; tone: "normal" | "attention" | "alert" }> = [];
    const actions: string[] = [];

    if (user.role === "elder") {
      const circle = services.circles.getCircleByElderId(user.id);
      const health = services.health.getOverview(user.id);
      const medication = services.medication.getSummary(user.id);
      const hydration = services.lifestyle.getHydrationSummary(user.id);
      const sosCount = services.sos.getActiveForElder(user.id).length;

      cards.push(
        { label: "Latest vital", value: health.latest ? `${health.latest.type}: ${health.latest.value}` : "No readings yet", tone: health.status === "alert" ? "alert" : health.status === "attention" ? "attention" : "normal" },
        { label: "Medication adherence", value: `${medication.adherencePercent}%`, tone: medication.adherencePercent >= 85 ? "normal" : "attention" },
        { label: "Hydration progress", value: `${hydration.progressPercent}%`, tone: hydration.progressPercent >= 60 ? "normal" : "attention" },
        { label: "Active SOS", value: `${sosCount}`, tone: sosCount > 0 ? "alert" : "normal" }
      );
      actions.push("Log vitals", "Medication", "Hydration", "Exercise", "Appointments", "AI Assistant", "Reports", "Care Circle", "SOS");
    } else if (user.role === "family") {
      const linkedElders = services.circles.getLinkedEldersForUser(user.id);
      const alerts = store.notifications.filter((notification) => notification.userId === user.id && notification.readAt === undefined).length;
      const activeSos = store.sosEvents.filter((event) => linkedElders.includes(event.elderId) && event.status === "active").length;

      cards.push(
        { label: "Linked elders", value: `${linkedElders.length}`, tone: "normal" },
        { label: "Unread alerts", value: `${alerts}`, tone: alerts > 0 ? "attention" : "normal" },
        { label: "Active SOS", value: `${activeSos}`, tone: activeSos > 0 ? "alert" : "normal" },
        { label: "Reports ready", value: `${linkedElders.length}`, tone: "normal" }
      );
      actions.push("View elder summary", "Open alerts", "Reports", "Notifications");
    } else if (user.role === "caregiver") {
      const linkedElders = services.circles.getLinkedEldersForUser(user.id);
      const tasks = linkedElders.reduce((sum, elderId) => {
        return sum + services.medication.getPlansForElder(elderId).length + services.lifestyle.getAppointmentsForElder(elderId).length;
      }, 0);

      cards.push(
        { label: "Assigned elders", value: `${linkedElders.length}`, tone: "normal" },
        { label: "Today tasks", value: `${tasks}`, tone: tasks > 0 ? "attention" : "normal" },
        { label: "Hydration logs", value: `${linkedElders.reduce((sum, elderId) => sum + services.lifestyle.getHydrationSummary(elderId).totalMl, 0)} ml`, tone: "normal" },
        { label: "Alerts", value: `${store.notifications.filter((notification) => notification.userId === user.id).length}`, tone: "normal" }
      );
      actions.push("Client list", "Vitals", "Medication", "Appointments", "Reports");
    } else {
      const analytics = services.reports.adminAnalytics();
      cards.push(
        { label: "Active users", value: `${analytics.totalUsers}`, tone: "normal" },
        { label: "Care circles", value: `${analytics.totalCareCircles}`, tone: "normal" },
        { label: "Active SOS", value: `${analytics.activeSos}`, tone: analytics.activeSos > 0 ? "alert" : "normal" },
        { label: "Medication adherence", value: `${analytics.medicationAdherencePercent}%`, tone: analytics.medicationAdherencePercent >= 85 ? "normal" : "attention" }
      );
      actions.push("User management", "Platform analytics", "Notification health", "SOS metrics");
    }

    return {
      role: user.role,
      title: `${user.role.charAt(0).toUpperCase()}${user.role.slice(1)} Dashboard`,
      cards,
      actions
    };
  };

  app.get("/health", (_req, res) => {
    res.json({ service: "CareCircle API", status: "ok" });
  });

  app.post("/auth/register", (req, res) => {
    const payload = registerSchema.parse(req.body);
    try {
      const result = services.auth.register(payload);
      res.status(201).json({
        message: "Account created. OTP sent for verification.",
        user: result.user,
        otpCode: result.otpCode
      });
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "Registration failed." });
    }
  });

  app.post("/auth/login", (req, res) => {
    const payload = loginSchema.parse(req.body);
    try {
      const result = services.auth.login(payload);
      res.json({
        message: "Login successful.",
        user: result.user,
        tokens: result.tokens
      });
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "Login failed." });
    }
  });

  app.post("/auth/verify-otp", (req, res) => {
    const payload = verifyOtpSchema.parse(req.body);
    try {
      const result = services.auth.verifyOtp(payload.email, payload.otp);
      res.json({
        message: "OTP verified successfully.",
        user: result.user,
        tokens: result.tokens
      });
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "OTP verification failed." });
    }
  });

  app.post("/auth/refresh", (req, res) => {
    const payload = refreshSchema.parse(req.body);

    try {
      const claims = services.auth.authenticateRefreshToken(payload.refreshToken);
      const user = services.auth.getUserById(claims.userId);
      if (!user) {
        res.status(404).json({ message: "User not found." });
        return;
      }

      if (claims.tokenVersion !== user.refreshTokenVersion) {
        res.status(401).json({ message: "Refresh token has been revoked." });
        return;
      }

      res.json({ tokens: services.auth.refresh(user.id) });
    } catch (error) {
      res.status(401).json({ message: error instanceof Error ? error.message : "Unable to refresh session." });
    }
  });

  app.get("/me", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const auth = req.auth;
    if (!auth) {
      res.status(401).json({ message: "Authentication required." });
      return;
    }

    const user = getSafeUser(auth.userId);
    if (!user) {
      res.status(404).json({ message: "User not found." });
      return;
    }

    res.json({ user, dashboard: buildDashboard(auth.userId) });
  });

  app.get("/dashboard", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const auth = req.auth;
    if (!auth) {
      res.status(401).json({ message: "Authentication required." });
      return;
    }

    try {
      res.json(buildDashboard(auth.userId));
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "Unable to build dashboard." });
    }
  });

  app.post("/care-circles", (req, res) => {
    if (!requireRole(["elder", "family"], req, res)) {
      return;
    }

    const payload = createCircleSchema.parse(req.body);
    const creator = services.auth.getUserById(req.auth!.userId);
    if (!creator) {
      res.status(404).json({ message: "Creator not found." });
      return;
    }

    const elderId = payload.elderId ?? creator.id;
    if (creator.role !== "elder" && creator.role !== "family") {
      res.status(403).json({ message: "Only elder or family users can create a CareCircle in this MVP." });
      return;
    }

    const existing = services.circles.getCircleByElderId(elderId);
    const circle = existing ?? services.circles.createCircle(elderId, creator.id, payload.name);
    if (existing && !existing.members.some((member) => member.userId === creator.id)) {
      existing.members.push({ userId: creator.id, relation: creator.role === "elder" ? "elder" : "family", acceptedAt: new Date().toISOString() });
    }

    res.status(existing ? 200 : 201).json({ circle });
  });

  app.post("/care-circles/:id/invite", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = inviteSchema.parse(req.body);
    const circle = services.circles.getCircle(req.params.id);
    if (!services.circles.userHasAccessToElder(req.auth!.userId, circle.elderId) && req.auth!.role !== "admin") {
      res.status(403).json({ message: "You cannot manage this CareCircle." });
      return;
    }

    try {
      const updated = services.circles.inviteMember(circle.id, payload.email, payload.relation);
      res.json({ circle: updated });
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "Invite failed." });
    }
  });

  app.post("/care-circles/:id/accept", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = acceptSchema.parse(req.body);
    try {
      const target = store.careCircles.find((circle) => circle.id === req.params.id || circle.inviteCode === req.params.id || circle.inviteCode === payload.inviteCode);
      if (!target) {
        res.status(404).json({ message: "CareCircle not found." });
        return;
      }

      if (req.auth!.role !== "admin" && req.auth!.userId !== target.elderId && !services.circles.userHasAccessToElder(req.auth!.userId, target.elderId)) {
        services.circles.acceptInvitation(
  payload.inviteCode,
  req.auth!.userId,
  req.auth!.email,
  payload.relation
);
      } else {
services.circles.acceptInvitation(
  payload.inviteCode,
  req.auth!.userId,
  req.auth!.email,
  payload.relation
);      }

      res.json({ circle: services.circles.getCircle(target.id) });
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "Unable to accept invitation." });
    }
  });

  app.get("/care-circles/me", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    res.json({
      circles: store.careCircles
        .filter((circle) => circle.members.some((member) => member.userId === req.auth!.userId))
        .map((circle) => ({ ...circle, members: services.circles.getMemberDetails(circle.id) }))
    });
  });

  app.post("/health/vitals", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = vitalSchema.parse(req.body);
    if (!ensureElderAccess(req, res, payload.elderId)) {
      return;
    }

    try {
      const result = services.health.logVital({ ...payload, loggedByUserId: req.auth!.userId });
      res.status(201).json({ reading: result.reading, alerted: result.alerted });
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "Unable to log vital." });
    }
  });

  app.get("/health/vitals/:elderId", (req, res) => {
    if (!ensureElderAccess(req, res, req.params.elderId)) {
      return;
    }

    res.json({ readings: services.health.getVitalsForElder(req.params.elderId), overview: services.health.getOverview(req.params.elderId) });
  });

  app.post("/medications", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = medicationSchema.parse(req.body);
    if (!ensureElderAccess(req, res, payload.elderId)) {
      return;
    }

    const plan = services.medication.createPlan({ ...payload, createdByUserId: req.auth!.userId });
    res.status(201).json({ medication: plan });
  });

  app.post("/medications/:id/logs", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = medicationLogSchema.parse(req.body);
    if (!ensureElderAccess(req, res, payload.elderId)) {
      return;
    }

    try {
      const result = services.medication.logDose({
        medicationId: req.params.id,
        elderId: payload.elderId,
        loggedByUserId: req.auth!.userId,
        status: payload.status,
        dueAt: payload.dueAt
      });
      res.status(201).json(result);
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "Unable to log medication dose." });
    }
  });

  app.get("/medications/summary/:elderId", (req, res) => {
    if (!ensureElderAccess(req, res, req.params.elderId)) {
      return;
    }

    res.json({
      plans: services.medication.getPlansForElder(req.params.elderId),
      logs: services.medication.getLogsForElder(req.params.elderId),
      summary: services.medication.getSummary(req.params.elderId)
    });
  });

  app.post("/hydration/logs", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = hydrationSchema.parse(req.body);
    if (!ensureElderAccess(req, res, payload.elderId)) {
      return;
    }

    res.status(201).json({ log: services.lifestyle.logHydration({ ...payload, loggedByUserId: req.auth!.userId }), summary: services.lifestyle.getHydrationSummary(payload.elderId) });
  });

  app.get("/hydration/summary/:elderId", (req, res) => {
    if (!ensureElderAccess(req, res, req.params.elderId)) {
      return;
    }

    res.json(services.lifestyle.getHydrationSummary(req.params.elderId));
  });

  app.post("/exercise/logs", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = exerciseSchema.parse(req.body);
    if (!ensureElderAccess(req, res, payload.elderId)) {
      return;
    }

    res.status(201).json({ log: services.lifestyle.logExercise({ ...payload, loggedByUserId: req.auth!.userId }), summary: services.lifestyle.getExerciseSummary(payload.elderId) });
  });

  app.get("/exercise/summary/:elderId", (req, res) => {
    if (!ensureElderAccess(req, res, req.params.elderId)) {
      return;
    }

    res.json(services.lifestyle.getExerciseSummary(req.params.elderId));
  });

  app.post("/appointments", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = appointmentSchema.parse(req.body);
    if (!ensureElderAccess(req, res, payload.elderId)) {
      return;
    }

    res.status(201).json({ appointment: services.lifestyle.createAppointment({ ...payload, createdByUserId: req.auth!.userId }) });
  });

  app.get("/appointments/:elderId", (req, res) => {
    if (!ensureElderAccess(req, res, req.params.elderId)) {
      return;
    }

    res.json({ appointments: services.lifestyle.getAppointmentsForElder(req.params.elderId) });
  });

  app.post("/ai/chat", async (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = aiSchema.parse(req.body);
    try {
      const result = await services.ai.chat(req.auth!.userId, payload.elderId ?? req.auth!.userId, payload.question);
      res.json({
        ...result,
        ifEmergency: result.conversation.emergencyDetected ? "Use SOS or emergency services immediately." : undefined
      });
    } catch (error) {
      res.status(502).json({ message: error instanceof Error ? error.message : "AI service is temporarily unavailable." });
    }
  });

  app.post("/files/upload", async (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = uploadSchema.parse(req.body);
    try {
const saved = await fileStorage.saveFile({
  ...payload,
  uploadedByUserId: req.auth!.userId
});      store.files.push(saved);
      options.onChange?.();
      services.notifications.create({
        userId: req.auth!.userId,
        category: "system",
        title: "File uploaded",
        body: `${saved.name} uploaded successfully.`,
        metadata: { fileId: saved.id, size: saved.size }
      });
      res.status(201).json({ file: saved });
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "Upload failed." });
    }
  });

  app.get("/files", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    if (!req.auth) {
      res.status(401).json({ message: "Authentication required." });
      return;
    }

    if (req.auth.role === "admin") {
      res.status(403).json({ message: "Admin users do not access private elder files." });
      return;
    }

    res.json({ files: store.files });
  });

  app.get("/notifications", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    res.json({ notifications: services.notifications.listForUser(req.auth!.userId) });
  });

  app.post("/notifications/device", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = deviceSchema.parse(req.body);
    try {
      res.json({ tokens: services.notifications.registerDevice(req.auth!.userId, payload.token) });
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "Unable to register device." });
    }
  });

  app.post("/notifications/:id/read", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const notification = services.notifications.markRead(req.auth!.userId, req.params.id);
    if (!notification) {
      res.status(404).json({ message: "Notification not found." });
      return;
    }

    res.json({ notification });
  });

  app.post("/sos", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    const payload = sosSchema.parse(req.body);
    if (!ensureElderAccess(req, res, payload.elderId)) {
      return;
    }

    res.status(201).json(services.sos.create({ ...payload, triggeredByUserId: req.auth!.userId }));
  });

  app.post("/sos/:id/acknowledge", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    try {
      res.json({ event: services.sos.acknowledge(req.params.id, req.auth!.userId) });
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "Unable to acknowledge SOS." });
    }
  });

  app.post("/sos/:id/resolve", (req, res) => {
    if (!requireAuth(req, res)) {
      return;
    }

    try {
      res.json({ event: services.sos.resolve(req.params.id, req.auth!.userId) });
    } catch (error) {
      res.status(400).json({ message: error instanceof Error ? error.message : "Unable to resolve SOS." });
    }
  });

  app.get("/reports/summary/:elderId", (req, res) => {
    const period = req.query.period === "monthly" ? "monthly" : "weekly";
    if (!ensureElderAccess(req, res, req.params.elderId)) {
      return;
    }

    res.json(services.reports.buildSummary(req.params.elderId, period));
  });

  app.get("/reports/summary/:elderId/pdf", async (req, res) => {
    const period = req.query.period === "monthly" ? "monthly" : "weekly";
    if (!ensureElderAccess(req, res, req.params.elderId)) {
      return;
    }

    try {
      const summary = services.reports.buildSummary(req.params.elderId, period);
      const pdf = await reportPdf.generate(summary);
      res.setHeader("Content-Type", "application/pdf");
      res.setHeader("Content-Disposition", `attachment; filename=carecircle-${period}-report.pdf`);
      res.send(pdf);
    } catch (error) {
      res.status(500).json({ message: error instanceof Error ? error.message : "Unable to generate report PDF." });
    }
  });

  app.get("/admin/analytics", (req, res) => {
    if (!requireRole(["admin"], req, res)) {
      return;
    }

    res.json(services.reports.adminAnalytics());
  });

  app.get("/admin/users", (req, res) => {
    if (!requireRole(["admin"], req, res)) {
      return;
    }

    res.json({ users: store.users.map((user) => services.auth.publicUser(user)) });
  });

  app.get("/admin/sos", (req, res) => {
    if (!requireRole(["admin"], req, res)) {
      return;
    }

    res.json({ sosEvents: store.sosEvents });
  });

  app.use((error: unknown, _req: Request, res: Response, _next: NextFunction) => {
    if (error instanceof z.ZodError) {
      res.status(400).json({ message: "Validation failed.", issues: error.issues });
      return;
    }

    res.status(500).json({ message: error instanceof Error ? error.message : "Unexpected server error." });
  });

  return app;
}
