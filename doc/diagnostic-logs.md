# Optional persistent diagnostics

Humm Capture supports either its own file store, an existing host log history,
or both. It does not require Firebase and does not intercept `print()` output.

## SDK-owned storage (Android/iOS)

Before constructing the feedback boundary, open a dedicated file inside the
application's private support directory. Obtain that directory using the host's
existing platform/path integration (for example its existing `path_provider`).
Do not use shared storage, a gallery directory, or an arbitrary user document.
No new path dependency is added to the core SDK.

```dart
final captureLogs = await FeedbackLogStore.open(
  filePath: '${appSupportDirectory.path}/capture-diagnostics.json',
  // Required: return a safe record or null to discard it.
  redact: redactDiagnosticEntry,
);

// Your logger forwards an already structured event. Await writes or explicitly
// handle their errors; do not leave unhandled futures in a logger callback.
await captureLogs.add(FeedbackLogEntry(
  timestamp: DateTime.now(),
  level: FeedbackLogLevel.error,
  category: 'network',
  message: 'Request timed out; correlation ID: safe-id',
));

FeedbackCaptureBoundary(
  reporter: reporter,
  logsProvider: captureLogs.snapshot,
  child: app,
);
```

Opening the store reloads/prunes previous records. Each write is serialized and
replaces a temporary file after flushing. Retention is 24 hours, at most 1000
records and a conservative 400 KB payload budget. Message/category limits match
intake limits. Snapshotting waits for pending writes; write errors reach callers.
A corrupt file reports an error instead of silently destroying existing data.

Use one store instance per owned file. Multi-isolate/process writers are not
supported. Call `await captureLogs.clear()` on sign-out/account switching and
`await captureLogs.flush()` when explicitly shutting down the store. Unexpected
process termination before an awaited write completes can lose that event.
Pruning occurs on open/write/snapshot, not via an always-running background job.
The store is plaintext, not an encrypted vault. Credentials, personal data,
request bodies and raw authorization headers must not be recorded. The SDK
cannot reliably infer which custom fields are sensitive; host redaction is mandatory.

## Bring your own logs

Existing synchronous providers still work. An async database/file-backed store
can also be provided without migrating to the SDK store:

```dart
logsProvider: () async {
  final existing = await developerLogs.readLast24Hours();
  return existing.map(toRedactedFeedbackLogEntry).toList();
},
```

To combine sources, return both lists from the callback:

```dart
logsProvider: () async => [
  ...await captureLogs.snapshot(),
  ...await existingLogHistory.feedbackEntries(),
],
```

The composer normalizes time/order and limits after collection. Sources should
not overlap unless duplicate entries are desired. A failed provider shows the
composer preparation error and leaves the report unsent; retry after correcting
the storage/provider failure. Web hosts use their own provider or the in-memory
`FeedbackLogBuffer`; SDK file storage is unsupported in browsers.

## Delivery, console and Jira

`HttpFeedbackReporter` includes typed logs in the authenticated report payload.
The bundled intake saves a readable private `logs.txt` with environment, version,
build, UTC times, severity, category and multiline messages. Firestore stores
the total count and a preview of the last 20 records. The panel displays the
latest preview entries and opens the authorized file. No log files go to Slack.

Jira export is a separate server integration: fetch `logsPath` using backend IAM,
upload bytes as a Jira attachment, and link that Jira attachment, not a private
Firebase token URL. The bundled backend exposes authenticated Jira integration/export routes.
Each installation still needs its own Jira configuration and live export
acceptance; a successful feedback upload does not prove Jira delivery.

## Manual acceptance

Use a real device: record a safe event, restart, send feedback and download the
file; check expiry after 24 hours, account switching, disabled logging, own-log
provider, write failures, size limits and absence of secrets. Validate the
consumer's platform directory and logger integration separately. Unit tests do
not prove OS/device retention or Jira delivery.


## Android process logs

`collectAndroidFeedbackLogs(redact: redactDiagnosticEntry)` reads epoch-format
logcat records for the current Android app PID. It runs on the device itself,
without ADB, root or READ_LOGS. It does not read other apps or guarantee 24-hour
OS ring-buffer history; combine it with FeedbackLogStore for persisted app logs.
An unsupported platform, timeout, size overflow or empty OS result raises a
clear error rather than reporting fabricated successful log capture. Apply the
required redactor before upload; production consumers must remove credentials
and personal data. The example keeps only its safe runtime-check marker for
acceptance, rather than uploading arbitrary framework logs. iOS and Web retain
the existing host logger/store integration; this API is Android-only.
