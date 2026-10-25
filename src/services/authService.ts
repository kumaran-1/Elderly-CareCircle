import bcrypt from "bcryptjs";
import crypto from "crypto";
import jwt from "jsonwebtoken";
import type { Request, Response, NextFunction } from "express";
import { config } from "../config";
import type { AuthContext, AuthTokens, Role, SystemStore, User } from "../domain/types";
import type { NotificationService } from "./notificationService";

export interface RegisterInput {
  name: string;
  email: string;
  password: string;
  role: Role;
}

export interface LoginInput {
  email: string;
  password: string;
}

export class AuthService {
  constructor(
    private readonly store: SystemStore,
    private readonly notifications: NotificationService,
    private readonly onChange: () => void = () => undefined
  ) {}

  register(input: RegisterInput): { user: Omit<User, "passwordHash" | "otpCode" | "otpExpiresAt">; otpCode: string } {
    const existing = this.store.users.find((user) => user.email.toLowerCase() === input.email.toLowerCase());
    if (existing) {
      throw new Error("An account with this email already exists.");
    }

    const otpCode = this.createOtp();
    const user: User = {
      id: crypto.randomUUID(),
      name: input.name,
      email: input.email.toLowerCase(),
      passwordHash: bcrypt.hashSync(input.password, 10),
      role: input.role,
      verified: false,
      profile: {},
      fcmTokens: [],
      otpCode,
      otpExpiresAt: new Date(Date.now() + config.otpTtlMinutes * 60 * 1000).toISOString(),
      refreshTokenVersion: 0,
      createdAt: new Date().toISOString()
    };

    this.store.users.push(user);
    this.onChange();
    this.notifications.create({
      userId: user.id,
      category: "otp",
      title: "Verify your CareCircle account",
      body: `Your verification code is ${otpCode}.`,
      metadata: { channel: "simulated" }
    });

    return { user: this.publicUser(user), otpCode };
  }

  login(input: LoginInput): { user: Omit<User, "passwordHash" | "otpCode" | "otpExpiresAt">; tokens: AuthTokens } {
    const user = this.getUserByEmail(input.email);
    if (!user) {
      throw new Error("Invalid email or password.");
    }

    const passwordMatches = bcrypt.compareSync(input.password, user.passwordHash);
    if (!passwordMatches) {
      throw new Error("Invalid email or password.");
    }

    user.refreshTokenVersion += 1;
    this.onChange();
    return { user: this.publicUser(user), tokens: this.issueTokens(user) };
  }

  verifyOtp(email: string, otp: string): { user: Omit<User, "passwordHash" | "otpCode" | "otpExpiresAt">; tokens: AuthTokens } {
    const user = this.getUserByEmail(email);
    if (!user) {
      throw new Error("Invalid verification request.");
    }

    const isExpired = !user.otpExpiresAt || new Date(user.otpExpiresAt).getTime() < Date.now();
    if (isExpired || user.otpCode !== otp) {
      throw new Error("OTP is invalid or has expired.");
    }

    user.verified = true;
    user.otpCode = undefined;
    user.otpExpiresAt = undefined;
    user.refreshTokenVersion += 1;
    this.onChange();

    return { user: this.publicUser(user), tokens: this.issueTokens(user) };
  }

  authenticate(token?: string): AuthContext {
    if (!token) {
      throw new Error("Missing bearer token.");
    }

    try {
      const payload = jwt.verify(token, config.jwtSecret) as AuthContext;
      return payload;
    } catch {
      throw new Error("Invalid or expired token.");
    }
  }

  authenticateRefreshToken(token?: string): AuthContext {
    if (!token) {
      throw new Error("Missing refresh token.");
    }

    try {
      const payload = jwt.verify(token, config.jwtRefreshSecret) as AuthContext;
      return payload;
    } catch {
      throw new Error("Invalid or expired refresh token.");
    }
  }

  issueTokens(user: User): AuthTokens {
    const claims: AuthContext = {
      userId: user.id,
      email: user.email,
      role: user.role,
      tokenVersion: user.refreshTokenVersion
    };

    return {
      accessToken: jwt.sign(claims, config.jwtSecret, { expiresIn: "4h" }),
      refreshToken: jwt.sign(claims, config.jwtRefreshSecret, { expiresIn: "7d" })
    };
  }

  getUserById(userId: string): User | undefined {
    return this.store.users.find((user) => user.id === userId);
  }

  getUserByEmail(email: string): User | undefined {
    return this.store.users.find((user) => user.email === email.toLowerCase());
  }

  refresh(userId: string): AuthTokens {
    const user = this.getUserById(userId);
    if (!user) {
      throw new Error("User not found.");
    }

    user.refreshTokenVersion += 1;
    this.onChange();
    return this.issueTokens(user);
  }

  requireRole(roles: Role[]) {
    return (req: Request, _res: Response, next: NextFunction): void => {
      if (!req.auth || !roles.includes(req.auth.role)) {
        next(new Error("You do not have access to this resource."));
        return;
      }

      next();
    };
  }

  publicUser(user: User): Omit<User, "passwordHash" | "otpCode" | "otpExpiresAt"> {
    const { passwordHash, otpCode, otpExpiresAt, ...publicUser } = user;
    return publicUser;
  }

  private createOtp(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }
}
