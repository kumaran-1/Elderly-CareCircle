import type {
  AuthService,
  CareCircleService,
  CareInstructionService,
  DashboardService,
  HealthService,
  LifestyleService,
  MedicationService,
  NotificationService,
  AiService,
  SosService,
  ReportService,
  FileStorageService,
  ReportPdfService
} from "../services";
import type { SystemStore } from "../domain/types";

export interface Services {
  auth: AuthService;
  circles: CareCircleService;
  careInstructions: CareInstructionService;
  health: HealthService;
  medication: MedicationService;
  lifestyle: LifestyleService;
  notifications: NotificationService;
  ai: AiService;
  sos: SosService;
  reports: ReportService;
  dashboard: DashboardService;
  fileStorage: FileStorageService;
  reportPdf: ReportPdfService;
}

export interface RouteContext {
  store: SystemStore;
  services: Services;
}
