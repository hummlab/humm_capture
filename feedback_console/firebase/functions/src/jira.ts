import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {defineString} from "firebase-functions/params";
import {HttpsError} from "firebase-functions/v2/https";
import {asRecord, jiraRequest, jiraSecretName, readJiraCredentials, validateJiraConfiguration, verifyJira, writeJiraSecret} from "./jiraClient.js";
import {secretRequest} from "./slack.js";

const bucketName = defineString("FEEDBACK_STORAGE_BUCKET");

export function assertJiraCreator(user: Record<string, unknown> | undefined): void {
  if (user?.role === "admin" || user?.feedbackRole === "admin") return;
  if (user?.feedbackRole !== "reviewer" || user.feedbackCanCreateJiraTasks !== true) {
    throw new HttpsError("permission-denied", "Ask an administrator for permission to create Jira tasks.");
  }
}

export async function manageJira(action: string, data: Record<string, unknown>): Promise<unknown> {
  const ref = getFirestore().doc("feedbackIntegrations/jira");
  const config = (await ref.get()).data();
  if (action === "disconnect") {
    // Disable exports first, even if removal of one secret subsequently fails.
    await ref.set({configured: false, connected: false}, {merge: true});
    await Promise.all(["api-token", "account-email"].map((suffix) => secretRequest(jiraSecretName(suffix as "api-token" | "account-email"), "DELETE")));
    return {configured: false, connected: false};
  }
  if (action === "status") {
    if (!config?.configured) return {configured: false, connected: false};
    try {
      const verified = await verifyJira(await readJiraCredentials(config));
      await ref.set({...verified, connected: true}, {merge: true});
      return {...verified, configured: true, connected: true};
    } catch {
      return {configured: true, connected: false, siteUrl: config.siteUrl, projectKey: config.projectKey,
        projectName: config.projectName, accountLabel: config.accountLabel,
        message: "Could not verify Jira. Check its availability, token and account permissions."};
    }
  }
  if (config?.configured) throw new HttpsError("failed-precondition", "Remove the current Jira integration before reconnecting.");
  const credentials = validateJiraConfiguration(data);
  const verified = await verifyJira(credentials);
  await writeJiraSecret("api-token", credentials.apiToken);
  await writeJiraSecret("account-email", credentials.accountEmail);
  await ref.set({...verified, configured: true, connected: true});
  return {...verified, configured: true, connected: true};
}

export function jiraDescription(report: Record<string, unknown>, reportId: string, attachments: {name: string; url: string}[] = []) {
  const context = report.context && typeof report.context === "object" ? report.context as Record<string, unknown> : {};
  const paragraph = (text: string) => ({type: "paragraph", content: text ? [{type: "text", text}] : []});
  const heading = (text: string) => ({type: "heading", attrs: {level: 2}, content: [{type: "text", text}]});
  const details = [
    ["Application", report.applicationName], ["Report type", report.kind],
    ["Environment", context.environment], ["Platform", context.platform],
    ["Version", context.appVersion], ["Build", context.buildNumber],
    ["Device", context.deviceModel], ["OS version", context.osVersion],
    ["Reported", report.capturedAt ? formatReportedAt(report.capturedAt) : undefined],
    ["Report ID", reportId],
  ].filter(([, value]) => value !== undefined && value !== null && value !== "");
  return {type: "doc", version: 1, content: [
    heading("Description"),
    ...String(report.message || "No tester description provided.").split(/\r?\n/).map(paragraph),
    heading("Report details"),
    {type: "bulletList", content: details.map(([label, value]) => ({type: "listItem", content: [{
      type: "paragraph", content: [{type: "text", text: `${label}: `, marks: [{type: "strong"}]},
        {type: "text", text: String(value)}],
    }]}))},
    ...(attachments.length ? [heading("Attachments"), {type: "bulletList", content: attachments.map((file) => ({
      type: "listItem", content: [{type: "paragraph", content: [{type: "text", text: file.name,
        marks: [{type: "link", attrs: {href: file.url}}]}]}],
    }))}] : []),
    paragraph("Submitted through Humm Capture."),
  ]};
}

function formatReportedAt(value: unknown): string {
  const date = new Date(String(value));
  return Number.isNaN(date.getTime()) ? "Unknown" : date.toISOString().slice(0, 16).replace("T", " ") + " UTC";
}

export async function createJiraIssue(reportId: string, input: Record<string, unknown>, actorUid: string): Promise<unknown> {
  const summary = typeof input.summary === "string" ? input.summary.trim() : "";
  if (!summary || summary.length > 120 || typeof input.includeAttachments !== "boolean") {
    throw new HttpsError("invalid-argument", "Use a Jira title of 1–120 characters and select whether to include media.");
  }
  const db = getFirestore();
  const config = (await db.doc("feedbackIntegrations/jira").get()).data();
  if (!config?.configured) throw new HttpsError("failed-precondition", "Connect Jira in the panel first.");
  const credentials = await readJiraCredentials(config);
  const ref = db.doc(`feedbackReports/${reportId}`);
  const report = await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(ref);
    const value = snapshot.data();
    if (!value) throw new HttpsError("not-found", "This feedback is no longer available.");
    if (value.jiraIssueKey) return value;
    // Never automatically retry an uncertain external create: Jira has no create idempotency key.
    if (value.jiraExportState) throw new HttpsError("failed-precondition", "Jira export already started. Check Jira before retrying; its result may be uncertain.");
    tx.update(ref, {jiraExportState: "creating", jiraExportActorUid: actorUid, jiraExportStartedAt: FieldValue.serverTimestamp()});
    return value;
  });
  if (report.jiraIssueKey) return {key: report.jiraIssueKey, url: report.jiraIssueUrl,
    ...(report.jiraExportState === "attachments_failed" ? {warning: "Task already exists; some attachments failed to upload. Check its files in Jira."} : {})};
  let issue: Record<string, unknown>;
  try {
    issue = asRecord(await jiraRequest(credentials, "/issue", "POST", {fields: {
      project: {key: credentials.projectKey}, issuetype: {id: config.issueTypeId}, summary,
      description: jiraDescription(report, reportId), labels: ["humm-capture"],
    }}));
    if (typeof issue.key !== "string" || !/^[A-Z0-9_]+-\d+$/.test(issue.key)) throw new Error("Invalid issue key");
  } catch (error) {
    await ref.update({jiraExportState: "uncertain"});
    throw error instanceof HttpsError ? error : new HttpsError("unavailable", "Jira did not confirm creation. Check Jira before retrying to avoid duplicates.");
  }
  const url = `${credentials.siteUrl}/browse/${issue.key}`;
  // Save the external key BEFORE any attachment IO; errors cannot cause a second create.
  await db.runTransaction(async (tx) => {
    tx.update(ref, {jiraIssueKey: issue.key, jiraIssueUrl: url, jiraExportState: "uploading", status: "in_review", updatedAt: FieldValue.serverTimestamp()});
    tx.set(ref.collection("statusEvents").doc(), {fromStatus: report.status, toStatus: "in_review", actorUid,
      actorLabel: "Jira export", createdAt: FieldValue.serverTimestamp()});
  });
  try {
    const files = [{path: report.screenshotPath, fileName: "screenshot.png", mimeType: "image/png"},
      ...(report.logsPath ? [{path: report.logsPath, fileName: "logs.txt", mimeType: "text/plain"}] : []),
      ...(input.includeAttachments && Array.isArray(report.attachments) ? report.attachments.map(asRecord) : [])];
    let total = 0;
    const links: {name: string; url: string}[] = [];
    for (const file of files) {
      if (typeof file.path !== "string" || !file.path.startsWith(`feedback/${reportId}/`)) throw new Error("Invalid attachment path");
      const stored = getStorage().bucket(bucketName.value()).file(file.path);
      const [metadata] = await stored.getMetadata();
      const size = Number(metadata.size);
      total += size;
      if (!Number.isFinite(size) || size <= 0 || total > 25 * 1024 * 1024) throw new Error("Attachment limit");
      const [bytes] = await stored.download();
      const form = new FormData();
      form.append("file", new Blob([new Uint8Array(bytes)], {type: String(file.mimeType || "application/octet-stream")}),
        String(file.fileName || "attachment").replace(/[\r\n/\\]/g, "_"));
      const uploaded = await jiraRequest(credentials, `/issue/${issue.key}/attachments`, "POST", form);
      if (!Array.isArray(uploaded)) throw new Error("Invalid upload response");
      for (const item of uploaded.map(asRecord)) {
        const attachmentUrl = new URL(String(item.content));
        if (attachmentUrl.origin !== credentials.siteUrl) throw new Error("Invalid attachment URL");
        links.push({name: String(item.filename || file.fileName), url: attachmentUrl.href});
      }
    }
    await jiraRequest(credentials, `/issue/${issue.key}`, "PUT", {fields: {description: jiraDescription(report, reportId, links)}});
    await ref.update({jiraExportState: "complete"});
    return {key: issue.key, url};
  } catch {
    await ref.update({jiraExportState: "attachments_failed"});
    return {key: issue.key, url, warning: "Task created, but some attachments could not be uploaded. Open Jira to check the files; do not create another task."};
  }
}
