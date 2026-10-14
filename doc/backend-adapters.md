# Backend adapter notes

`humm_capture` only captures and serializes feedback. An application's own
server must accept reports, validate the caller and persist the data.

## Firebase intake

For a Firebase-hosted application, expose an authenticated Cloud Function or
Cloud Run endpoint. The endpoint should:

1. verify the Firebase ID token or another application-owned session;
2. enforce an application-specific payload, screenshot and attachment-size limit;
3. store the screenshot and any selected media using Firebase Admin rather than client Storage rules;
4. create a feedback record with message, support context, storage path and
   lifecycle status;
5. return only a report reference to the SDK.

Preserve `context.environment` when provided. Accept only `dev`, `stage`, or
`prod`; omit it for old clients rather than guessing. If your intake has a
context allowlist, add this field explicitly. Store additional media under
`feedback/{reportId}/...` with `path`, `fileName`, `mimeType`, and `sizeBytes`
metadata so the bundled console and Storage rules can read it.

For diagnostics, store the full formatted file at `logsPath`, the total count
at `logCount`, and a bounded preview (last 20 entries) at `logs`. Preserve each
entry's timestamp, level, category and message. Older records containing only
`logsPath` still expose their downloadable file in the console.

The optional [Slack services](../feedback_console/doc/slack-integration.md)
run after a standalone `feedbackReports` document is created. They do not
replace the authenticated intake and are never called by the mobile SDK.

The web console reads this record through its own Firebase-authenticated
administrator session. It must not share a Console credential, Firestore write
permission or a Firebase Admin credential with the mobile SDK.

The [self-hosted Feedback Console guide](self-hosted-feedback-console.md)
defines the exact Firestore, Storage, reviewer-role and Hosting contract used
by the bundled `feedback_console` application.

## Lifecycle

The initial console contract uses `new`, `in_review`, `resolved` and `rejected`. The host
may add Jira issue metadata or a project-specific lifecycle without changing
the SDK's portable payload.
