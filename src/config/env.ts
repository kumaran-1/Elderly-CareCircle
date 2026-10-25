import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().positive().default(4000),
  HOST: z.string().default("0.0.0.0"),
  MONGODB_URI: z.string().optional(),
  FIREBASE_SERVICE_ACCOUNT_JSON: z.string().optional(),
  GEMINI_API_KEY: z.string().optional(),
  GEMINI_ENDPOINT: z.string().url().optional(),
  GEMINI_MODEL: z.string().default("gemini-3.6-flash"),
  JWT_SECRET: z.string().optional(),
  JWT_REFRESH_SECRET: z.string().optional(),
  JWT_ACCESS_EXPIRES_IN: z.string().default("4h"),
  JWT_REFRESH_EXPIRES_IN: z.string().default("7d"),
  OTP_TTL_MINUTES: z.coerce.number().int().positive().default(10),
  MEDICATION_RESPONSE_WINDOW_MINUTES: z.coerce.number().int().positive().default(60),
  DEMO_PASSWORD: z.string().default("Password123!"),
  CORS_ORIGIN: z.string().optional(),
  RATE_LIMIT_WINDOW_MS: z.coerce
    .number()
    .int()
    .positive()
    .default(15 * 60 * 1000),
  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(30),
  FILE_UPLOAD_MAX_BYTES: z.coerce
    .number()
    .int()
    .positive()
    .default(10 * 1024 * 1024)
});

export type Env = z.infer<typeof envSchema>;

const parse = (): Env => {
  const result = envSchema.safeParse(process.env);
  if (!result.success) {
    const issues = result.error.issues.map((issue) => `${issue.path.join(".")}: ${issue.message}`).join("; ");
    throw new Error(`Invalid environment configuration: ${issues}`);
  }
  return result.data;
};

export const env = parse();

export interface AppConfig {
  readonly isProd: boolean;
  readonly appName: string;
  readonly port: number;
  readonly host: string;
  readonly mongodbUri?: string;
  readonly firebaseServiceAccountJson?: string;
  readonly geminiApiKey?: string;
  readonly geminiEndpoint?: string;
  readonly geminiModel: string;
  readonly jwtSecret: string;
  readonly jwtRefreshSecret: string;
  readonly jwtAccessExpiresIn: string;
  readonly jwtRefreshExpiresIn: string;
  readonly otpTtlMinutes: number;
  readonly medicationResponseWindowMinutes: number;
  readonly demoPassword: string;
  readonly corsOrigin?: string;
  readonly rateLimitWindowMs: number;
  readonly rateLimitMax: number;
  readonly fileUploadMaxBytes: number;
}

const devJwt = (name: string) => `${name}-${env.NODE_ENV}-insecure-dev-key-change-me`;

export const config: AppConfig = {
  isProd: env.NODE_ENV === "production",
  appName: "CareCircle",
  port: env.PORT,
  host: env.HOST,
  mongodbUri: env.MONGODB_URI,
  firebaseServiceAccountJson: env.FIREBASE_SERVICE_ACCOUNT_JSON,
  geminiApiKey: env.GEMINI_API_KEY,
  geminiEndpoint: env.GEMINI_ENDPOINT,
  geminiModel: env.GEMINI_MODEL,
  jwtSecret:
    env.NODE_ENV === "production" ? requireSecret("JWT_SECRET") : (env.JWT_SECRET ?? devJwt("carecircle-access")),
  jwtRefreshSecret:
    env.NODE_ENV === "production"
      ? requireSecret("JWT_REFRESH_SECRET")
      : (env.JWT_REFRESH_SECRET ?? devJwt("carecircle-refresh")),
  jwtAccessExpiresIn: env.JWT_ACCESS_EXPIRES_IN,
  jwtRefreshExpiresIn: env.JWT_REFRESH_EXPIRES_IN,
  otpTtlMinutes: env.OTP_TTL_MINUTES,
  medicationResponseWindowMinutes: env.MEDICATION_RESPONSE_WINDOW_MINUTES,
  demoPassword: env.DEMO_PASSWORD,
  corsOrigin: env.CORS_ORIGIN,
  rateLimitWindowMs: env.RATE_LIMIT_WINDOW_MS,
  rateLimitMax: env.RATE_LIMIT_MAX,
  fileUploadMaxBytes: env.FILE_UPLOAD_MAX_BYTES
};

function requireSecret(name: string): string {
  const value = process.env[name];
  if (!value || value.length < 16) {
    throw new Error(`Environment variable ${name} must be set to a secret of at least 16 characters in production.`);
  }
  return value;
}

if (env.NODE_ENV === "production" && config.jwtSecret === config.jwtRefreshSecret) {
  throw new Error("JWT_SECRET and JWT_REFRESH_SECRET must be distinct values in production.");
}
