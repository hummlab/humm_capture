# Humm Capture test application

Independent Android host consuming `humm_capture` 1.0.1 through `path: ../`.
This tests unpublished local changes, not the pub.dev release. It signs in with
Firebase Auth and sends real reports to the configured HTTP intake.

Use an ignored configuration file with `FIREBASE_API_KEY`, `FIREBASE_APP_ID`,
`FIREBASE_SENDER_ID`, `FIREBASE_PROJECT_ID` and `FEEDBACK_ENDPOINT`.
Never add the administrator password to that file.
Run `flutter pub get`, then launch with the project's Firebase configuration
and `--dart-define=APP_ENV=dev`:

```bash
flutter run -d DEVICE_ID --dart-define-from-file=config/firebase-test.json --dart-define=APP_ENV=dev
```

Repeat with separate `stage` and `prod` launches;
environment is selected at build time, not with an in-app dropdown.

## Device checklist

- Open feedback, draw and undo a marker; switch Feedback/Bug.
- Enter text and hide the keyboard; check screenshot sizing and safe areas.
- Select image/video from Media, preview and remove it.
- Disable attachments and check that Media disappears.
- Launch each environment build and verify its label in the hosted panel.
- Submit successfully: verify the real report and files in Firebase.
- Check actual authorization/network failures without showing a success result.

Gallery selection uses host-owned `image_picker`, not a core SDK dependency.
This harness accepts PNG/JPEG/WebP/MP4/MOV up to 15 MB per file, only in memory.
Logs combine persisted safe lifecycle events, the in-memory auth buffer and
real Android process logcat. The example persists a safe native startup marker
with a process-session timestamp and build mode, allowing restart verification.
It also emits a safe runtime marker when collecting feedback and requires that
native marker before sending; it does not
upload arbitrary OS/framework logs. Android collection does not use ADB or root.
Only the current app process is visible; OS ring-buffer retention is not promised.
Android activity destruction
during picking is not recovered here; production hosts need retrieveLostData.

Storage permissions, panel previews/filtering and Slack delivery must be tested
against the configured Firebase project. See
../feedback_console/doc/firebase-onboarding.md and
../feedback_console/doc/slack-integration.md. Never embed Slack webhooks or
privileged credentials in the app.

## Release acceptance

Build with `flutter build apk --release --dart-define-from-file=config/firebase-test.json --dart-define=APP_ENV=dev`.
Install with `adb install -r` to preserve sign-in and the private diagnostic file.
Verify Android package flags do not contain DEBUGGABLE. Launch once, force-stop,
then launch again without clearing data. Submit screenshot/image/video and check
that uploaded logs contain native startup records from both process sessions,
with `mode=release`, plus the current submission marker.

This harness intentionally records only its safe native markers. It does not
promise all Android OS logs, a full 24-hour OS ring buffer, or automatic logging
of arbitrary production application events. Production hosts must persist their
sanitized logger events continuously. The sample APK uses the existing debug
signing key for local installation; release compilation and signing identity are
independent, and this is not a store-distribution build.
