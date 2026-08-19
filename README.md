# Humm Capture

`humm_capture` captures visual feedback from Flutter applications without
coupling the package to a particular backend.

It creates a report containing an annotated screenshot, a tester description
an explicit support-context snapshot, and optional tester-selected images or
videos. The host application decides whether
to send the report to its own HTTP endpoint, Firebase Function or another
destination.

It supports two input modes:

- an in-app screenshot captured before the feedback UI appears;
- a system screenshot imported by the host application.

The host owns authentication, storage and persistence through a
`FeedbackReporter`.

## Status

The package is stable. It provides in-app capture, host-supplied system
screenshot import, highlight annotations, an English composer, support context
and a destination-agnostic delivery contract. Backend adapters remain outside
this package so that Firebase credentials are never required by every consumer.

## Usage

Wrap the app content with `FeedbackCaptureBoundary`:

```dart
final feedbackController = FeedbackCaptureController();

FeedbackCaptureBoundary(
  controller: feedbackController,
  reporter: HttpFeedbackReporter(
    endpoint: Uri.parse('https://api.example.com/feedback'),
    headersProvider: () async => {
      'authorization': 'Bearer ${await session.feedbackAccessToken()}',
    },
  ),
  contextProvider: () => FeedbackContext(
    appVersion: '1.4.0',
    buildNumber: '42',
    platform: FeedbackPlatform.android,
    screenName: 'checkout.payment',
    locale: 'en-US',
    metadata: const {'environment': 'staging'},
  ),
  attachmentPicker: (type) => switch (type) {
    FeedbackAttachmentType.image => mediaPicker.pickImages(),
    FeedbackAttachmentType.video => mediaPicker.pickVideo(),
  },
  taskCreationAvailabilityProvider: () async {
    // Query your authenticated backend. Do not decide permissions in Flutter.
    return feedbackApi.canCreateLinkedTask();
  },
  child: const AppContent(),
);

```

`HttpFeedbackReporter` sends one portable JSON payload containing the image as
Base64, the message, selected kind (`feedback` or `bug`), normalized annotation
strokes, optional selected media and explicitly supplied context. It requires HTTPS unless
`allowInsecureHttp: true` is set for local development. It also accepts a custom
`package:http` client for host-specific network configuration and deterministic
tests.

## Optional media attachments

Supply `attachmentPicker` when the host app should expose its native gallery.
The composer presents separate actions for photos and video, keeps file names
private in the UI, and lets the tester review or remove selected media before
sending. The callback returns `FeedbackAttachment` values owned by the host
application. `attachmentsProvider` remains available for compatibility but is
deprecated because it cannot distinguish the requested media type.

## Optional linked tasks

The default composer can show a **Create a linked task** checkbox. Supply
`taskCreationAvailabilityProvider` only when the host backend exposes a
server-side availability check. The checkbox stays hidden while the provider
returns `false` or fails. A report then includes `requestTaskCreation: true`.

This is intentionally a request, not permission. The receiving backend must
check the authenticated user and the destination integration again before it
creates a task. This keeps Jira, Linear, or another task system optional and
prevents a modified client from granting itself access.

For Firebase, expose an authenticated Firebase Function or Cloud Run endpoint
from the host application's Firebase project and use the same reporter. This
keeps Firebase rules, App Check, authentication and the report schema under the
host application's control.

By default, a three-finger long press opens the flow. For a custom QA action,
set `trigger: FeedbackTrigger.none` and call
`feedbackController.captureAppView()`.

When the host receives an operating-system screenshot from a share or import
flow, provide it through `feedbackController.addSystemScreenshot(...)`.

## Delivery results

Return `FeedbackSubmissionSuccess` when the destination accepted the report.
Return `FeedbackSubmissionFailure` with an English, user-facing message when
delivery failed. The composer closes after preparing the image; delivery
continues in the background and one status notice shows a loader, then changes
in place to success or failure.
Supply `FeedbackDeliveryCallbacks` to render those states in the host app.

This is non-blocking delivery while the host app remains alive. It is not a
durable local outbox: closing the process before a response may interrupt an
upload. A persistent retry queue belongs to the host application or a future
optional storage adapter.

## Support context and privacy

`FeedbackContext` is intentionally opt-in. The package does not automatically
read account IDs, device diagnostics, route history, locale or analytics. A
host app should only pass the context needed to investigate the report:

- app version and build number identify the released binary;
- platform and operating-system version distinguish environment-specific bugs;
- screen name identifies where the problem occurred;
- locale helps reproduce localized UI issues;
- metadata is for small, serializable, host-defined values.

Only provide `userId` when the host has a legitimate reason to associate a
report with a user. Do not put tokens, passwords, request payloads or other
secrets in `metadata`.

See [integration documentation](doc/integration.md) for the API contract and
[backend adapter notes](doc/backend-adapters.md) for a safe Firebase intake.

For a complete Firebase-backed installation — SDK, authenticated intake,
reviewer roles, the standalone console and Hosting — see the
[self-hosted Feedback Console guide](doc/self-hosted-feedback-console.md).

## Boundaries

The package intentionally does not include Firebase, authentication or
analytics. Its small HTTP transport accepts an application-controlled endpoint
and headers provider; it never knows an integration secret or chooses a
backend. A direct Firebase reporter belongs in a separate optional package so
Firebase does not become mandatory for other adopters.

## Development

The package uses a 120-character Dart formatter width and strict static
analysis. Before contributing or preparing a release, run:

```bash
fvm dart format .
fvm dart analyze lib test example/lib
fvm flutter test
fvm dart pub publish --dry-run
```
