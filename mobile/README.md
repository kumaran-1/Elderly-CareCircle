# CareCircle Mobile

This folder contains a Flutter client scaffold for the CareCircle app.

The mobile app now includes a fresh daylight theme, a role-aware landing screen, a backend-connected email/password login flow, secure session restoration, and a dashboard that fetches the authenticated user profile, notifications, and role summary from the Express backend in the root project.

The client also includes an API helper for login, OTP verification, session refresh, dashboard loading, notifications, reports, medication, vitals, hydration, exercise, AI, and SOS calls.

By default, the client targets `http://localhost:4000`.

If you run on an Android emulator, use:

`flutter run --dart-define=CARECIRCLE_API_BASE_URL=http://10.0.2.2:4000`

## Notes

- The current UI is intentionally high-contrast and role-aware for elder usability.
- The visual system uses a calm green, cream, and sky-blue palette with large controls and clear action hierarchy.
- Session tokens are stored securely through Flutter secure storage.
- The app refreshes the session using the backend refresh endpoint when possible.
