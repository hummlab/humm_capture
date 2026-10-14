# Jira integration for a self-hosted Feedback Console

The bundled `firebase/functions` backend now exports `feedbackJiraApi`.
The mobile application needs no Jira adapter or credentials. This implementation
is validated by local tests, not yet by a live Jira export on the test project.

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

Configuration and status routes require the Firebase user document to have either `role: "admin"`
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

Use an Atlassian Cloud site (`https://your-team.atlassian.net`) and an **unscoped**
API token for this first implementation. Scoped tokens using the `api.atlassian.com`
gateway, OAuth and Jira Data Center are not supported. Credentials are sent only
to the verified site; redirects are not followed.

No `firebase functions:secrets:set` command is needed. The administrator
creates an Atlassian API token, opens **Jira** in the Feedback Console, and
uses **Connect Jira**. The backend verifies the site, project key and token
before it stores a new secret version.

Exported descriptions use Jira ADF headings for Description, Report details and
Attachments, with bold human-readable field labels and attachment links. Tester
line breaks are preserved. Changes to this format apply to newly exported tasks;
existing Jira descriptions are not automatically overwritten.

### One-time setup checklist

1. From `feedback_console/firebase`, deploy the bundled backend and rules:

   ```sh
   firebase deploy --only functions,firestore:rules,storage --project YOUR_PROJECT_ID
   ```

   Supply the same project-local environment parameters as intake/Slack, including
   `FEEDBACK_STORAGE_BUCKET` and `FEEDBACK_CONSOLE_URL`. Set the panel's
   `FEEDBACK_FUNCTIONS_BASE_URL` to
   `https://europe-west1-YOUR_PROJECT_ID.cloudfunctions.net/feedbackJiraApi`,
   rebuild it and deploy Hosting. Keep `FEEDBACK_SLACK_FUNCTIONS_BASE_URL`
   pointed at `feedbackSlackApi` when Slack is used.
2. In **Google Cloud Console → IAM**, find the service account running that
   project's Cloud Functions (e.g. `<PROJECT_ID>@appspot.gserviceaccount.com`).
3. Create a custom role containing only the five Secret Manager permissions
   listed above and assign it to that service account. This is needed once per
   Firebase project, because secrets are intentionally project-local.
4. Ensure the Secret Manager API is enabled for the project.
   For restricted IAM, pre-create the two Jira secrets listed above and grant
   version access/add and secret delete directly on those secrets to the runtime
   service account. This avoids granting access to unrelated secrets; creation
   permission must remain project-level. Verify saving the connection in the
   panel, not just the presence of an IAM binding.
5. Give the selected Firebase Auth user `role: "admin"` or
   `feedbackRole: "admin"` in `users/{uid}`.
6. In the Console, open **Jira**, create an Atlassian API token for an account
   that can access the chosen project, paste it once and select **Connect Jira**.

The Jira account needs Browse projects, Create issues, Create attachments and
Edit issues. Enable Jira attachments and provide a non-subtask issue type named
`Task` or its Polish name `Zadanie`. The backend stores the selected type ID;
epics and subtasks are excluded. Other custom type names are not yet supported.
Projects requiring additional custom fields on creation need additional
configuration and are not supported by this minimal form yet. Integration setup
does not create a Jira issue. Do not use a personal account with unnecessarily
broad project permissions.

The function runtime needs bucket-scoped `storage.objects.get` to read private
files; never make the bucket public. Logs and media exported to Jira become
available to users with access to that Jira issue, so redact logs before sending.

Administrators can enable `feedbackCanCreateJiraTasks` for existing reviewers in
the Access panel. A boolean alone does not grant access: the backend also requires
the reviewer role. Deploy the updated Firestore rules to allow admins to change
this flag. Configuration remains admin-only.

## Export results and duplicate protection

- One report creates one task. The backend records `jiraIssueKey`/`jiraIssueUrl`
  before uploading files and changes the report status to `in_review` with an
  actor event.
- The tester description is preserved in Jira Description. A short editable
  title is supplied separately. Environment/version/build are included in the
  description; no private Firebase download-token URL is copied to Jira.
- Screenshot and `logs.txt` are always exported when available. Additional
  selected media are exported only when the panel checkbox is enabled.
- Attachment links at the end of Description point to Jira's own attachments.
- Failed uploads produce a visible warning while retaining the created task.
  Automatic attachment retry is not implemented; inspect the task and attach
  missing files manually. Do not create another task.
- If an external create times out, `jiraExportState: uncertain` blocks automatic
  retries. Search Jira for the report ID in Description before administrator
  recovery. Never clear this state without checking for an existing task.
- Removing an integration disables new exports and removes its project-local
  secrets; it does not delete existing Jira tasks.

The in-product **Set up Jira integration** guide repeats these steps for an
administrator. It never asks a user to enter Google Cloud or Firebase service
account credentials into the browser.

## Connection status

The panel checks the saved token against `GET /rest/api/3/myself` and the
selected project against `GET /rest/api/3/project/{projectKey}`. It displays
only the project name, account label and connection state. A failed check does
not remove the current configuration or expose credentials.
