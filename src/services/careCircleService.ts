import crypto from "crypto";
import type { CareCircle, CareCircleMember, Role, SystemStore } from "../domain/types";
import type { NotificationService } from "./notificationService";

export class CareCircleService {
  constructor(
    private readonly store: SystemStore,
    private readonly notifications: NotificationService,
    private readonly onChange: () => void = () => undefined
  ) {}

  createCircle(elderId: string, creatorUserId: string, name?: string): CareCircle {
    const elder = this.store.users.find((user) => user.id === elderId && user.role === "elder");
    if (!elder) {
      throw new Error("Elder account not found.");
    }

    const circle: CareCircle = {
      id: crypto.randomUUID(),
      elderId,
      name: name ?? `${elder.name} Care Circle`,
      inviteCode: `CIRCLE-${crypto.randomBytes(3).toString("hex").toUpperCase()}`,
      createdByUserId: creatorUserId,
      createdAt: new Date().toISOString(),
      members: [
        { userId: elderId, relation: "elder", acceptedAt: new Date().toISOString() }
      ]
    };

    this.store.careCircles.push(circle);
    this.onChange();
    return circle;
  }

  inviteMember(circleId: string, email: string, relation: CareCircleMember["relation"]): CareCircle {
    const circle = this.getCircle(circleId);
    const user = this.store.users.find((candidate) => candidate.email === email.toLowerCase());
    if (!user) {
      throw new Error("Invitee must already have a CareCircle account in this MVP.");
    }

    if (!circle.members.some((member) => member.userId === user.id)) {
      circle.members.push({ userId: user.id, relation, acceptedAt: new Date().toISOString() });
      this.onChange();
      this.notifications.create({
        userId: user.id,
        elderId: circle.elderId,
        category: "system",
        title: "CareCircle invitation accepted",
        body: `You are now linked to ${circle.name}.`
      });
    }

    return circle;
  }

  acceptInvitation(circleInviteCode: string, userId: string, relation: CareCircleMember["relation"]): CareCircle {
    const circle = this.store.careCircles.find((candidate) => candidate.inviteCode === circleInviteCode);
    if (!circle) {
      throw new Error("Invalid invite code.");
    }

    if (!circle.members.some((member) => member.userId === userId)) {
      circle.members.push({ userId, relation, acceptedAt: new Date().toISOString() });
      this.onChange();
    }

    return circle;
  }

  getCircle(circleId: string): CareCircle {
    const circle = this.store.careCircles.find((candidate) => candidate.id === circleId);
    if (!circle) {
      throw new Error("CareCircle not found.");
    }

    return circle;
  }

  getCircleByElderId(elderId: string): CareCircle | undefined {
    return this.store.careCircles.find((circle) => circle.elderId === elderId);
  }

  getLinkedEldersForUser(userId: string): string[] {
    return this.store.careCircles
      .filter((circle) => circle.members.some((member) => member.userId === userId))
      .map((circle) => circle.elderId);
  }

  userHasAccessToElder(userId: string, elderId: string): boolean {
    const user = this.store.users.find((candidate) => candidate.id === userId);
    if (!user) {
      return false;
    }

    if (user.role === "admin") {
      return false;
    }

    if (user.id === elderId) {
      return true;
    }

    const circle = this.getCircleByElderId(elderId);
    return Boolean(circle && circle.members.some((member) => member.userId === userId));
  }

  getMemberDetails(circleId: string): Array<{ userId: string; name: string; role: Role; relation: string }> {
    const circle = this.getCircle(circleId);
    return circle.members.map((member) => {
      const user = this.store.users.find((candidate) => candidate.id === member.userId);
      return {
        userId: member.userId,
        name: user?.name ?? "Unknown",
        role: user?.role ?? "family",
        relation: member.relation
      };
    });
  }
}
