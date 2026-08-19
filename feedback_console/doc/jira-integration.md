# Jira integration for a self-hosted Feedback Console

The Console configuration form does not store an Atlassian API token in the
browser, Firestore or a build-time define. It sends it once, over HTTPS and with
the signed-in user's Firebase ID token, to the feedback backend in the same
Firebase project. The backend verifies the Jira site and project before saving
the token and account email in Google Secret Manager.

## Reference backend setup

The backend exposes these authenticated routes through its Cloud Functions API:

- `GET /feedback-console/jira/status`
- `POST /feedback-console/jira/configuration`
- `DELETE /feedback-console/jira/configuration`
- `POST /feedback-console/reports/{reportId}/jira-issue`

Both routes require the Firebase user document to have either `role: "admin"`
or `feedbackRole: "admin"`. The response never contains the API token.

The issue endpoint is available to an administrator and to a reviewer with
`feedbackCanCreateJiraTasks: true`. It creates one Jira **Task** per feedback
report, copies the feedback message and captured context into the description,
uploads the private screenshot as a Jira attachment, and adds a link to that
attachment in the description. The backend records the Jira key and URL on the
report to prevent duplicate task creation.

Before deploying the backend, grant its Cloud Functions service account a
custom least-privilege role with these permissions:

- `secretmanager.secrets.create`
- `secretmanager.secrets.get`
- `secretmanager.secrets.delete`
- `secretmanager.versions.add`
- `secretmanager.versions.access`

For your Firebase project, the Cloud Functions runtime service account is typically
`<PROJECT_ID>@appspot.gserviceaccount.com` (or the default compute service account).
The role is required because the first successful configuration creates two project-local secrets:

- `feedback-console-jira-api-token`
- `feedback-console-jira-account-email`

No `firebase functions:secrets:set` command is needed. The administrator
creates an Atlassian API token, opens **Jira** in the Feedback Console, and
uses **Connect Jira**. The backend verifies the site, project key and token
before it stores a new secret version.

### One-time setup checklist

1. Deploy the feedback backend in the Firebase project that owns the Console.
2. In **Google Cloud Console → IAM**, find the service account running that
   project's Cloud Functions (e.g. `<PROJECT_ID>@appspot.gserviceaccount.com`).
3. Create a custom role containing only the five Secret Manager permissions
   listed above and assign it to that service account. This is needed once per
   Firebase project, because secrets are intentionally project-local.
4. Ensure the Secret Manager API is enabled for the project.
5. Give the selected Firebase Auth user `role: "admin"` or
   `feedbackRole: "admin"` in `users/{uid}`.
6. In the Console, open **Jira**, create an Atlassian API token for an account
   that can access the chosen project, paste it once and select **Connect Jira**.

The in-product **Set up Jira integration** guide repeats these steps for an
administrator. It never asks a user to enter Google Cloud or Firebase service
account credentials into the browser.

## Connection status

The panel checks the saved token against `GET /rest/api/3/myself` and the
selected project against `GET /rest/api/3/project/{projectKey}`. It displays
only the project name, account label and connection state. A failed check does
not remove the current configuration or expose credentials.
