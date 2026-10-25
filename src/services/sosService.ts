import crypto from "crypto";
import type { SosEvent, SystemStore } from "../domain/types";
import type { CareCircleService } from "./careCircleService";
import type { NotificationService } from "./notificationService";

export interface SosInput {
  elderId: string;
  triggeredByUserId: string;
  location?: string;
}

export class SosService {
  constructor(
    private readonly store: SystemStore,
    private readonly circles: CareCircleService,
    private readonly notifications: NotificationService,
    private readonly onChange: () => void = () => undefined
  ) {}

  create(input: SosInput): { event: SosEvent; notificationCount: number } {
    const event: SosEvent = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      triggeredByUserId: input.triggeredByUserId,
      status: "active",
      location: input.location,
      createdAt: new Date().toISOString()
    };

    this.store.sosEvents.push(event);
  this.onChange();

    const circle = this.circles.getCircleByElderId(input.elderId);
    const notifications = circle
      ? this.notifications.broadcastToCareCircle(circle, {
          elderId: input.elderId,
          category: "sos",
          title: "SOS alert triggered",
          body: input.location ? `SOS activated from ${input.location}.` : "SOS activated.",
          metadata: { sosId: event.id }
        })
      : [];

    return { event, notificationCount: notifications.length };
  }

  acknowledge(eventId: string, userId: string): SosEvent {
    const event = this.store.sosEvents.find((candidate) => candidate.id === eventId);
    if (!event) {
      throw new Error("SOS event not found.");
    }

    event.status = "acknowledged";
    event.acknowledgedAt = new Date().toISOString();
    this.onChange();
    this.notifications.create({
      userId,
      elderId: event.elderId,
      category: "sos",
      title: "SOS acknowledged",
      body: "The SOS alert has been acknowledged."
    });
    return event;
  }

  resolve(eventId: string, userId: string): SosEvent {
    const event = this.store.sosEvents.find((candidate) => candidate.id === eventId);
    if (!event) {
      throw new Error("SOS event not found.");
    }

    event.status = "resolved";
    event.resolvedAt = new Date().toISOString();
    this.onChange();
    this.notifications.create({
      userId,
      elderId: event.elderId,
      category: "sos",
      title: "SOS resolved",
      body: "The SOS alert has been resolved."
    });
    return event;
  }

  getActiveForElder(elderId: string): SosEvent[] {
    return this.store.sosEvents.filter((event) => event.elderId === elderId && event.status === "active");
  }
}
