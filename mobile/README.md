# CareCircle Mobile

This folder contains a Flutter client scaffold for the CareCircle app.

The mobile app now includes a warm daylight theme, a three-role landing screen (elder, family, caregiver), backend-connected email/password login with OTP registration, secure session restoration, role-specific shells, and dashboards that fetch live data from the Express backend in the root project.

The client also includes an API helper for login, OTP verification, session refresh, dashboard loading, notifications, reports, medication, vitals, hydration, exercise, care plans, appointments, care instructions, AI, and SOS calls.

By default, debug builds target the deployed API at `https://carecircle-api-l8pk.onrender.com`. Override it with:

`flutter run --dart-define=CARECIRCLE_API_BASE_URL=http://10.0.2.2:4000`

## Notes

- The current UI is intentionally high-contrast and role-aware for elder usability.
- The visual system uses a forest-green, warm ivory, and peach palette with large controls and clear action hierarchy.
- Session tokens and API endpoint overrides are stored securely through Flutter secure storage.
- The app refreshes the session using the backend refresh endpoint when possible.
- Firebase push delivery is not configured; in-app alerts are available from the server.
