import crypto from "crypto";
import type {
  CareNote,
  CareNoteType,
  CareShift,
  CareTask,
  CareTaskPriority,
  CareTaskStatus,
  SystemStore
} from "../domain/types";
import type { CareCircleService } from "./careCircleService";
import type { NotificationService } from "./notificationService";

export interface CreateCareTaskInput {
  elderId: string;
  createdByUserId: string;
  assignedToUserId?: string;
  title: string;
  notes?: string;
  dueAt?: string;
  priority: CareTaskPriority;
}

export interface UpdateCareTaskInput {
  status?: CareTaskStatus;
  assignedToUserId?: string;
  title?: string;
  notes?: string;
  dueAt?: string;
  priority?: CareTaskPriority;
}

export interface CreateCareNoteInput {
  elderId: string;
  authorId: string;
  type: CareNoteType;
  title: string;
  body: string;
  shift?: CareShift;
}

export class CarePlanService {
  constructor(
    private readonly store: SystemStore,
    private readonly circles: CareCircleService,
    private readonly notifications: NotificationService,
    private readonly onChange: () => void = () => undefined
  ) {}

  createTask(input: CreateCareTaskInput): CareTask {
    const actor = this.requireCareMember(input.createdByUserId, input.elderId);
    this.validateAssignee(input.assignedToUserId, input.elderId);

    const task: CareTask = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      createdByUserId: input.createdByUserId,
      assignedToUserId: input.assignedToUserId,
      title: input.title.trim(),
      notes: input.notes?.trim() || undefined,
      dueAt: input.dueAt,
      priority: input.priority,
      status: "pending",
      createdAt: new Date().toISOString()
    };

    this.store.careTasks.push(task);
    this.onChange();

    const circle = this.circles.getCircleByElderId(input.elderId);
    if (circle) {
      if (input.assignedToUserId && input.assignedToUserId !== actor.id) {
        this.notifications.create({
          userId: input.assignedToUserId,
          elderId: input.elderId,
          category: "careTask",
          title: `New care task: ${task.title}`,
          body: `A new ${task.priority} priority task was assigned to you.`,
          metadata: { taskId: task.id, priority: task.priority }
        });
      } else if (!input.assignedToUserId) {
        this.notifications.broadcastToCareCircle(
          circle,
          {
            elderId: input.elderId,
            category: "careTask",
            title: `New care task: ${task.title}`,
            body: `${actor.name} added a ${task.priority} priority task for ${circle.name}.`,
            metadata: { taskId: task.id, priority: task.priority }
          },
          actor.id
        );
      }
    }

    return task;
  }

  getTasksForElder(elderId: string): CareTask[] {
    return this.store.careTasks
      .filter((task) => task.elderId === elderId)
      .sort((a, b) => {
        if (a.status !== b.status) return a.status === "pending" ? -1 : 1;
        const aDue = a.dueAt ? Date.parse(a.dueAt) : Number.MAX_SAFE_INTEGER;
        const bDue = b.dueAt ? Date.parse(b.dueAt) : Number.MAX_SAFE_INTEGER;
        if (aDue !== bDue) return aDue - bDue;
        return b.createdAt.localeCompare(a.createdAt);
      });
  }

  getPendingTaskCount(elderId: string): number {
    return this.store.careTasks.filter((task) => task.elderId === elderId && task.status === "pending").length;
  }

  updateTask(taskId: string, actorId: string, input: UpdateCareTaskInput): CareTask {
    const task = this.store.careTasks.find((candidate) => candidate.id === taskId);
    if (!task) throw new Error("Care task not found.");

    const actor = this.store.users.find((candidate) => candidate.id === actorId);
    if (!actor || actor.role === "admin") throw new Error("User not found.");
    if (!this.circles.userHasAccessToElder(actorId, task.elderId)) {
      throw new Error("You are not linked to this elder's CareCircle.");
    }

    const statusOnly = Object.keys(input).every((key) => key === "status");
    if (actor.role === "elder" && !statusOnly) {
      throw new Error("Elders can only update a care task status.");
    }

    this.validateAssignee(input.assignedToUserId, task.elderId);

    if (input.title !== undefined) task.title = input.title.trim();
    if (input.notes !== undefined) task.notes = input.notes.trim() || undefined;
    if (input.dueAt !== undefined) task.dueAt = input.dueAt;
    if (input.priority !== undefined) task.priority = input.priority;
    if (input.assignedToUserId !== undefined) task.assignedToUserId = input.assignedToUserId;
    if (input.status !== undefined) {
      task.status = input.status;
      task.completedAt = input.status === "completed" ? new Date().toISOString() : undefined;
    }

    task.updatedAt = new Date().toISOString();
    this.onChange();

    if (input.status === "completed" && task.createdByUserId !== actorId) {
      this.notifications.create({
        userId: task.createdByUserId,
        elderId: task.elderId,
        category: "careTask",
        title: `Care task completed: ${task.title}`,
        body: `${actor.name} marked the task as completed.`,
        metadata: { taskId: task.id, status: task.status }
      });
    }

    return task;
  }

  createNote(input: CreateCareNoteInput): CareNote {
    const actor = this.requireCareMember(input.authorId, input.elderId);

    const note: CareNote = {
      id: crypto.randomUUID(),
      elderId: input.elderId,
      authorId: input.authorId,
      type: input.type,
      title: input.title.trim(),
      body: input.body.trim(),
      shift: input.type === "handover" ? input.shift : undefined,
      createdAt: new Date().toISOString()
    };

    this.store.careNotes.push(note);
    this.onChange();

    const circle = this.circles.getCircleByElderId(input.elderId);
    if (circle) {
      this.notifications.broadcastToCareCircle(
        circle,
        {
          elderId: input.elderId,
          category: "careNote",
          title: input.type === "handover" ? `Handover: ${note.title}` : `Care note: ${note.title}`,
          body: `${actor.name} added ${input.type === "handover" ? "a shift handover" : "a care note"}.`,
          metadata: { noteId: note.id, type: note.type, shift: note.shift ?? "" }
        },
        input.authorId
      );
    }

    return note;
  }

  getNotesForElder(elderId: string): CareNote[] {
    return this.store.careNotes
      .filter((note) => note.elderId === elderId)
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
  }

  private requireCareMember(userId: string, elderId: string) {
    const actor = this.store.users.find((candidate) => candidate.id === userId);
    if (!actor || (actor.role !== "family" && actor.role !== "caregiver")) {
      throw new Error("Only family or caregiver members can manage the care plan.");
    }
    if (!this.circles.userHasAccessToElder(userId, elderId)) {
      throw new Error("You are not linked to this elder's CareCircle.");
    }
    return actor;
  }

  private validateAssignee(userId: string | undefined, elderId: string) {
    if (!userId) return;
    const assignee = this.store.users.find((candidate) => candidate.id === userId);
    if (!assignee || assignee.role === "admin") {
      throw new Error("Assigned user not found.");
    }
    if (!this.circles.userHasAccessToElder(userId, elderId)) {
      throw new Error("Assigned user is not part of this elder's CareCircle.");
    }
  }
}
