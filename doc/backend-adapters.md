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
