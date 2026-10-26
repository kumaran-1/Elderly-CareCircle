
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
    if (!elder) throw new Error("Elder account not found.");

    const circle: CareCircle = {
      id: crypto.randomUUID(),
      elderId,
      name: name ?? `${elder.name} Care Circle`,
      inviteCode: `CIRCLE-${crypto.randomBytes(3).toString("hex").toUpperCase()}`,
      createdByUserId: creatorUserId,
      createdAt: new Date().toISOString(),
      members: [{ userId: elderId, relation: "elder", acceptedAt: new Date().toISOString() }]
    };

    this.store.careCircles.push(circle);
    this.onChange();
    return circle;
  }

  createOrJoinCircle(
    elderId: string,
    creatorUserId: string,
    relation: CareCircleMember["relation"],
    name?: string
  ): { circle: CareCircle; created: boolean } {
    const existing = this.getCircleByElderId(elderId);
    if (existing) {
      if (!existing.members.some((member) => member.userId === creatorUserId)) {
        existing.members.push({ userId: creatorUserId, relation, acceptedAt: new Date().toISOString() });
        this.onChange();
      }
      return { circle: existing, created: false };
    }

    const circle = this.createCircle(elderId, creatorUserId, name);
    if (creatorUserId !== elderId) {
      circle.members.push({ userId: creatorUserId, relation, acceptedAt: new Date().toISOString() });
      this.onChange();
    }
    return { circle, created: true };
  }

  inviteMember(
    circleId: string,
    email: string,
    relation: CareCircleMember["relation"],
    _inviterUserId?: string
  ): { circle: CareCircle; created: boolean; invitation: { email: string; relation: CareCircleMember["relation"]; status: string; expiresAt: string } } {
    const circle = this.getCircle(circleId);
    const user = this.store.users.find((candidate) => candidate.email.toLowerCase() === email.toLowerCase());
    if (!user) throw new Error("Invitee must already have a CareCircle account in this MVP.");

    const alreadyMember = circle.members.some((member) => member.userId === user.id);
    if (!alreadyMember) {
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

    return {
      circle,
      created: !alreadyMember,
      invitation: {
        email: user.email,
        relation,
        status: alreadyMember ? "already_linked" : "accepted",
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString()
      }
    };
  }

  acceptInvitation(
    inviteCode: string,
    userId: string,
    _email: string,
    relation: CareCircleMember["relation"]
  ): { circle: CareCircle; alreadyLinked: boolean } {
    const circle = this.store.careCircles.find((candidate) => candidate.inviteCode === inviteCode);
    if (!circle) throw new Error("Invalid invite code.");

    const alreadyLinked = circle.members.some((member) => member.userId === userId);
    if (!alreadyLinked) {
      circle.members.push({ userId, relation, acceptedAt: new Date().toISOString() });
      this.onChange();
    }
    return { circle, alreadyLinked };
  }

  getCircle(circleId: string): CareCircle {
    const circle = this.store.careCircles.find((candidate) => candidate.id === circleId);
    if (!circle) throw new Error("CareCircle not found.");
    return circle;
  }

  getCircleByElderId(elderId: string): CareCircle | undefined {
    return this.store.careCircles.find((circle) => circle.elderId === elderId);
  }

  getCirclesForUser(userId: string): CareCircle[] {
    return this.store.careCircles.filter((circle) => circle.members.some((member) => member.userId === userId));
  }

  getLinkedEldersForUser(userId: string): string[] {
    return this.getCirclesForUser(userId).map((circle) => circle.elderId);
  }

  isCircleManager(circleId: string, userId: string): boolean {
    const circle = this.getCircle(circleId);
    return circle.elderId === userId;
  }

  removeMember(circleId: string, userId: string): CareCircle {
    const circle = this.getCircle(circleId);
    if (circle.elderId === userId) throw new Error("The elder cannot be removed from their own CareCircle.");
    circle.members = circle.members.filter((member) => member.userId !== userId);
    this.onChange();
    return circle;
  }

  userHasAccessToElder(userId: string, elderId: string): boolean {
    const user = this.store.users.find((candidate) => candidate.id === userId);
    if (!user || user.role === "admin") return false;
    if (user.id === elderId) return true;
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

  getPendingForCircle(_circleId: string): Array<{ email: string; relation: string; createdAt: string; expiresAt: string }> {
    return [];
  }

  getPendingForEmail(_email: string): Array<{ circleId: string; relation: string; createdAt: string; expiresAt: string }> {
    return [];
  }
}
