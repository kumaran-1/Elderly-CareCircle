import crypto from "crypto";
import type { CareCircle, Notification, NotificationCategory, SystemStore } from "../domain/types";
import type { FcmGateway } from "./fcmGateway";

export interface NotificationInput {
  userId: string;
  category: NotificationCategory;
  title: string;
  body: string;
  elderId?: string;
  metadata?: Record<string, string | number | boolean>;
}

export class NotificationService {
  constructor(
    private readonly store: SystemStore,
    private readonly onChange: () => void = () => undefined,
    private readonly fcm?: FcmGateway
  ) {}

  create(input: NotificationInput): Notification {
    const notification: Notification = {
      id: crypto.randomUUID(),
      userId: input.userId,
      elderId: input.elderId,
      category: input.category,
      title: input.title,
      body: input.body,
      deliveredAt: new Date().toISOString(),
      metadata: input.metadata
    };

    this.store.notifications.push(notification);
    this.onChange();
    const user = this.store.users.find((candidate) => candidate.id === input.userId);
    for (const token of user?.fcmTokens ?? []) {
      void this.fcm?.send({
        token,
        title: notification.title,
        body: notification.body,
        data: {
          notificationId: notification.id,
          category: notification.category,
          ...(notification.elderId ? { elderId: notification.elderId } : {})
        }
      }).catch(() => undefined);
    }
    return notification;
  }

  registerDevice(userId: string, token: string): string[] {
    const user = this.store.users.find((candidate) => candidate.id === userId);
    if (!user) {
      throw new Error("User not found.");
    }

    if (!user.fcmTokens.includes(token)) {
      user.fcmTokens.push(token);
      this.onChange();
    }

    return user.fcmTokens;
  }

  listForUser(userId: string): Notification[] {
    return this.store.notifications.filter((notification) => notification.userId === userId);
  }

  markRead(userId: string, notificationId: string): Notification | undefined {
    const notification = this.store.notifications.find(
      (candidate) => candidate.id === notificationId && candidate.userId === userId
    );

    if (!notification) {
      return undefined;
    }

    notification.readAt = new Date().toISOString();
    this.onChange();
    return notification;
  }

  broadcastToCareCircle(circle: CareCircle, input: Omit<NotificationInput, "userId">, excludeUserId?: string): Notification[] {
    const recipients = circle.members.map((member) => member.userId).filter((userId) => userId !== excludeUserId);
    return recipients.map((userId) =>
      this.create({
        ...input,
        userId
      })
    );
  }
}
