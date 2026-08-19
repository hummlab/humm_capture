# Integration contract

## Purpose

`humm_capture` owns visual capture and report composition. It deliberately
does not own authentication, persistence or a feedback lifecycle.
This lets the same package work in internal QA builds, client applications and
projects that do not use Firebase.

For the complete Firebase-backed implementation, including the standalone
review panel, see the [self-hosted Feedback Console guide](self-hosted-feedback-console.md).

## Flow

1. `FeedbackCaptureBoundary` captures the Flutter view before its composer is
   displayed.
2. The tester highlights the image, adds an optional description and can select
   optional image or video attachments when the host supplies an
   `attachmentPicker`. The callback receives the requested media type, so the
   host can open the photo gallery or the video gallery directly.
3. The boundary passes a snapshot from `FeedbackContextProvider` to the
   composer.
4. The composer prepares `FeedbackReport` and closes.
5. The boundary calls `FeedbackReporter.submit` in the background.
6. The reporter returns `FeedbackSubmissionSuccess` or
   `FeedbackSubmissionFailure`; the boundary displays a brief notice or calls
   the host's `FeedbackDeliveryCallbacks`.

The built-in flow intentionally does not wait for a network round trip in the
composer. It still waits briefly to render the annotation into the screenshot,
then immediately returns the tester to the application. This is not a durable
outbox: if the host process is stopped during delivery, an in-flight request
can be interrupted. Hosts that need guaranteed eventual delivery should persist
the report locally and retry it through their own `FeedbackReporter`.

## Host responsibilities

The host must provide a `FeedbackReporter`. It can use the included
`HttpFeedbackReporter` or provide its own. A host can:

- upload `report.image.bytes` to object storage;
- create a backend record with the image reference, text and context;
- call an authenticated HTTP endpoint;
- enqueue a report for a later retry;
- return a controlled failure if delivery is unavailable.

The reporter should not put backend credentials in the Flutter package or in
the report metadata. Authorize sensitive writes on a backend service. For an
HTTPS endpoint, pass a short-lived host-app access token through
`headersProvider`; a backend credential belongs only in that endpoint's
server-side environment.

## Delivery notifications

Without configuration, the boundary shows one English `SnackBar` with a loader;
it changes in place to `Feedback sent.` or a delivery failure. A host can render
its own localized UI without changing the reporter:

```dart
FeedbackCaptureBoundary(
  reporter: reporter,
  deliveryCallbacks: FeedbackDeliveryCallbacks(
    onStarted: () => showNotice('Feedback is being sent.'),
    onCompleted: (result) => switch (result) {
      FeedbackSubmissionSuccess() => showNotice('Feedback sent.'),
      FeedbackSubmissionFailure(:final message) => showNotice(message),
    },
  ),
  child: const AppContent(),
)
```

## HTTP reporter payload

`HttpFeedbackReporter` posts JSON with `capturedAt`, `imageBase64`,
`contentType`, `fileName`, `imageSource`, `message`, `annotationStrokes` and
`context`. When supplied, `attachments` contains `fileName`, `mimeType` and
`dataBase64` for each intentionally selected image or video. The receiving
backend must set count and byte limits before persisting any attachment.
A successful `2xx` response may return `feedbackId`, `reference` or
`id` as a JSON string. A `408`, `429` or `5xx` response is retryable; an
authentication or validation response is not.

```dart
final class ApiFeedbackReporter implements FeedbackReporter {
  @override
  Future<FeedbackSubmissionResult> submit(FeedbackReport report) async {
    try {
      // 1. Upload report.image.bytes.
      // 2. Send its URL plus report.message and report.context.
      // 3. Validate the server response.
      return const FeedbackSubmissionSuccess(reference: 'feedback-123');
    } on Object {
      return const FeedbackSubmissionFailure(
        message: 'Could not send feedback. Please try again.',
      );
    }
  }
}
```

## Context fields

`FeedbackContext` uses optional fields because the SDK cannot know what is
safe or useful for every host application.

| Field | Why it can be useful | Source of truth |
| --- | --- | --- |
| `appVersion`, `buildNumber` | Reproduce an issue on the right release. | Host release metadata |
| `platform`, `operatingSystemVersion` | Identify environment-specific behavior. | Host platform integration |
| `screenName` | Locate the reported UI flow. | Router or feature code |
| `locale` | Reproduce translations and layout. | Host locale |
| `userId` | Contact or identify a tester when justified. | Host auth layer |
| `metadata` | Small, serializable project-specific context. | Host feature code |

Do not send secrets, access tokens, raw HTTP responses, payment data or large
payloads in `metadata`.

## Capture limitations

In-app capture uses Flutter's `RenderRepaintBoundary`. It captures Flutter
pixels rendered below the boundary, not an operating-system screenshot. Native
or platform views can require a separate imported screenshot flow. The SDK
keeps `FeedbackImageSource.systemScreenshot` for that future host-driven path.

## Localization

The built-in composer currently uses English strings to keep the pre-release
SDK usable across projects. Localization must be added through a dedicated,
public configuration API rather than by modifying package source in each host.
