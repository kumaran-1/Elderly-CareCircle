import type { SystemStore, User } from "../domain/types";

/**
 * Persistence contract for user/account records.
 * Production uses the MongoDB-backed directory; when MongoDB is not
 * configured, the in-memory directory over the shared store is used.
 */
export interface UserDirectory {
  list(): Promise<User[]>;
  findById(userId: string): Promise<User | undefined>;
  findByEmail(email: string): Promise<User | undefined>;
  create(user: User): Promise<User>;
  update(userId: string, patch: Partial<Omit<User, "id">>): Promise<User | undefined>;
}

/** In-memory directory backed by the shared store. */
export class MemoryUserDirectory implements UserDirectory {
  constructor(private readonly store: SystemStore) {}

  async list(): Promise<User[]> {
    return this.store.users.map((user) => ({ ...user }));
  }

  async findById(userId: string): Promise<User | undefined> {
    return this.store.users.find((user) => user.id === userId);
  }

  async findByEmail(email: string): Promise<User | undefined> {
    return this.store.users.find((user) => user.email === email.toLowerCase());
  }

  async create(user: User): Promise<User> {
    if (
      this.store.users.some(
        (candidate) => candidate.id === user.id || candidate.email.toLowerCase() === user.email.toLowerCase()
      )
    ) {
      throw new Error("An account with this email already exists.");
    }
    this.store.users.push(user);
    return user;
  }

  async update(userId: string, patch: Partial<Omit<User, "id">>): Promise<User | undefined> {
    const user = this.store.users.find((candidate) => candidate.id === userId);
    if (!user) {
      return undefined;
    }
    for (const [key, value] of Object.entries(patch)) {
      if (value === undefined) {
        delete (user as unknown as Record<string, unknown>)[key];
      } else {
        (user as unknown as Record<string, unknown>)[key] = value;
      }
    }
    return user;
  }
}
