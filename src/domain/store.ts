import type { SystemStore } from "./types";

export const createEmptyStore = (): SystemStore => ({
  users: [],
  careCircles: [],
  careInstructions: [],
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
