# CareCircle MVP

CareCircle is an elderly-care workflow backend that models the documented flow for authentication, role-based dashboards, care circles, health activity logging, notifications, AI safety checks, SOS escalation, and reporting.

The repository also includes a Flutter client scaffold under [mobile](mobile) for the role-based mobile experience.

This workspace contains a practical TypeScript/Express MVP with:

- Email/password + JWT authentication
- Elder, Family Member, Caregiver, and Admin roles
- Care circle membership and invite flow
- Vitals, medication, hydration, exercise, and appointment APIs
- Event-driven notifications
- Safe AI assistant routing with emergency detection
- SOS creation, acknowledgement, and resolution
- Weekly and monthly report summaries
- Admin analytics that stay at the aggregate level

## Run locally

1. Install dependencies.
2. Start the API with `npm run dev`.
3. Use the seeded demo accounts or register a new account.
4. Run the smoke test with `npm run test`.

`npm run test` runs both the service-level workflow test and the HTTP API test, including JWT/OTP login, refresh, alerting, and admin privacy enforcement.

## Container deployment

Set strong values for `JWT_SECRET` and `JWT_REFRESH_SECRET`, then start the API and MongoDB together:

`docker compose up --build`

The API is available on port `4000`. Gemini and Firebase remain optional environment integrations; configure `GEMINI_API_KEY` and `FIREBASE_SERVICE_ACCOUNT_JSON` when those services are ready.

## Staging and production

Use the included CI workflow to validate backend and Flutter web builds on every push or pull request. For staging or production, provide `MONGODB_URI`, strong JWT secrets, and optional Gemini/Firebase secrets through the deployment platform's secret manager, then deploy the container from the included `Dockerfile`.

To use MongoDB instead of the local JSON store, set `MONGODB_URI` before starting the API. For example:

`$env:MONGODB_URI="mongodb://127.0.0.1:27017/carecircle"; npm run dev`

Copy `.env.example` to `.env` and replace the development secrets before using a shared or production environment. The backend loads `.env` automatically; never commit the filled-in `.env` file.

## Demo accounts

The seed data includes verified sample users for:

- Elder: Rajendran
- Family: Asha
- Caregiver: Suresh
- Admin: Admin User

The default demo password is `Password123!`.

## API surface

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/verify-otp` (legacy registration verification)
- `POST /auth/refresh`
- `GET /me`
- `GET /dashboard`
- `POST /care-circles`
- `POST /care-circles/:id/invite`
- `POST /care-circles/:id/accept`
- `GET /care-circles/me`
- `POST /health/vitals`
- `GET /health/vitals/:elderId`
- `POST /medications`
- `POST /medications/:id/logs`
- `POST /hydration/logs`
- `POST /exercise/logs`
- `POST /appointments`
- `POST /ai/chat`
- `POST /files/upload`
- `GET /files`
- `POST /sos`
- `POST /sos/:id/acknowledge`
- `POST /sos/:id/resolve`
- `GET /reports/summary/:elderId`
- `GET /reports/summary/:elderId/pdf`
- `GET /notifications`
- `POST /notifications/device`
- `GET /admin/analytics`

## Notes

- The app now persists to a local JSON file in `data/carecircle-store.json`.
- Set `MONGODB_URI` to enable the Mongoose-backed store; local JSON remains the fallback.
- The AI assistant uses a local safe fallback and calls Gemini directly when `GEMINI_API_KEY` is configured; `GEMINI_ENDPOINT` remains available for a proxy.
- FCM delivery is enabled when `FIREBASE_SERVICE_ACCOUNT_JSON` and a device token are configured.
- File uploads are stored locally in `data/files/` through a cloud-storage-style adapter.
- The services are separated so the persistence layer can be swapped for MongoDB/Mongoose later with minimal change.
- Public registration cannot create admin accounts; administrators must be provisioned separately.
