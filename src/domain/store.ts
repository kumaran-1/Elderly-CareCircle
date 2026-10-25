import type { SystemStore } from "./types";

export const createEmptyStore = (): SystemStore => ({
  users: [],
  careCircles: [],
  vitals: [],
  medicationPlans: [],
  medicationLogs: [],
  hydrationLogs: [],
  exerciseLogs: [],
  appointments: [],
  conversations: [],
  notifications: [],
  sosEvents: [],
  files: []
});
