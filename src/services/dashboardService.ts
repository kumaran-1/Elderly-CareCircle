import type { DashboardPayload, SystemStore, User } from "../domain/types";
import type { AuthService } from "./authService";
import type { CareCircleService } from "./careCircleService";
import type { HealthService } from "./healthService";
import type { MedicationService } from "./medicationService";
import type { LifestyleService } from "./lifestyleService";
import type { SosService } from "./sosService";
import type { ReportService } from "./reportService";

export class DashboardService {
  constructor(
    private readonly auth: AuthService,
    private readonly circles: CareCircleService,
    private readonly health: HealthService,
    private readonly medication: MedicationService,
    private readonly lifestyle: LifestyleService,
    private readonly sos: SosService,
    private readonly reports: ReportService,
    private readonly store: SystemStore
  ) {}

  async build(userId: string): Promise<DashboardPayload> {
    const user = await this.auth.getUserById(userId);
    if (!user) {
      throw new Error("User not found.");
    }

    const cards: DashboardPayload["cards"] = [];
    const actions: string[] = [];

    switch (user.role) {
      case "elder":
        cards.push(...this.elderCards(user));
        actions.push(
          "Log vitals",
          "Medication",
          "Hydration",
          "Exercise",
          "Appointments",
          "AI Assistant",
          "Reports",
          "Care Circle",
          "SOS"
        );
        break;
      case "family":
        cards.push(...this.familyCards(user));
        actions.push("View elder summary", "Open alerts", "Reports", "Notifications");
        break;
      case "caregiver":
        cards.push(...this.caregiverCards(user));
        actions.push("Client list", "Vitals", "Medication", "Appointments", "Reports");
        break;
    }

    return {
      role: user.role,
      title: `${user.role.charAt(0).toUpperCase()}${user.role.slice(1)} Dashboard`,
      cards,
      actions
    };
  }

  private elderCards(user: User): DashboardPayload["cards"] {
    const health = this.health.getOverview(user.id);
    const medication = this.medication.getSummary(user.id);
    const hydration = this.lifestyle.getHydrationSummary(user.id);
    const sosCount = this.sos.getActiveForElder(user.id).length;

    return [
      {
        label: "Latest vital",
        value: health.latest ? `${health.latest.type}: ${health.latest.value}` : "No readings yet",
        tone: health.status === "abnormal" ? "attention" : "normal"
      },
      {
        label: "Medication adherence",
        value: `${medication.adherencePercent}%`,
        tone: medication.adherencePercent >= 85 ? "normal" : "attention"
      },
      {
        label: "Hydration progress",
        value: `${hydration.progressPercent}%`,
        tone: hydration.progressPercent >= 60 ? "normal" : "attention"
      },
      { label: "Active SOS", value: `${sosCount}`, tone: sosCount > 0 ? "alert" : "normal" }
    ];
  }

  private familyCards(user: User): DashboardPayload["cards"] {
    const linkedElders = this.circles.getLinkedEldersForUser(user.id);
    const alerts = this.store.notifications.filter(
      (notification) => notification.userId === user.id && notification.readAt === undefined
    ).length;
    const activeSos = this.store.sosEvents.filter(
      (event) => linkedElders.includes(event.elderId) && event.status === "active"
    ).length;

    return [
      { label: "Linked elders", value: `${linkedElders.length}`, tone: "normal" },
      { label: "Unread alerts", value: `${alerts}`, tone: alerts > 0 ? "attention" : "normal" },
      { label: "Active SOS", value: `${activeSos}`, tone: activeSos > 0 ? "alert" : "normal" },
      { label: "Reports ready", value: `${linkedElders.length}`, tone: "normal" }
    ];
  }

  private caregiverCards(user: User): DashboardPayload["cards"] {
    const linkedElders = this.circles.getLinkedEldersForUser(user.id);
    const tasks = linkedElders.reduce((sum, elderId) => {
      return (
        sum + this.medication.getPlansForElder(elderId).length + this.lifestyle.getAppointmentsForElder(elderId).length
      );
    }, 0);

    return [
      { label: "Assigned elders", value: `${linkedElders.length}`, tone: "normal" },
      { label: "Today tasks", value: `${tasks}`, tone: tasks > 0 ? "attention" : "normal" },
      {
        label: "Hydration logs",
        value: `${linkedElders.reduce((sum, elderId) => sum + this.lifestyle.getHydrationSummary(elderId).totalMl, 0)} ml`,
        tone: "normal"
      },
      {
        label: "Alerts",
        value: `${this.store.notifications.filter((notification) => notification.userId === user.id).length}`,
        tone: "normal"
      }
    ];
  }
}
