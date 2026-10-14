# Updating Humm Capture in a consuming application

The SDK package is `humm_capture` (release candidate 2.0.0). The repository directory
may still be named `humm_feedback`. SDK, standalone console and Firebase
services are three independent deliverables; updating one does not deploy the others.

## Validate the library before sharing a release

1. Review the intended diff; do not include local Firebase configuration,
   credentials, `.dart_tool`, build output, or signing changes.
2. Update `pubspec.yaml` and `CHANGELOG.md` only when preparing a real release.
   A compatible feature normally increments the minor version; breaking public
   contracts require a major release. Do not reuse a published version.
3. From the repository root run:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
dart pub publish --dry-run
```

These commands validate only: the dry run does not publish. The current local
changes are not a published update to 1.0.1. Publish requires a separate explicit
release decision and publisher access. For a ZIP handoff, include source,
tests, license, changelog, documentation and the standalone console; exclude
credentials and generated/build directories. A consumer cannot use a ZIP with
`humm_capture: ^1.0.1` unless that code is actually published under that version.

## Update the Crustlab application

Use the consuming project's pinned Flutter SDK (`fvm flutter` if configured).
For a published release update its dependency and resolve it:

```yaml
dependencies:
  humm_capture: ^<published-version>
```

```sh
flutter pub get
flutter analyze
flutter test
```

For local acceptance testing only, override the dependency with an extracted
library directory. Remove the override before release/CI:

```yaml
dependency_overrides:
  humm_capture:
    path: /absolute/path/to/humm_feedback
```

Preserve the application's reporter/auth integration. Never embed a static
backend bearer token, Slack webhook or Jira token in the mobile build. Set the
environment from the application's existing flavor/config, not a tester dropdown.
Connect its logger to `FeedbackLogBuffer` after redaction; see feedback-options.md.

## Update the standalone console and Firebase services

Target the consuming application's Firebase project, not Humm Hub. Back up and
review existing rules: do not overwrite unrelated application rules blindly.
The deployment uses the authenticated account's existing project permissions.
Complete initial setup using the onboarding guide before running updates.

```sh
cd feedback_console/firebase/functions
npm ci
npm test
npm run build
cd ..
firebase deploy --only functions --project <firebase-project-id>
cd ..
flutter pub get
flutter analyze
flutter test
flutter build web --release --dart-define-from-file=config/feedback_console.json
mkdir -p firebase/.hosting-build
rsync -a build/web/ firebase/.hosting-build/
cd firebase
firebase deploy --only hosting --project <firebase-project-id>
```

`config/feedback_console.json` and project `.env` files are local deployment
configuration; do not distribute your project's values in a release ZIP.
Deploy changed rules only after reviewing their merge into the host project.
Slack remains configured server-side and existing connections need not be recreated.
The bundled services provide authenticated intake, Slack and Jira endpoints.

## Acceptance and rollback

Test a new report from a real device in each supported environment, attachments
enabled/disabled, image preview, video file (no panel player), log download,
unauthorized account denial, and Slack link before/after login. Jira requires configured server-side credentials and a real integration test.
Save the previous SDK dependency and console/functions source revision. Roll
back by restoring those versions and redeploying to the same explicit project.
Do not assume a mobile update automatically rolls back backend contracts.
