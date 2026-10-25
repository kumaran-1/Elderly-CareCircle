import { describe, it, expect } from "vitest";
import { createSeedStore } from "../domain/seed";
import { NotificationService } from "./notificationService";
import { AuthService } from "./authService";
import { CareCircleService } from "./careCircleService";

function createContext() {
  const store = createSeedStore();
  const notifications = new NotificationService(store);
  const auth = new AuthService(store, notifications);
  const circles = new CareCircleService(store, notifications);
  return { store, auth, circles };
}

async function registerUser(
  auth: AuthService,
  name: string,
  email: string,
  role: "elder" | "family" | "caregiver"
) {
  const result = await auth.register({ name, email, password: "Password123!", role });
  return result.user;
}

describe("CareCircleService invitations", () => {
  it("lets an elder create a circle they own", async () => {
    const { auth, circles } = createContext();
    const elder = await registerUser(auth, "Circle Elder", "circle.elder@example.com", "elder");
    const circle = circles.createCircle(elder.id, elder.id, "My Circle");
    expect(circle.elderId).toBe(elder.id);
    expect(circle.members).toEqual([{ userId: elder.id, relation: "elder", acceptedAt: expect.any(String) }]);
  });

  it("stores a family invitation as pending without granting membership", async () => {
    const { store, auth, circles } = createContext();
    const elder = await registerUser(auth, "Invite Elder", "invite.elder@example.com", "elder");
    const family = await registerUser(auth, "Invite Family", "invite.family@example.com", "family");
    const circle = circles.createCircle(elder.id, elder.id);

    const result = circles.inviteMember(circle.id, family.email, "family", elder.id);
    expect(result.created).toBe(true);
    expect(result.invitation.status).toBe("pending");
    expect(result.invitation.relation).toBe("family");
    expect(result.invitation.email).toBe(family.email);
    expect(result.invitation).not.toHaveProperty("acceptedAt");
    expect(circle.members.some((m) => m.userId === family.id)).toBe(false);
    expect(store.invitations).toHaveLength(1);
  });

  it("stores a caregiver invitation with the exact caregiver relationship", async () => {
    const { auth, circles } = createContext();
    const elder = await registerUser(auth, "Cg Elder", "cg.elder@example.com", "elder");
    const caregiver = await registerUser(auth, "Cg Pro", "cg.pro@example.com", "caregiver");
    const circle = circles.createCircle(elder.id, elder.id);

    const result = circles.inviteMember(circle.id, caregiver.email, "caregiver", elder.id);
    expect(result.invitation.relation).toBe("caregiver");
    expect(circle.members.some((m) => m.userId === caregiver.id)).toBe(false);
  });

  it("treats a repeat invite while pending as idempotent instead of duplicating", async () => {
    const { store, auth, circles } = createContext();
    const elder = await registerUser(auth, "Dup Elder", "dup.elder@example.com", "elder");
    const family = await registerUser(auth, "Dup Family", "dup.family@example.com", "family");
    const circle = circles.createCircle(elder.id, elder.id);

    const first = circles.inviteMember(circle.id, family.email, "family", elder.id);
    const second = circles.inviteMember(circle.id, family.email, "family", elder.id);
    expect(second.created).toBe(false);
    expect(second.invitation.id).toBe(first.invitation.id);
    expect(store.invitations).toHaveLength(1);
  });

  it("rejects inviting an existing member", async () => {
    const { auth, circles } = createContext();
    const elder = await registerUser(auth, "Mem Elder", "mem.elder@example.com", "elder");
    const family = await registerUser(auth, "Mem Family", "mem.family@example.com", "family");
    const circle = circles.createCircle(elder.id, elder.id);

    circles.inviteMember(circle.id, family.email, "family", elder.id);
    const familyUser = await auth.getUserByEmail(family.email);
    await expect(
      (async () => circles.acceptInvitation(circle.inviteCode, familyUser!.id, familyUser!.email, "family"))()
    ).resolves.toMatchObject({ alreadyLinked: false });
    await expect(
      (async () => circles.inviteMember(circle.id, family.email, "family", elder.id))()
    ).rejects.toThrow(/already a member/i);
  });

  it("activates family membership only on explicit matching acceptance", async () => {
    const { auth, circles } = createContext();
    const elder = await registerUser(auth, "Acc Elder", "acc.elder@example.com", "elder");
    const family = await registerUser(auth, "Acc Family", "acc.family@example.com", "family");
    const circle = circles.createCircle(elder.id, elder.id);
    circles.inviteMember(circle.id, family.email, "family", elder.id);

    const familyUser = await auth.getUserByEmail(family.email);
    const result = circles.acceptInvitation(circle.inviteCode, familyUser!.id, familyUser!.email, "family");
    expect(result.alreadyLinked).toBe(false);
    const member = circle.members.find((m) => m.userId === familyUser!.id);
    expect(member?.relation).toBe("family");
    expect(member?.acceptedAt).toBeDefined();
  });

  it("rejects acceptance when the relationship does not match the invitation", async () => {
    const { auth, circles } = createContext();
    const elder = await registerUser(auth, "Mis Elder", "mis.elder@example.com", "elder");
    const family = await registerUser(auth, "Mis Family", "mis.family@example.com", "family");
    const circle = circles.createCircle(elder.id, elder.id);
    circles.inviteMember(circle.id, family.email, "family", elder.id);

    const familyUser = await auth.getUserByEmail(family.email);
    await expect(
      (async () => circles.acceptInvitation(circle.inviteCode, familyUser!.id, familyUser!.email, "caregiver"))()
    ).rejects.toThrow(/for a family relationship/i);
    expect(circle.members.some((m) => m.userId === familyUser!.id)).toBe(false);
  });

  it("rejects an invalid invite code", async () => {
    const { auth, circles } = createContext();
    const family = await registerUser(auth, "Code Family", "code.family@example.com", "family");
    await expect(
      (async () => circles.acceptInvitation("CIRCLE-NOPE-000", family.id, family.email, "family"))()
    ).rejects.toThrow(/invalid invite code/i);
  });

  it("rejects acceptance by a user the invitation was not intended for", async () => {
    const { auth, circles } = createContext();
    const elder = await registerUser(auth, "Hij Elder", "hij.elder@example.com", "elder");
    const intended = await registerUser(auth, "Hij Intended", "hij.intended@example.com", "family");
    const intruder = await registerUser(auth, "Hij Intruder", "hij.intruder@example.com", "family");
    const circle = circles.createCircle(elder.id, elder.id);
    circles.inviteMember(circle.id, intended.email, "family", elder.id);

    await expect(
      (async () => circles.acceptInvitation(circle.inviteCode, intruder.id, intruder.email, "family"))()
    ).rejects.toThrow(/no pending invitation/i);
    expect(circle.members.some((m) => m.userId === intruder.id)).toBe(false);
  });

  it("rejects missing or invalid relationships without silent defaults", async () => {
    const { auth, circles } = createContext();
    const elder = await registerUser(auth, "Rel Elder", "rel.elder@example.com", "elder");
    const family = await registerUser(auth, "Rel Family", "rel.family@example.com", "family");
    const circle = circles.createCircle(elder.id, elder.id);

    await expect(
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (async () => circles.inviteMember(circle.id, family.email, undefined as any, elder.id))()
    ).rejects.toThrow(/family or caregiver/i);
    for (const bad of ["admin", "other", "elder", "friend"]) {
      await expect(
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (async () => circles.inviteMember(circle.id, family.email, bad as any, elder.id))()
      ).rejects.toThrow(/family or caregiver/i);
    }
    expect(circle.members.some((m) => m.userId === family.id)).toBe(false);
  });

  it("treats a repeat acceptance as already linked without duplicating membership", async () => {
    const { auth, circles } = createContext();
    const elder = await registerUser(auth, "Re Elder", "re.elder@example.com", "elder");
    const family = await registerUser(auth, "Re Family", "re.family@example.com", "family");
    const circle = circles.createCircle(elder.id, elder.id);
    circles.inviteMember(circle.id, family.email, "family", elder.id);

    const familyUser = await auth.getUserByEmail(family.email);
    await circles.acceptInvitation(circle.inviteCode, familyUser!.id, familyUser!.email, "family");
    const second = circles.acceptInvitation(circle.inviteCode, familyUser!.id, familyUser!.email, "family");
    expect(second.alreadyLinked).toBe(true);
    expect(circle.members.filter((m) => m.userId === familyUser!.id)).toHaveLength(1);
  });

  it("rejects expired invitations", async () => {
    const { store, auth, circles } = createContext();
    const elder = await registerUser(auth, "Exp Elder", "exp.elder@example.com", "elder");
    const family = await registerUser(auth, "Exp Family", "exp.family@example.com", "family");
    const circle = circles.createCircle(elder.id, elder.id);
    const result = circles.inviteMember(circle.id, family.email, "family", elder.id);

    const stored = store.invitations.find((inv) => inv.id === result.invitation.id);
    stored!.expiresAt = new Date(Date.now() - 1000).toISOString();

    const familyUser = await auth.getUserByEmail(family.email);
    await expect(
      (async () => circles.acceptInvitation(circle.inviteCode, familyUser!.id, familyUser!.email, "family"))()
    ).rejects.toThrow(/expired/i);
    expect(circle.members.some((m) => m.userId === familyUser!.id)).toBe(false);
  });

  it("grants access only to linked members and revokes it on removal", async () => {
    const { auth, circles } = createContext();
    const elder = await registerUser(auth, "Scope Elder", "scope.elder@example.com", "elder");
    const family = await registerUser(auth, "Scope Family", "scope.family@example.com", "family");
    const stranger = await registerUser(auth, "Scope Stranger", "scope.stranger@example.com", "family");
    const circle = circles.createCircle(elder.id, elder.id);

    expect(circles.userHasAccessToElder(stranger.id, elder.id)).toBe(false);

    circles.inviteMember(circle.id, family.email, "family", elder.id);
    const familyUser = await auth.getUserByEmail(family.email);
    circles.acceptInvitation(circle.inviteCode, familyUser!.id, familyUser!.email, "family");
    expect(circles.userHasAccessToElder(familyUser!.id, elder.id)).toBe(true);

    circles.removeMember(circle.id, familyUser!.id);
    expect(circles.userHasAccessToElder(familyUser!.id, elder.id)).toBe(false);
  });

  it("restricts circle management to the owning elder", async () => {
    const { auth, circles } = createContext();
    const elder = await registerUser(auth, "Mgr Elder", "mgr.elder@example.com", "elder");
    const family = await registerUser(auth, "Mgr Family", "mgr.family@example.com", "family");
    const circle = circles.createCircle(elder.id, elder.id);

    expect(circles.isCircleManager(circle.id, elder.id)).toBe(true);
    expect(circles.isCircleManager(circle.id, family.id)).toBe(false);
  });

  it("preserves exact stored relationships in member details", () => {
    const { circles } = createContext();
    const details = circles.getMemberDetails("circle-1");
    const byName = Object.fromEntries(details.map((d) => [d.name, d.relation]));
    expect(byName["Rajendran"]).toBe("elder");
    expect(byName["Asha"]).toBe("family");
    expect(byName["Suresh"]).toBe("caregiver");
  });
});
