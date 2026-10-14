import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import {defineString} from "firebase-functions/params";
import {HttpsError, onRequest} from "firebase-functions/v2/https";
import {assertFeedbackAdministrator} from "./authorization.js";
import {assertJiraCreator, createJiraIssue, manageJira} from "./jira.js";

const consoleUrl = defineString("FEEDBACK_CONSOLE_URL");
export const feedbackJiraApi = onRequest({region: "europe-west1", invoker: "public", timeoutSeconds: 300, memory: "512MiB"}, async (req, res) => {
  const origin = new URL(consoleUrl.value()).origin;
  if (req.headers.origin && req.headers.origin !== origin) { res.status(403).json({message: "Console origin not allowed."}); return; }
  res.set("Access-Control-Allow-Origin", origin).set("Vary", "Origin").set("Cache-Control", "no-store");
  if (req.method === "OPTIONS") {
    res.set("Access-Control-Allow-Methods", "GET, POST, DELETE").set("Access-Control-Allow-Headers", "Content-Type, X-Firebase-Auth");
    res.status(204).send(); return;
  }
  try {
    const header = req.get("X-Firebase-Auth") ?? "";
    if (!header.startsWith("Bearer ")) throw new HttpsError("unauthenticated", "Sign in to use Jira.");
    const token = await getAuth().verifyIdToken(header.slice(7), true).catch(() => { throw new HttpsError("unauthenticated", "Sign in again."); });
    const user = (await getFirestore().doc(`users/${token.uid}`).get()).data();
    if ((req.rawBody?.length ?? 0) > 8192) throw new HttpsError("invalid-argument", "Request is too large.");
    const reportRoute = /^\/feedback-console\/reports\/([A-Za-z0-9_-]{1,128})\/jira-issue$/.exec(req.path);
    if (req.method === "POST" && reportRoute) {
      assertJiraCreator(user);
      res.json(await createJiraIssue(reportRoute[1], req.body ?? {}, token.uid)); return;
    }
    assertFeedbackAdministrator(user);
    const action = req.method === "GET" && req.path === "/feedback-console/jira/status" ? "status" :
      req.path === "/feedback-console/jira/configuration" && req.method === "POST" ? "connect" :
      req.path === "/feedback-console/jira/configuration" && req.method === "DELETE" ? "disconnect" : null;
    if (!action) { res.status(404).json({message: "Unknown Jira endpoint."}); return; }
    res.json(await manageJira(action, req.body ?? {}));
  } catch (error) {
    const statuses: Record<string, number> = {"unauthenticated": 401, "permission-denied": 403, "invalid-argument": 400, "not-found": 404, "failed-precondition": 412};
    res.status(error instanceof HttpsError ? statuses[error.code] ?? 503 : 503)
      .json({message: error instanceof HttpsError ? error.message : "Could not complete the Jira request. Check backend setup and try again."});
  }
});
