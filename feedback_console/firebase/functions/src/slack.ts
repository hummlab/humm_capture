import {getApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";
import {feedbackSlackMessage, defaultSlackMessageSettings} from "./slackMessage.js";

export function validateSlackMessageSettings(value: unknown): typeof defaultSlackMessageSettings {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new HttpsError("invalid-argument", "Message settings are required.");
  const input = value as Record<string, unknown>;
  const output = {...defaultSlackMessageSettings};
  for (const key of ["feedbackHeading", "bugHeading", "linkLabel"] as const) {
    if (typeof input[key] !== "string" || !input[key].trim() || input[key].length > 100 || /[<>|\r\n]/.test(input[key])) {
      throw new HttpsError("invalid-argument", "Use 1–100 characters without link markup for message labels.");
    }
    output[key] = input[key].trim();
  }
  if (typeof input.includeDescription !== "boolean") throw new HttpsError("invalid-argument", "Description setting must be boolean.");
  output.includeDescription = input.includeDescription;
  return output;
}

/** Only Slack-owned HTTPS URLs may receive feedback notifications. */
export function validateSlackWebhook(value: unknown): string {
  if (typeof value !== "string") throw new HttpsError("invalid-argument", "Webhook is required.");
  let url: URL;
  try {
    url = new URL(value.trim());
  } catch {
    throw new HttpsError("invalid-argument", "Use a Slack Incoming Webhook URL.");
  }
  if (url.protocol !== "https:" || url.hostname !== "hooks.slack.com" ||
      url.port || url.username || url.password || url.search || url.hash ||
      !/^\/services\/[A-Za-z0-9]+\/[A-Za-z0-9]+\/[A-Za-z0-9]+$/.test(url.pathname)) {
    throw new HttpsError("invalid-argument", "Use a Slack Incoming Webhook URL.");
  }
  return url.href;
}

export async function secretRequest(path: string, method = "GET", body?: unknown): Promise<{payload?: {data: string}}> {
  const credential = getApp().options.credential;
  if (!credential) throw new HttpsError("internal", "Backend credentials are unavailable.");
  const token = await credential.getAccessToken();
  const response = await fetch(`https://secretmanager.googleapis.com/v1/${path}`, {
    method,
    headers: {Authorization: `Bearer ${token.access_token}`, "Content-Type": "application/json"},
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(15000),
  });
  if (response.status === 409 && method === "POST" && path.includes("?secretId=")) return {};
  if (response.status === 404 && method === "DELETE") return {};
  if (response.status === 429 || response.status >= 500) {
    throw new HttpsError("unavailable", "Secret Manager is temporarily unavailable.");
  }
  if (!response.ok) {
    throw new HttpsError("failed-precondition", "Secret Manager access is required for this integration.");
  }
  return response.status === 204 ? {} : await response.json() as {payload?: {data: string}};
}

function secretName(): string {
  const project = process.env.GCLOUD_PROJECT;
  if (!project) {
    throw new HttpsError("failed-precondition", "Slack project configuration is unavailable.");
  }
  return `projects/${project}/secrets/feedback-console-slack`;
}

async function postMessage(webhook: string, message: string | ReturnType<typeof feedbackSlackMessage>): Promise<void> {
  const response = await fetch(validateSlackWebhook(webhook), {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(typeof message === "string" ? {text: message, unfurl_links: false, unfurl_media: false} : message),
    redirect: "error",
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) throw new HttpsError(
    response.status === 429 || response.status >= 500 ? "unavailable" : "failed-precondition",
    `Slack returned HTTP ${response.status}.`,
  );
}

/** Called only after console administrator authorization. Never returns the webhook. */
export async function manageFeedbackSlack(data: Record<string, unknown>): Promise<unknown> {
  const ref = getFirestore().doc("feedbackIntegrations/slack");
  const current = await ref.get();
  if (data.action === "status") return {
    connected: current.data()?.connected === true,
    messageSettings: {...defaultSlackMessageSettings, ...current.data()?.messageSettings},
    lastDeliveryStatus: current.data()?.lastDeliveryStatus ?? null,
    lastDeliveredAt: current.data()?.lastDeliveredAt?.toDate().toISOString() ?? null,
  };
  if (data.action === "settings") {
    const messageSettings = validateSlackMessageSettings(data.messageSettings);
    await ref.set({messageSettings, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    return {connected: current.data()?.connected === true, messageSettings};
  }
  const name = secretName();
  if (data.action === "disconnect") {
    if (current.data()?.connected) await secretRequest(name, "DELETE");
    await ref.set({connected: false, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
    return {connected: false};
  }
  if (data.action === "test") {
    if (!current.data()?.connected) throw new HttpsError("failed-precondition", "Connect Slack first.");
    const secret = await secretRequest(`${name}/versions/latest:access`);
    if (!secret.payload?.data) throw new HttpsError("failed-precondition", "Slack secret is unavailable.");
    await postMessage(Buffer.from(secret.payload.data, "base64").toString(), "Feedback Console: test notification.");
    return {
      connected: true,
      lastDeliveryStatus: current.data()?.lastDeliveryStatus ?? null,
      lastDeliveredAt: current.data()?.lastDeliveredAt?.toDate().toISOString() ?? null,
    };
  }
  if (data.action !== "connect") throw new HttpsError("invalid-argument", "Unknown Slack action.");
  if (current.data()?.connected) throw new HttpsError("failed-precondition", "Remove the existing integration first.");
  const webhook = validateSlackWebhook(data.webhook);
  await postMessage(webhook, "Feedback Console: connection test.");
  if (!current.data()?.connected) {
    await secretRequest(name.slice(0, name.lastIndexOf("/secrets/")) + "/secrets?secretId=" + name.split("/").at(-1),
      "POST", {replication: {automatic: {}}});
  }
  await secretRequest(`${name}:addVersion`, "POST", {payload: {data: Buffer.from(webhook).toString("base64")}});
  await ref.set({connected: true, updatedAt: FieldValue.serverTimestamp()}, {merge: true});
  return {connected: true};
}

/** Runs independently from feedback intake; transient failures trigger a retry. */
export async function notifyFeedbackSlack(feedbackId: string, consoleUrl: string): Promise<void> {
  const db = getFirestore();
  const configRef = db.doc("feedbackIntegrations/slack");
  const config = await configRef.get();
  if (config.data()?.connected !== true) return;
  const reportRef = db.doc(`feedbackReports/${feedbackId}`);
  const report = (await reportRef.get()).data();
  if (!report || report.slackNotifiedAt || report.slackDeliveryStatus === "failed") return;
  const claimed = await db.runTransaction(async (transaction) => {
    const latest = (await transaction.get(reportRef)).data();
    if (!latest || latest.slackNotifiedAt || latest.slackDeliveryStatus === "failed") return false;
    if (latest.slackLeaseUntil > Date.now()) throw new HttpsError("unavailable", "Notification is being sent.");
    const attempts = Number(latest.slackDeliveryAttempts ?? 0);
    if (attempts >= 5) {
      transaction.update(reportRef, {slackDeliveryStatus: "failed", slackLeaseUntil: 0});
      transaction.update(configRef, {lastDeliveryStatus: "failed"});
      return false;
    }
    transaction.update(reportRef, {slackDeliveryAttempts: attempts + 1, slackLeaseUntil: Date.now() + 60000, slackDeliveryStatus: "sending"});
    return true;
  });
  if (!claimed) return;
  try {
    const secret = await secretRequest(`${secretName()}/versions/latest:access`);
    if (!secret.payload?.data) throw new HttpsError("failed-precondition", "Slack secret is unavailable.");
    await postMessage(Buffer.from(secret.payload.data, "base64").toString(), feedbackSlackMessage(report, feedbackId, consoleUrl,
      {...defaultSlackMessageSettings, ...config.data()?.messageSettings}));
    await reportRef.update({slackNotifiedAt: FieldValue.serverTimestamp(), slackDeliveryStatus: "sent", slackLeaseUntil: 0});
    await configRef.update({lastDeliveryStatus: "sent", lastDeliveredAt: FieldValue.serverTimestamp()});
  } catch (error) {
    const retryable = !(error instanceof HttpsError) || error.code === "unavailable";
    await reportRef.update({slackDeliveryStatus: retryable ? "retrying" : "failed", slackLeaseUntil: 0});
    await configRef.update({lastDeliveryStatus: retryable ? "retrying" : "failed"});
    // Never log the webhook or fetch errors, which can contain the secret URL.
    if (retryable) throw new HttpsError("unavailable", "Slack notification will be retried.");
  }
}
