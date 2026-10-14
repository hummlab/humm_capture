# Self-hosted Slack notifications

Everything here runs in **your application's Firebase project**. No Humm Hub
endpoint, account, secret, or database is used. Slack is optional; the mobile
SDK still sends only feedback to your chosen intake endpoint.

## Backend setup

The bundled services live in `firebase/functions` and expect the existing
console contract: `users/{uid}` and `feedbackReports/{reportId}`. They do not
replace your intake or Jira backend. The functions use Node 22 and Firebase
Admin. Enable the Secret Manager API in your Google Cloud project.

Give the runtime service account a dedicated custom role with these permissions:

- `secretmanager.secrets.create`
- `secretmanager.secrets.delete`
- `secretmanager.versions.add`
- `secretmanager.versions.access`

Secret creation needs a project-level grant. Scope the other permissions to
`feedback-console-slack` when your IAM setup supports that arrangement. Never
grant Owner or expose payload access to console users. If the function uses a
dedicated service account, also grant its required Firestore access; this code
does not require Storage access. IAM grants and APIs are not configured by the
SDK or the console UI. Repeat this setup in each adopting Firebase project.

Install, verify, and only deploy when ready:

```bash
cd feedback_console/firebase/functions
npm ci --legacy-peer-deps
npm run build
npm test
cd ..
firebase deploy --project YOUR_PROJECT_ID --only functions:feedbackSlackApi,functions:feedbackSlackNotification
```

The legacy peer-dependency flag avoids an npm peer-resolution failure and
irrelevant GraphQL integration peers; these services use neither GraphQL nor
Apollo. Commit/use the included lockfile for reproducible installation.
The lockfile overrides the legacy `gaxios` UUID dependency to the patched
CommonJS-compatible UUID 11 series; the Gaxios v4 UUID API remains unchanged.
Run the backend tests and dependency audit when upgrading it.

During deployment set `FEEDBACK_CONSOLE_URL` to the actual HTTPS URL of your
console, e.g. `https://your-feedback.web.app`. It determines both the allowed
browser origin and the link in notifications. For local emulator testing you
can use `http://localhost:4182`; never set a production console URL to localhost.
The example `firebase.json` deploys only these services. If your Firebase project
already has functions, merge this codebase into its configuration rather than
overwriting the project's existing Firebase configuration.

Build your standalone console with:

```json
{
  "FEEDBACK_SLACK_FUNCTIONS_BASE_URL": "https://europe-west1-YOUR_PROJECT_ID.cloudfunctions.net/feedbackSlackApi"
}
```

This is a service URL, not a secret. Existing `FEEDBACK_FUNCTIONS_BASE_URL`
continues to serve Jira. If your own router hosts the Slack paths too, you may
omit the separate Slack URL and the console will use that existing base URL.

The authenticated HTTP contract (relative to that base URL) is:

| Method and path | Purpose |
| --- | --- |
| `GET /feedback-console/slack/status` | Safe configuration and last-delivery metadata; never the webhook. |
| `POST /feedback-console/slack/configuration` | JSON `{ "webhook": "https://hooks.slack.com/services/..." }`; test and store the secret. |
| `POST /feedback-console/slack/test` | Send a test using the stored webhook. |
| `DELETE /feedback-console/slack/configuration` | Delete the secret and disconnect. |

Every request carries `X-Firebase-Auth: Bearer <Firebase ID token>`. Responses
are JSON with `connected` and optional delivery metadata, or a safe `message`
with a non-success status. Tokens must not be passed in URLs.

## Configure in the standalone panel

1. Sign in as a user whose trusted `users/{uid}` document has
   `feedbackRole: "admin"` (or the existing application `role: "admin"`).
2. Open **Slack** in the standalone console.
3. Open https://api.slack.com/apps and create an app for the destination workspace.
4. Enable **Incoming Webhooks**, choose **Add New Webhook to Workspace**, choose
   the channel, and authorize.
5. Copy the generated `https://hooks.slack.com/services/...` URL into the panel.
   Treat it as a password. Connect sends a test message; **Send test** checks it
   again. Connection status means a configuration was verified, not a continuous
   health probe. Remove the integration before selecting another channel.

Only administrators see configuration UI and the backend verifies the role
again for every request. Reviewers cannot configure Slack even if they call the
URL manually. The public Cloud Function invoker allows requests to reach the
application's Firebase-token verification; it does **not** grant administrative
access. The ID token is verified including revocation. CORS allows only your
configured console origin and is not a substitute for authentication.

The webhook is stored only in Google Secret Manager. Firestore
`feedbackIntegrations/slack` holds safe metadata: connected state, update time,
last delivery status, and last delivery time. Direct client access is denied.
The API never returns the webhook. It is not stored in browser persistence,
mobile builds, Dart defines, or logs. Only standard Slack Cloud webhooks are
supported; GovSlack destinations are not currently supported.

## Delivery and privacy

Administrators can edit **Message settings** in the console: feedback/bug
fallback headings, report link label, and whether the tester description is
included. Defaults are English. Custom report titles take priority over fallback
headings. Settings are saved through authenticated `POST /feedback-console/slack/settings`
and apply to new notifications, not existing Slack messages. Webhook credentials
remain read-only; reconnecting is not required to change message text.

Notifications use Block Kit: an optional SDK report `title` (up to 150 characters),
a kind-based fallback (`New feedback` or `New bug`), application/environment/version
context, and the description only when supplied. Text is literal, not Slack markup.
The `Open report` link includes `?feedback=<reportId>`; the console opens the
matching report after authentication and authorized data loading.
It is a normal hyperlink, so Slack Interactivity configuration is not required.

Screenshots remain private. An Incoming Webhook cannot upload them. Slack image
blocks require a publicly accessible image URL or an existing Slack file. Do not
make Firebase screenshots public or expose download tokens for notifications.
A future private-image option requires a Slack bot token with `files:write`,
channel access, and a backend file upload; this is not enabled by this integration.

Creation of `feedbackReports/{reportId}` triggers the notification independently
of intake. It includes application, dev/stage/prod, platform/version/build,
a bounded description, and a console link. No private image URLs, media bytes,
log files, or Firebase tokens are sent. Channel members can see descriptions,
so choose a private channel when reports contain sensitive information.

Existing reports are not backfilled. Concurrent delivery uses a transactional
lease. Transient failures retry up to five attempts; invalid/revoked webhooks
and missing permissions stop. `slackDeliveryStatus`, `slackDeliveryAttempts`,
`slackLeaseUntil`, and `slackNotifiedAt` on the report describe delivery.
Incoming webhooks offer at-least-once, not exactly-once delivery: a timeout
after Slack accepted the message can result in a duplicate on retry.

## Verification before deployment

Unit tests use mocked Firebase/fetch and never send messages to Slack. Manually
verify admin/reviewer access, connect/test/remove/reconnect, denied Secret
Manager permissions, one new report in each environment, Slack downtime, and
that no webhook appears in API responses or logs. Running a local Functions
emulator with real credentials/webhook can still send real Slack messages.

References: [Slack Incoming Webhooks](https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks/)
and [Secret Manager IAM](https://cloud.google.com/secret-manager/docs/access-control).
