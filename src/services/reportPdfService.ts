import PDFDocument from "pdfkit";
import type { ReportSummary } from "../domain/types";

export class ReportPdfService {
  async generate(summary: ReportSummary): Promise<Buffer> {
    const document = new PDFDocument({ margin: 48, size: "A4" });
    const chunks: Buffer[] = [];

    return new Promise<Buffer>((resolve, reject) => {
      document.on("data", (chunk: Buffer) => chunks.push(chunk));
      document.on("end", () => resolve(Buffer.concat(chunks)));
      document.on("error", reject);

      document.fontSize(22).fillColor("#16202a").text("CareCircle Health Report");
      document.moveDown(0.4);
      document.fontSize(11).fillColor("#667085").text(`Elder profile: ${summary.elderId}`);
      document.text(`Period: ${summary.period}`);
      document.text(`Generated: ${summary.generatedAt}`);
      document.moveDown();

      document.fontSize(14).fillColor("#16202a").text("Summary");
      document.moveDown(0.3);
      document.fontSize(11).fillColor("#344054").text(summary.summary, { lineGap: 4 });
      document.moveDown();

      document.fontSize(14).fillColor("#16202a").text("Metrics");
      document.moveDown(0.3);
      const metrics = [
        ["Vitals recorded", summary.vitalsCount],
        ["Abnormal vitals", summary.abnormalVitalsCount],
        ["Medication adherence", `${summary.medicationAdherencePercent}%`],
        ["Hydration", `${summary.hydrationMl} ml`],
        ["Exercise", `${summary.exerciseMinutes} minutes`],
        ["Appointments", summary.appointmentCount],
        ["Active SOS alerts", summary.activeSosCount]
      ];

      metrics.forEach(([label, value]) => {
        document.fontSize(11).fillColor("#344054").text(`${label}: ${value}`);
      });

      document.moveDown(2);
      document.fontSize(9).fillColor("#98a2b3").text("CareCircle AI and health summaries are informational and do not replace professional medical advice.");
      document.end();
    });
  }
}
