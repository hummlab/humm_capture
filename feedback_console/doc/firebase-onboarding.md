# Firebase onboarding checklist

This is the deployment checklist for a new application using `humm_capture`
and the standalone Feedback Console. No Humm Hub or GateFlow backend is required.
This guide is being validated against a real fresh Firebase project. Items marked
**pending verification** are not yet proven end to end.

## 1. Project and accounts

- Create/select the customer's Firebase project and enable billing for functions.
- Create Firestore, Storage, a Web app for the console and the relevant mobile apps.
- Enable Firebase Auth email/password for the console.
- Create the first administrator in Firebase Auth. From a trusted administrative
  tool, create `users/<Auth UID>` with `feedbackRole: "admin"`.
- Intake separately requires `feedbackCanSubmit: true` on the authenticated
  submitter's user document. Signing in alone does not grant submission access.
- Never ship an administrator password, Slack webhook or Jira token in the SDK,
  browser build, Git repository or chat. Firebase app configuration is not an
  authorization mechanism.

## 2. Configuration

Use ignored local `config/feedback_console.json` for the Web app configuration.
Set `FEEDBACK_SLACK_FUNCTIONS_BASE_URL` to the project's `feedbackSlackApi` URL.
Jira is optional; do not point it at another application's backend.

The functions' ignored `.env.<project-id>` contains non-secret parameters:
`FEEDBACK_CONSOLE_URL`, `FEEDBACK_APPLICATION_NAME`,
`FEEDBACK_APPLICATION_ID`, and `FEEDBACK_STORAGE_BUCKET`.
Slack credentials belong in Secret Manager through the administrator API.

## 3. Rules and runtime permissions

Review and deploy `firebase/firestore.rules` and `firebase/storage.rules`.
For an existing project, merge these rules; do not overwrite unrelated rules.
Clients cannot create reports or upload feedback objects directly under these
templates. The authenticated intake verifies submission permission and uses
Admin SDK. Admin SDK bypasses Firebase rules but still requires Google Cloud IAM.

Identify the actual build and runtime service accounts before assigning roles.
Do not assume the legacy `<project-number>@cloudbuild.gserviceaccount.com`
account is used: new projects can build with the Compute default account.
Grant only the required permissions, not Owner or Editor.
The intake runtime needs Firebase Auth lookup and Firestore access, plus object
access restricted to the feedback bucket. Secret Manager permissions are a
separate requirement for enabling Slack; do not grant them to mobile clients.

### Storage rules reading Firestore roles

These Storage rules use `firestore.get()` to read `users/<Auth UID>`.
In a fresh project, the Firebase Storage service agent also needs
`roles/firebaserules.firestoreServiceAgent` on that project. Its existing
`roles/firebasestorage.serviceAgent` role does not replace this requirement.
Without cross-service access, a valid administrator can receive HTTP 403 for
screenshots, attachments and logs even though intake successfully uploaded them.

After reviewing the scope with the project owner:

```bash
gcloud projects describe YOUR_PROJECT_ID --format='value(projectNumber)'
# Replace YOUR_PROJECT_NUMBER with the number returned above.
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member=serviceAccount:service-YOUR_PROJECT_NUMBER@gcp-sa-firebasestorage.iam.gserviceaccount.com \
  --role=roles/firebaserules.firestoreServiceAgent \
  --condition=None
```

This grants the service agent cross-service Firestore access for rule evaluation;
it does not make Storage public or bypass the reviewer's Firebase rules. Allow
IAM changes to propagate, then verify authenticated downloads and unauthenticated
rejection. See [Firebase cross-service rules setup](https://firebase.google.com/docs/rules/manage-deploy).

### Web image previews and bucket CORS

Flutter Web image rendering also requires CORS on downloaded image responses.
A working authenticated download does not prove browser rendering works.
Copy `firebase/storage-cors.example.json` to an ignored local file, replace the
placeholder origin with the actual console HTTPS origin, then apply:

```bash
gcloud storage buckets update gs://YOUR_STORAGE_BUCKET --cors-file=YOUR_LOCAL_CORS_FILE.json
```

Preserve any existing bucket CORS entries used by other applications. Allow only
the required console origins and GET/HEAD; do not use `*` as a default. CORS does
not grant file access or replace Auth/rules. Verify the image response includes
`Access-Control-Allow-Origin` for the console and visually check the thumbnail
and details. The test bucket originally had no CORS configuration, and its image
response lacked that header; a console-origin-only configuration was applied.

## 4. Build and deploy

From `feedback_console`:

```bash
fvm flutter pub get
fvm flutter build web --release --dart-define-from-file=config/feedback_console.json
mkdir -p firebase/.hosting-build
rsync -a build/web/ firebase/.hosting-build/
cd firebase
firebase deploy --only firestore:rules,storage,functions,hosting --project YOUR_PROJECT_ID
```

The current hosting configuration serves `firebase/.hosting-build`, not
`build/web` outside the Firebase configuration directory. The optional
`tool/prepare_hosting_build.dart` cache-cleanup helper currently rejects the
Flutter 3.44.3 bootstrap shape; do not include it as a mandatory working step
until its compatibility is tested.

The CLI may require confirmation for retry-enabled Slack notifications. Retries
are billed. Inspect the application's attempt limits and deduplication behavior;
do not interpret them as a guarantee of exactly-once Slack delivery.

HTTP functions must be reachable by the SDK/browser while application code
checks Firebase identity and authorization. Cloud Run invoker access and Firebase
Auth are separate layers. An organization policy can block public invoker setup;
do not bypass it or open access without the project owner's approval.

## 5. Real acceptance test (pending verification)

- Install the test app on a physical Android device with the real reporter.
- Submit feedback with dev/stage/prod context and an annotated screenshot.
- Attach a gallery image and a video; verify upload and panel metadata.
- Sign in to the hosted console; check image preview and video file opening
  without an embedded player, logs, status changes and deletion.
- Verify unauthorized users cannot submit or review reports.
- Connect a real Slack webhook, test it, then submit a report and check delivery.
- Test failure/retry behavior without exposing credentials or creating unbounded
  retries. Verify cleanup and permissions independently of successful builds.

## Fresh-project findings: 2026-10-01

In `test-capture-feedback`, builds used the Compute default service account,
while `roles/cloudbuild.builds.builder` was initially assigned only to the legacy
Cloud Build account. With owner approval, assigning the build role to the actual
build account removed that build failure. This is a project-specific finding,
not a requirement to grant the role to every default service account.

`feedbackSlackNotification` then deployed successfully. The deploy of
`feedbackIntake` and `feedbackSlackApi` still failed when setting HTTP invoker
IAM policy. The exact cause and fix remain **pending verification**. Hosting,
runtime permissions, administrator bootstrap and full device-to-Slack flow are
not yet confirmed by this deployment.

Deploy logs identify `FAILED_PRECONDITION` when adding `allUsers` as Cloud Run
invoker: Google reports that members are outside the permitted customer,
consistent with an organization policy restriction. Investigating the effective
policy requires the currently disabled Organization Policy API. Do not disable
organization restrictions or bypass invoker checks as an automatic workaround;
obtain explicit approval for any scoped exception first.

For this test project, the owner explicitly approved a project-level override
of `iam.allowedPolicyMemberDomains` with `allowAll: true`. The override was
applied only to `test-capture-feedback`, not the parent organization. It permits
IAM members outside the organization throughout this project; it does not itself
grant data access. This is a security-relevant exception, not a mandatory SDK
installation step. Endpoint deployment and authorization tests are still pending.

After policy propagation, invoker bindings succeeded for both HTTP services.
Real unauthenticated HTTP requests returned application JSON with status 401
from intake and Slack API. This confirms reachability and rejection without
credentials, not successful authorized delivery. The runtime Compute account
currently has build, Eventarc receiver and Run invoker roles only; its Auth,
Firestore and bucket permissions need provisioning before authorized intake tests.

The owner-approved runtime roles are now provisioned: `roles/firebaseauth.viewer`
and `roles/datastore.user` on the test project, and `roles/storage.objectAdmin`
only on its feedback bucket. The example now uses Firebase Auth and real HTTP
intake, with `APP_ENV` selected at build time. Authorized device submission is
still unverified: first-admin bootstrap using local credentials failed because
Identity Toolkit requires an explicit quota project. Do not treat installed roles
or successful analysis as proof of completed onboarding.

First administrator bootstrap succeeded using a configured gcloud access token
and an explicit `x-goog-user-project` quota header. The test administrator can
sign in (HTTP 200). An authenticated empty intake request returns HTTP 400 after
checking submission access; unauthenticated requests return 401. Actual media
upload and panel review remain pending device testing.

### Real device result and remaining checks

A physical Samsung submitted a real dev report with an annotated screenshot,
a gallery image and a video. The report appeared in Firestore and in the hosted
console. Four objects exist in Storage: screenshot, image, video and logs.
The current example's log payload is synthetic, so this does not yet validate
collection of real application logs over the previous 24 hours.

Authenticated console reads returned HTTP 403. Inspection found that the Storage
service agent lacked `roles/firebaserules.firestoreServiceAgent`; this role was
added with owner approval. After propagation, authenticated downloads returned
HTTP 200 for all four files with their expected byte counts. An unauthenticated
download returned HTTP 403. Backend tests: 29 passed. Separate stage/prod builds,
status changes, deletion and live Slack
delivery also remain pending. Do not label the entire onboarding flow verified
based only on successful upload.

After applying the console-origin-only bucket CORS configuration, visual review
confirmed the list screenshot, details screenshot with annotation and attached
image thumbnail render in the hosted console. Video remains a file attachment,
not an embedded player, as intended.

### Slack provisioning progress

Secret Manager API was enabled in the test project. Two custom roles separate
`secretmanager.secrets.create` (project scope, required for creation) from
`secretmanager.secrets.delete`, `secretmanager.versions.add` and
`secretmanager.versions.access`. The latter binding is conditioned on the
`feedback-console-slack` secret resource prefix, including its versions, rather
than all project secrets. Both are granted to the actual function runtime account.
Creation permission still allows creating secret resources in this test project;
it does not provide read access to unrelated secrets.

A Slack app named Capture Feedback was created in JS1914 with Incoming Webhooks
enabled. Only the private `feedback` channel was selected. The supplied channel
link pointed to `pomysły` and was not used as the notification destination.
The user completed final Slack authorization and supplied the webhook privately
for configuration. The authenticated administrator API connected successfully
(HTTP 200), stored the webhook in Secret Manager and sent its connection test.
The separate test endpoint also returned 200. Both messages were visually
confirmed in the native Slack application in JS1914 / `feedback`.

A new report submitted through the real authenticated HTTP intake returned 201.
Its Firestore creation triggered an automatic Slack notification, visually
confirmed with app name, dev label, Android/version/build, description and the
test console link. This verifies the live backend notification path; it is not
an additional device-driven submission or a stage/prod build test. Those checks,
real 24-hour logs and deletion still remain pending.

Never paste webhook URLs into documentation, source control or screenshots.
If a webhook is disclosed in chat, rotate it after testing and reconnect through
the panel. The API does not return the stored webhook.
# Slack report deep-link acceptance test (2026-10-01)

Validated on `test-capture-feedback` and JS1914's private `feedback` channel.
Authenticated intake returned 201; the notification contained its title,
description, environment/version/build, and a direct `Open report` hyperlink.
Clicking it in native Slack opened the default Chrome profile, showed sign-in,
and automatically opened the matching report after login. No screenshot URL
was shared with Slack. The test used HTTP intake, not a new mobile submission.

Use a normal Slack mrkdwn hyperlink, not an interactive button: the initial
button produced an action error in this webhook-only app. No Slack interaction
endpoint or additional bot permissions are required for the hyperlink.

## Persistent diagnostics device check (2026-10-01)

Installed the updated dev example on the physical Samsung SM-A536B. Restarted
the application process and submitted a report through the mobile composer.
The hosted console showed three diagnostic entries: both process starts and
the application's custom in-memory lifecycle entry. This verifies persisted
logs surviving restart and merging with a host-supplied logger.

The example uses `path_provider` for its private support directory; this
dependency is not added to the SDK. Applications must supply a private path
and redact sensitive data before storage. Retention boundary tests cover
24 hours; this device check did not run continuously for 24 hours.

Clicking Open log file navigated to Storage, but the test Chrome profile
blocked the destination with `ERR_BLOCKED_BY_CLIENT`. Download acceptance
remains unverified; do not bypass browser security restrictions to test it.
