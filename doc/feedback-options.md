# Feedback configuration

## Optional media attachments

Set `attachmentsEnabled: false` on `FeedbackCaptureBoundary` to hide the media
attachment action and prevent either configured picker from being invoked.
This does not disable the captured screenshot or diagnostic logs. The default
is `true`; image/video selection still requires a host-provided picker.

```dart
FeedbackCaptureBoundary(
  reporter: reporter,
  attachmentsEnabled: false,
  contextProvider: () => const FeedbackContext(
    environment: FeedbackEnvironment.stage,
  ),
  child: app,
)
```

## Environment

The host chooses `FeedbackEnvironment.dev`, `.stage`, or `.prod` at startup.
The SDK sends its name as `context.environment`. It does not infer an
environment from a package name, Firebase project, or a debug build.
The field is optional for compatibility with existing applications and reports.
The console displays `Unspecified` for older reports.

## Media previews

Image attachments have a thumbnail and an enlarged image preview. Video
attachments remain files opened externally; the console does not embed a player.
Storage metadata accepts `path` and the compatible `storagePath` field.
The viewer still needs permission to read the corresponding Storage object.

## Diagnostic logs

For persistence through app restarts, use `FeedbackLogStore` or an existing
application log history. Both sync and async `logsProvider` callbacks are supported.
See [persistent/custom logging](diagnostic-logs.md) for complete examples.

Connect the host application's logger explicitly. The SDK does not read global
console output. Redact tokens, passwords and personal data before recording logs.

```dart
final feedbackLogs = FeedbackLogBuffer();
// In your existing logger callback, after redaction:
feedbackLogs.add(FeedbackLogEntry(
  timestamp: DateTime.now(),
  level: FeedbackLogLevel.error,
  category: 'network',
  message: 'Request failed: timeout (request ID: safe-correlation-id)',
));
// On FeedbackCaptureBoundary:
// logsProvider: feedbackLogs.snapshot,
```

The buffer is bounded to 1000 entries and 24 hours, in memory only. For logs
across app restarts, use the host's existing persistent developer-log store as
`logsProvider`. The composer filters old/future entries and orders them by time.
Composer log snapshots truncate messages to 2000 characters, categories to 100,
and keep the newest entries within a conservative 400 KB serialized budget
(the intake limit is 500 KB). No automatic redaction or persistent collection is
promised. The backend stores a readable UTC log file with environment/version
context, and only the last 20 records as the panel preview.

For Jira, the host backend must copy that private file as `logs.txt`, retain
category/severity and add environment to the issue context. Do not put private
Firebase download tokens in Jira descriptions. The bundled Firebase functions
currently implement intake and Slack only; Jira export is not yet bundled.

## Slack notifications

The SDK must never contain a Slack webhook. The standalone console includes a
Slack settings screen and deployable services under
`feedback_console/firebase/functions`. They run in the adopting application's
Firebase project and notify Slack after a report is persisted. There is no Humm
Hub dependency. See [Slack setup](../feedback_console/doc/slack-integration.md).
Other receiving backends can implement the same pattern without Firebase.
