import mongoose, { Schema } from "mongoose";
import { createEmptyStore } from "../domain/store";
import type { SystemStore } from "../domain/types";

const storeSchema = new Schema(
  {
    key: { type: String, unique: true, required: true },
    snapshot: { type: Schema.Types.Mixed, required: true }
  },
  { timestamps: true }
);

const StoreDocument = mongoose.model("CareCircleStore", storeSchema);

export class MongoStore {
  private saveQueue: Promise<void> = Promise.resolve();

  constructor(private readonly store: SystemStore) {}

  static async loadOrSeed(uri: string, seedFactory: () => SystemStore): Promise<MongoStore> {
    await mongoose.connect(uri);
    const document = await StoreDocument.findOne({ key: "primary" }).lean();
    if (!document?.snapshot) {
      return new MongoStore(seedFactory());
    }

    return new MongoStore(mergeStore(createEmptyStore(), document.snapshot as Partial<SystemStore>));
  }

  get value(): SystemStore {
    return this.store;
  }

  save(): Promise<void> {
    this.saveQueue = this.saveQueue.then(async () => {
      await StoreDocument.findOneAndUpdate(
        { key: "primary" },
        { key: "primary", snapshot: this.store },
        { upsert: true, setDefaultsOnInsert: true }
      );
    });
    return this.saveQueue;
  }

  async close(): Promise<void> {
    await this.saveQueue;
    await mongoose.disconnect();
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
