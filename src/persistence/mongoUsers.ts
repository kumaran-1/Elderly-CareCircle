import mongoose, { Schema } from "mongoose";
import type { User } from "../domain/types";
import type { UserDirectory } from "./userDirectory";

const userSchema = new Schema(
  {
    id: { type: String, required: true, unique: true },
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    // No enum constraint: the collection faithfully preserves every stored
    // account record, including legacy roles. Role validity for new accounts
    // is enforced at the API boundary (registerSchema / Role type).
    role: { type: String, required: true },
    verified: { type: Boolean, required: true },
    profile: { type: Schema.Types.Mixed, default: {} },
    fcmTokens: { type: [String], default: [] },
    otpCode: { type: String },
    otpExpiresAt: { type: String },
    refreshTokenVersion: { type: Number, required: true },
    createdAt: { type: String, required: true }
  },
  // minimize:false keeps empty objects (e.g. profile:{}) intact so records
  // round-trip byte-for-byte instead of silently dropping empty subdocuments.
  { versionKey: false, minimize: false }
);

const UserModel = mongoose.model("User", userSchema, "users");

function toUser(doc: Record<string, unknown>): User {
  const { _id: _ignored, ...rest } = doc;
  void _ignored;
  return rest as unknown as User;
}

function isDuplicateKey(error: unknown): boolean {
  return (error as { code?: number }).code === 11000;
}

/** MongoDB-backed user directory using the dedicated `users` collection. */
export class MongoUserDirectory implements UserDirectory {
  static async connect(uri: string): Promise<void> {
    await mongoose.connect(uri);
    await UserModel.createIndexes();
  }

  /**
   * One-time migration seed: inserts the given users only when the
   * collection is empty. Existing records are never overwritten, and the
   * unique indexes on `id`/`email` prevent duplicates.
   */
  static async seedIfEmpty(users: User[]): Promise<{ seeded: boolean; count: number }> {
    const count = await UserModel.countDocuments();
    if (count > 0 || users.length === 0) {
      return { seeded: false, count };
    }
    try {
      await UserModel.insertMany(users.map((user) => ({ ...user })), { ordered: true });
    } catch (error) {
      if (!isDuplicateKey(error)) {
        throw error;
      }
      // Lost a concurrent first-boot race: another instance seeded already.
      return { seeded: false, count: await UserModel.countDocuments() };
    }
    return { seeded: true, count: users.length };
  }

  async list(): Promise<User[]> {
    const docs = await UserModel.find().lean();
    return docs.map((doc) => toUser(doc as Record<string, unknown>));
  }

  async findById(userId: string): Promise<User | undefined> {
    const doc = await UserModel.findOne({ id: userId }).lean();
    return doc ? toUser(doc as Record<string, unknown>) : undefined;
  }

  async findByEmail(email: string): Promise<User | undefined> {
    const doc = await UserModel.findOne({ email: email.toLowerCase() }).lean();
    return doc ? toUser(doc as Record<string, unknown>) : undefined;
  }

  async create(user: User): Promise<User> {
    try {
      const doc = await UserModel.create({ ...user });
      return toUser(doc.toObject({ minimize: false }));
    } catch (error) {
      if (isDuplicateKey(error)) {
        throw new Error("An account with this email already exists.", { cause: error });
      }
      throw error;
    }
  }

  async update(userId: string, patch: Partial<Omit<User, "id">>): Promise<User | undefined> {
    const set: Record<string, unknown> = {};
    const unset: Record<string, 1> = {};
    for (const [key, value] of Object.entries(patch)) {
      if (value === undefined) {
        unset[key] = 1;
      } else {
        set[key] = value;
      }
    }
    const update: Record<string, unknown> = {};
    if (Object.keys(set).length > 0) update.$set = set;
    if (Object.keys(unset).length > 0) update.$unset = unset;
    if (Object.keys(update).length === 0) {
      return this.findById(userId);
    }
    try {
      const doc = await UserModel.findOneAndUpdate({ id: userId }, update, { new: true }).lean();
      return doc ? toUser(doc as Record<string, unknown>) : undefined;
    } catch (error) {
      if (isDuplicateKey(error)) {
        throw new Error("An account with this email already exists.", { cause: error });
      }
      throw error;
    }
  }
}
