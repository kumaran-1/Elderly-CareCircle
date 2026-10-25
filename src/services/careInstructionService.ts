import crypto from "crypto";
import type { CareInstruction, InstructionPriority, SystemStore } from "../domain/types";
import type { CareCircleService } from "./careCircleService";
import type { NotificationService } from "./notificationService";

export interface CareInstructionInput {
  elderId: string;
  caregiverId: string;
  title: string;
  message: string;
  priority: InstructionPriority;
  category: string;
  scheduledAt?: string;
}

export class CareInstructionService {
  constructor(
    private readonly store: SystemStore,
    private readonly circles: CareCircleService,
    private readonly notifications: NotificationService,
    private readonly onChange: () => void = () => undefined
  ) {}

  create(input: CareInstructionInput): CareInstruction {
    const caregiver = this.store.users.find((u) => u.id === input.caregiverId);
    if (!caregiver || caregiver.role !== "caregiver") {
      throw new Error("Only caregivers can create care instructions.");
    }

    if (!this.circles.userHasAccessToElder(input.caregiverId, input.elderId)) {
      throw new Error("You are not linked to this elder's CareCircle.");
    }

    const instruction: CareInstruction = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      caregiverId: input.caregiverId,
      title: input.title.trim(),
      message: input.message.trim(),
      priority: input.priority,
      category: input.category.trim(),
      scheduledAt: input.scheduledAt,
      createdAt: new Date().toISOString()
    };

    this.store.careInstructions.push(instruction);
    this.onChange();

    const circle = this.circles.getCircleByElderId(input.elderId);
    if (circle) {
      const caregiverName = caregiver.name;
      this.notifications.broadcastToCareCircle(
        circle,
        {
          elderId: input.elderId,
          category: "careInstruction",
          title: `New care instruction: ${instruction.title}`,
          body: `${caregiverName} provided a ${instruction.priority} priority instruction.`,
          metadata: {
            instructionId: instruction.id,
            priority: instruction.priority,
            category: instruction.category
          }
        },
        input.caregiverId
      );
    }

    return instruction;
  }

  getByElderId(elderId: string): CareInstruction[] {
    return this.store.careInstructions
      .filter((i) => i.elderId === elderId)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  getById(instructionId: string): CareInstruction | undefined {
    return this.store.careInstructions.find((i) => i.id === instructionId);
  }

  getByCaregiverId(caregiverId: string): CareInstruction[] {
    return this.store.careInstructions
      .filter((i) => i.caregiverId === caregiverId)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  getMedicalRecordsForElder(elderId: string) {
    const elder = this.store.users.find((u) => u.id === elderId && u.role === "elder");
    if (!elder) {
      throw new Error("Elder not found.");
    }

    const vitals = this.store.vitals
      .filter((v) => v.elderId === elderId)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));

    const medicationPlans = this.store.medicationPlans.filter((m) => m.elderId === elderId && m.active);
    const medicationLogs = this.store.medicationLogs.filter((l) => l.elderId === elderId);

    const hydrationLogs = this.store.hydrationLogs.filter((h) => h.elderId === elderId);
    const exerciseLogs = this.store.exerciseLogs.filter((e) => e.elderId === elderId);
    const appointments = this.store.appointments.filter((a) => a.elderId === elderId);
    const instructions = this.getByElderId(elderId);

    return {
      elderId,
      profile: {
        name: elder.name,
        dateOfBirth: elder.profile.dateOfBirth,
        medicalConditions: elder.profile.medicalConditions ?? [],
        allergies: elder.profile.allergies ?? [],
        contactNumber: elder.profile.contactNumber
      },
      vitals,
      medicationPlans,
      medicationLogs,
      hydrationLogs,
      exerciseLogs,
      appointments,
      instructions
    };
  }
}
