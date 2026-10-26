import type { ReportSummary, SystemStore } from "../domain/types";

export class ReportService {
  constructor(private readonly store: SystemStore) {}

  buildSummary(elderId: string, period: "weekly" | "monthly"): ReportSummary {
    const cutoffDays = period === "weekly" ? 7 : 30;
    const cutoff = Date.now() - cutoffDays * 24 * 60 * 60 * 1000;

    const vitals = this.store.vitals.filter((vital) => vital.elderId === elderId && new Date(vital.createdAt).getTime() >= cutoff);
    const medicationLogs = this.store.medicationLogs.filter((log) => log.elderId === elderId && new Date(log.loggedAt).getTime() >= cutoff);
    const hydrationLogs = this.store.hydrationLogs.filter((log) => log.elderId === elderId && new Date(log.createdAt).getTime() >= cutoff);
    const exerciseLogs = this.store.exerciseLogs.filter((log) => log.elderId === elderId && new Date(log.createdAt).getTime() >= cutoff);
    const appointments = this.store.appointments.filter(
      (appointment) =>
        appointment.elderId === elderId &&
        appointment.status !== "cancelled" &&
        new Date(appointment.createdAt).getTime() >= cutoff
    );
    const activeSosCount = this.store.sosEvents.filter((event) => event.elderId === elderId && event.status === "active").length;

    const medicationTaken = medicationLogs.filter((log) => log.status === "taken").length;
    const medicationAdherencePercent = medicationLogs.length === 0 ? 0 : Math.round((medicationTaken / medicationLogs.length) * 100);
    const abnormalVitalsCount = vitals.filter((vital) => vital.status === "abnormal").length;
    const hydrationMl = hydrationLogs.reduce((sum, log) => sum + log.amountMl, 0);
    const exerciseMinutes = exerciseLogs.reduce((sum, log) => sum + log.minutes, 0);

    return {
      elderId,
      period,
      generatedAt: new Date().toISOString(),
      vitalsCount: vitals.length,
      abnormalVitalsCount,
      medicationAdherencePercent,
      hydrationMl,
      exerciseMinutes,
      appointmentCount: appointments.length,
      activeSosCount,
      summary: `Care summary for ${period} period: ${vitals.length} vitals, ${abnormalVitalsCount} abnormal readings, ${medicationAdherencePercent}% medication adherence, and ${activeSosCount} active SOS alerts.`
    };
  }

  adminAnalytics() {
    const activeSos = this.store.sosEvents.filter((event) => event.status === "active").length;
    const resolvedSos = this.store.sosEvents.filter((event) => event.status === "resolved").length;
    const medicationLogs = this.store.medicationLogs;
    const taken = medicationLogs.filter((log) => log.status === "taken").length;
    const adherence = medicationLogs.length === 0 ? 0 : Math.round((taken / medicationLogs.length) * 100);

    return {
      totalUsers: this.store.users.length,
      totalCareCircles: this.store.careCircles.length,
      activeSos,
      resolvedSos,
      medicationAdherencePercent: adherence,
      notificationCount: this.store.notifications.length,
      aiConversationCount: this.store.conversations.length
    };
  }
}
