# Production onboarding acceptance

The SDK remains Firebase-independent. Updating pubspec alone is insufficient
for the first installation: wrap the host UI in FeedbackCaptureBoundary, supply
its context/reporter and authenticated HTTP headers, and bind the host logger.
Optional photos/videos need a host picker. Use FeedbackLogStore for private,
redacted app diagnostics and clear it on account changes. Android native
process snapshots are available through collectAndroidFeedbackLogs; iOS/Web
need their host logging integration. No complete phone-wide logging is claimed.

Deploy Auth, Firestore, Storage, Functions intake/integration endpoints and
Hosting to the intended customer's Firebase project. Rules and Hosting alone
do not deploy the intake. Configure the console Web app, actual runtime IAM,
Storage CORS and submitter/reviewer/admin profiles. Match Firebase ID token
audience to that backend project, or implement an explicitly authenticated
custom backend adapter. The SDK does not receive administrative credentials.

Configure Slack/Jira in the authenticated console; webhook/API secrets remain
in server Secret Manager. A webhook alone is not a complete Jira issue exporter:
site, project, issue type and credential configuration must match the backend
API. Use separate project/configuration for production, not the shared test app.

## Verified 2026-10-14

Physical Samsung SM-A536B → app UI → real HTTP intake → Firestore/Storage →
test-capture-feedback console. Final report N3NR0US9OlXtT1ZtyPVY contains a
screenshot, PNG, 3-second MP4 and 7-entry logs.txt with an actual
android.logcat/flutter runtime record. Media SHA-256 matches source fixtures.
Persisted events from earlier app processes survive restarts. Backend Slack
status is sent. Native records are collected inside the Android application,
not attached afterwards through ADB. Whole 24-hour elapsed retention, iOS
native logs, another production app and production deployment remain unverified.
Local SDK changes have not been published to pub.dev.
