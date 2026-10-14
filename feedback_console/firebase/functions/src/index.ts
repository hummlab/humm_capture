import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {defineString} from "firebase-functions/params";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {HttpsError, onRequest} from "firebase-functions/v2/https";
import {manageFeedbackSlack, notifyFeedbackSlack} from "./slack.js";
import {assertFeedbackAdministrator} from "./authorization.js";

initializeApp();
export {feedbackIntake} from "./intake.js";
export {feedbackJiraApi} from "./jiraApi.js";
const consoleUrl = defineString("FEEDBACK_CONSOLE_URL");

/** Authentication is enforced here, not by possession of the public function URL. */
export const feedbackSlackApi = onRequest({region: "europe-west1", invoker: "public", timeoutSeconds: 90}, async (req, res) => {
  const origin = new URL(consoleUrl.value()).origin;
  if (req.headers.origin && req.headers.origin !== origin) {
    res.status(403).json({message: "This console origin is not allowed."});
    return;
  }
  res.set("Access-Control-Allow-Origin", origin);
  res.set("Vary", "Origin");
  res.set("Cache-Control", "no-store");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "GET, POST, DELETE");
    res.set("Access-Control-Allow-Headers", "Content-Type, X-Firebase-Auth");
    res.status(204).send();
    return;
  }
  try {
    const header = req.get("X-Firebase-Auth") ?? "";
    if (!header.startsWith("Bearer ")) throw new HttpsError("unauthenticated", "Sign in to manage Slack.");
    const token = await getAuth().verifyIdToken(header.slice(7), true).catch(() => {
      throw new HttpsError("unauthenticated", "Sign in again to manage Slack.");
    });
    const user = (await getFirestore().doc(`users/${token.uid}`).get()).data();
    assertFeedbackAdministrator(user);
    if ((req.rawBody?.length ?? 0) > 4096) throw new HttpsError("invalid-argument", "Request is too large.");
    const action = req.method === "GET" && req.path === "/feedback-console/slack/status" ? "status" :
      req.method === "POST" && req.path === "/feedback-console/slack/test" ? "test" :
      req.method === "POST" && req.path === "/feedback-console/slack/settings" ? "settings" :
      req.method === "POST" && req.path === "/feedback-console/slack/configuration" ? "connect" :
      req.method === "DELETE" && req.path === "/feedback-console/slack/configuration" ? "disconnect" : null;
    if (!action) { res.status(404).json({message: "Unknown Slack endpoint."}); return; }
    res.json(await manageFeedbackSlack({action, webhook: req.body?.webhook, messageSettings: req.body?.messageSettings}));
  } catch (error) {
    const statuses: Record<string, number> = {"unauthenticated": 401, "permission-denied": 403, "invalid-argument": 400, "failed-precondition": 412};
    const status = error instanceof HttpsError ? (statuses[error.code] ?? 503) : 503;
    // Never return or log raw exceptions: network failures can include the webhook.
    res.status(status).json({message: error instanceof HttpsError ? error.message : "Could not complete the Slack request."});
  }
});

export const feedbackSlackNotification = onDocumentCreated({
  document: "feedbackReports/{reportId}", region: "europe-west1", retry: true,
}, async (event) => notifyFeedbackSlack(event.params.reportId, consoleUrl.value()));
