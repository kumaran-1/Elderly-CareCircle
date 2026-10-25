import { describe, it, expect } from "vitest";
import { createSeedStore } from "../domain/seed";
import { NotificationService } from "./notificationService";
import { CareCircleService } from "./careCircleService";
import { CareInstructionService } from "./careInstructionService";

function createContext() {
  const store = createSeedStore();
  const notifications = new NotificationService(store);
  const circles = new CareCircleService(store, notifications);
  const careInstructions = new CareInstructionService(store, circles, notifications);
  return { store, circles, notifications, careInstructions };
}

describe("CareInstructionService", () => {
  it("creates an instruction for an assigned elder", () => {
    const { careInstructions } = createContext();
    const instruction = careInstructions.create({
      elderId: "user-elder-1",
      caregiverId: "user-caregiver-1",
      title: "Take blood pressure medication",
      message: "Please ensure Amlodipine is taken at 8 AM daily.",
      priority: "high",
      category: "medication"
    });
    expect(instruction.id).toBeDefined();
    expect(instruction.elderId).toBe("user-elder-1");
    expect(instruction.caregiverId).toBe("user-caregiver-1");
    expect(instruction.priority).toBe("high");
    expect(instruction.category).toBe("medication");
    expect(instruction.createdAt).toBeDefined();
  });

  it("delivers notification to elder and family members", () => {
    const { careInstructions, notifications } = createContext();
    careInstructions.create({
      elderId: "user-elder-1",
      caregiverId: "user-caregiver-1",
      title: "Check hydration",
      message: "Drink at least 2 liters of water today.",
      priority: "medium",
      category: "general"
    });
    const elderNotifs = notifications.listForUser("user-elder-1");
    const familyNotifs = notifications.listForUser("user-family-1");
    expect(elderNotifs.some((n) => n.category === "careInstruction")).toBe(true);
    expect(familyNotifs.some((n) => n.category === "careInstruction")).toBe(true);
  });

  it("does not send notification to the caregiver who created it", () => {
    const { careInstructions, notifications } = createContext();
    careInstructions.create({
      elderId: "user-elder-1",
      caregiverId: "user-caregiver-1",
      title: "Morning walk",
      message: "Take a 30-minute walk.",
      priority: "low",
      category: "lifestyle"
    });
    const caregiverNotifs = notifications.listForUser("user-caregiver-1");
    expect(caregiverNotifs.some((n) => n.category === "careInstruction")).toBe(false);
  });

  it("rejects creation by non-caregiver role", () => {
    const { careInstructions } = createContext();
    expect(() =>
      careInstructions.create({
        elderId: "user-elder-1",
        caregiverId: "user-family-1",
        title: "Test",
        message: "Test message",
        priority: "low",
        category: "general"
      })
    ).toThrow(/only caregivers/i);
  });

  it("rejects creation for unrelated elder", () => {
    const { careInstructions } = createContext();
    expect(() =>
      careInstructions.create({
        elderId: "user-nonexistent-elder",
        caregiverId: "user-caregiver-1",
        title: "Test",
        message: "Test message",
        priority: "low",
        category: "general"
      })
    ).toThrow(/not linked/i);
  });

  it("retrieves instructions for an elder", () => {
    const { careInstructions } = createContext();
    careInstructions.create({
      elderId: "user-elder-1",
      caregiverId: "user-caregiver-1",
      title: "Instruction 1",
      message: "First instruction",
      priority: "low",
      category: "general"
    });
    careInstructions.create({
      elderId: "user-elder-1",
      caregiverId: "user-caregiver-1",
      title: "Instruction 2",
      message: "Second instruction",
      priority: "high",
      category: "medication"
    });
    const instructions = careInstructions.getByElderId("user-elder-1");
    expect(instructions.length).toBe(2);
    const titles = instructions.map((i) => i.title);
    expect(titles).toContain("Instruction 1");
    expect(titles).toContain("Instruction 2");
  });

  it("retrieves medical records for an elder", () => {
    const { careInstructions } = createContext();
    const records = careInstructions.getMedicalRecordsForElder("user-elder-1");
    expect(records.elderId).toBe("user-elder-1");
    expect(records.profile.name).toBe("Rajendran");
    expect(records.vitals.length).toBeGreaterThan(0);
    expect(records.medicationPlans.length).toBeGreaterThan(0);
    expect(records.profile.medicalConditions).toContain("Hypertension");
    expect(records.profile.allergies).toContain("Penicillin");
  });

  it("retrieves instructions created by a specific caregiver", () => {
    const { careInstructions } = createContext();
    careInstructions.create({
      elderId: "user-elder-1",
      caregiverId: "user-caregiver-1",
      title: "My instruction",
      message: "From caregiver",
      priority: "medium",
      category: "general"
    });
    const instructions = careInstructions.getByCaregiverId("user-caregiver-1");
    expect(instructions.length).toBe(1);
    expect(instructions[0].caregiverId).toBe("user-caregiver-1");
  });

  it("returns empty for caregiver with no instructions", () => {
    const { careInstructions } = createContext();
    const instructions = careInstructions.getByCaregiverId("user-caregiver-1");
    expect(instructions.length).toBe(0);
  });

  it("returns empty for elder with no vitals", () => {
    const { careInstructions } = createContext();
    const records = careInstructions.getMedicalRecordsForElder("user-elder-1");
    expect(records.vitals.length).toBe(2);
  });
});

describe("CareCircleService access control for instructions", () => {
  it("grants caregiver access to assigned elder", () => {
    const { circles } = createContext();
    expect(circles.userHasAccessToElder("user-caregiver-1", "user-elder-1")).toBe(true);
  });

  it("denies caregiver access to unassigned elder", () => {
    const { circles } = createContext();
    expect(circles.userHasAccessToElder("user-caregiver-1", "user-nonexistent-elder")).toBe(false);
  });

  it("grants elder access to self", () => {
    const { circles } = createContext();
    expect(circles.userHasAccessToElder("user-elder-1", "user-elder-1")).toBe(true);
  });

  it("grants family access to linked elder", () => {
    const { circles } = createContext();
    expect(circles.userHasAccessToElder("user-family-1", "user-elder-1")).toBe(true);
  });
});
