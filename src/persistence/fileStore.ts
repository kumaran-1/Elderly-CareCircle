import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { createEmptyStore } from "../domain/store";
import type { SystemStore } from "../domain/types";

const dataDir = path.join(process.cwd(), "data");
const dataFile = path.join(dataDir, "carecircle-store.json");

export class FileStore {
  constructor(private readonly store: SystemStore) {}

  static async load(): Promise<FileStore> {
    try {
      const raw = await readFile(dataFile, "utf8");
      const parsed = JSON.parse(raw) as SystemStore;
      return new FileStore(mergeStore(createEmptyStore(), parsed));
    } catch {
      return new FileStore(createEmptyStore());
    }
  }

  static async loadOrSeed(seedFactory: () => SystemStore): Promise<FileStore> {
    const fileStore = await FileStore.load();
    const hasAnyData = fileStore.value.users.length > 0 || fileStore.value.careCircles.length > 0;
    return hasAnyData ? fileStore : new FileStore(seedFactory());
  }

  get value(): SystemStore {
    return this.store;
  }

  async save(): Promise<void> {
    await mkdir(dataDir, { recursive: true });
    await writeFile(dataFile, JSON.stringify(this.store, null, 2), "utf8");
  }

  async close(): Promise<void> {
    return Promise.resolve();
  }
}

function mergeStore(base: SystemStore, incoming: Partial<SystemStore>): SystemStore {
  const users = (incoming.users ?? base.users).map((user) => ({ ...user, fcmTokens: user.fcmTokens ?? [] }));
  return {
    users,
    careCircles: incoming.careCircles ?? base.careCircles,
    careInstructions: incoming.careInstructions ?? base.careInstructions,
    vitals: incoming.vitals ?? base.vitals,
    medicationPlans: incoming.medicationPlans ?? base.medicationPlans,
    medicationLogs: incoming.medicationLogs ?? base.medicationLogs,
    hydrationLogs: incoming.hydrationLogs ?? base.hydrationLogs,
    exerciseLogs: incoming.exerciseLogs ?? base.exerciseLogs,
    appointments: incoming.appointments ?? base.appointments,
    conversations: incoming.conversations ?? base.conversations,
    notifications: incoming.notifications ?? base.notifications,
    sosEvents: incoming.sosEvents ?? base.sosEvents,
    files: incoming.files ?? base.files
  };
}
