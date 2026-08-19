# Feedback Console

`feedback_console` is a standalone Flutter Web panel for any application that
uses `humm_capture`. It is intentionally separate from the SDK: an adopting
project owns its Firebase project, users, access policy, intake endpoint and
hosting.

## What a new project needs

The integration has four independent parts:

1. Add `humm_capture` to the Flutter application and send reports to that
   application's authenticated intake endpoint.
2. Deploy the intake endpoint in the same Firebase project. It writes an image
   to `feedback/{reportId}.png` and a Firestore document at
   `feedbackReports/{reportId}`.
3. Build and host this console with that Firebase project's **Web app**
   configuration.
4. Give selected Firebase Auth users the `reviewer` or `admin` feedback role.

## Optional Jira integration

For a Firebase-backed console, an administrator can configure Jira through the
**Jira** section of the panel. The token is sent once over an authenticated HTTPS
request to the project's feedback backend. The backend verifies the selected
Atlassian Cloud site and project before storing the email and token in Google
Secret Manager. They must never be written to Firestore, build configuration or
browser storage.

The backend exposes these protected endpoints:

| Endpoint | Purpose |
| --- | --- |
| `GET /feedback-console/jira/status` | Checks the stored credentials against Jira and returns only connection metadata. |
| `POST /feedback-console/jira/configuration` | Verifies a new Jira configuration and stores its credentials in Secret Manager. |
| `DELETE /feedback-console/jira/configuration` | Removes the saved Jira configuration and its two Secret Manager secrets. |
| `POST /feedback-console/reports/{reportId}/jira-issue` | Creates one Jira task from a feedback report. The request carries an editable short `summary`; the full feedback and screenshot are added to the Jira Description. |

Only a user with `role: "admin"` or `feedbackRole: "admin"` can use either
endpoint. Its Cloud Functions service account needs permission to create,
write and read the two Jira secrets in the target Google Cloud project.

This keeps tester capture, the backend and the review panel independently
replaceable. A project can use its own backend instead of Firebase; only the
panel's Firestore contract changes in that case.

## First local run

Copy the example configuration; this local file is ignored by Git:

```bash
cd feedback_console
cp config/feedback_console.example.json config/feedback_console.json
```

Fill the values from **Firebase Console → Project settings → Your apps → Web
app**. They identify the Firebase project and are not secrets. Authentication,
Firestore rules and Storage rules still enforce access.

Then run:

```bash
fvm flutter pub get
fvm flutter run -d chrome --dart-define-from-file=config/feedback_console.json
```

## Firebase data contract

The initial console reads only these paths:

| Path | Owner | Purpose |
| --- | --- | --- |
| `feedbackReports/{reportId}` | Server-side intake | One submitted report with `message`, `status`, `context`, `screenshotPath` and timestamps. The Console displays app version, platform, OS version, screen, locale and device metadata when supplied. |
| `feedbackReports/{reportId}/statusEvents/{eventId}` | Signed-in reviewer | Immutable history of status changes. |
| `users/{uid}` | Existing application user directory | `email`, optional `displayName`, and `feedbackRole`. |
| `feedback/{reportId}.png` | Server-side intake | Annotated screenshot. |

Administrators can permanently delete a report from its details view. This removes both the Firestore document and its private screenshot; deploy the supplied Firestore and Storage rules together for that action.

The console understands four lifecycle values: `new`, `in_review`, `resolved`,
and `rejected`.

For the first administrator, create or update the existing `users/<uid>`
document from a trusted server-side tool and set `feedbackRole: "admin"`.
Administrators can then grant or remove the `reviewer` role through the
**Access** screen. They can separately allow an existing reviewer to create
Jira tasks with `feedbackCanCreateJiraTasks: true`. Do not let an
unauthenticated client assign itself a role.

## Rules template

`firebase/firestore.rules` and `firebase/storage.rules` are secure starting
points for this exact contract. Merge them into the target Firebase project;
they are not deployed automatically because each project can have additional
collections and existing authorization rules.

The report intake must use the Firebase Admin SDK (or an equally trusted
server). Client writes to `feedbackReports` and `feedback/` remain denied.
The service account used by the intake needs write permission to the target
Storage bucket.

## Build and deploy

Build with the same local configuration:

```bash
fvm flutter build web --release --dart-define-from-file=config/feedback_console.json
fvm dart run tool/prepare_hosting_build.dart
```

Firebase Hosting serves a directory under the target Firebase repository. Copy
only the generated files to an ignored deployment directory in that repository
and deploy that Hosting target:

```bash
rsync -a --delete feedback_console/build/web/ ../your-app/feedback_console/build/web/
cd ../your-app
firebase deploy --only hosting:feedback
```

The source of the console remains in this repository. The target project gets
no Humm Hub dependency and does not need a bespoke Flutter feedback panel.
