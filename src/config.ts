export const config = {
  appName: "CareCircle",
  port: Number(process.env.PORT ?? 4000),
  host: process.env.HOST ?? "0.0.0.0",
  mongodbUri: process.env.MONGODB_URI,
  firebaseServiceAccountJson: process.env.FIREBASE_SERVICE_ACCOUNT_JSON,
  geminiApiKey: process.env.GEMINI_API_KEY,
  geminiEndpoint: process.env.GEMINI_ENDPOINT,
  geminiModel: process.env.GEMINI_MODEL ?? "gemini-3-flash-preview",
  jwtSecret: process.env.JWT_SECRET ?? "carecircle-dev-secret",
  jwtRefreshSecret: process.env.JWT_REFRESH_SECRET ?? "carecircle-dev-refresh-secret",
  otpTtlMinutes: Number(process.env.OTP_TTL_MINUTES ?? 10),
  medicationResponseWindowMinutes: Number(process.env.MEDICATION_RESPONSE_WINDOW_MINUTES ?? 60),
  demoPassword: process.env.DEMO_PASSWORD ?? "Password123!"
};
