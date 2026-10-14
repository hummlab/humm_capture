import {HttpsError} from "firebase-functions/v2/https";
import {secretRequest} from "./slack.js";

export type JiraCredentials = {siteUrl: string; projectKey: string; accountEmail: string; apiToken: string};

/** Restrict destinations before sending credentials; redirects are never followed. */
export function validateJiraConfiguration(input: Record<string, unknown>): JiraCredentials {
  let site: URL;
  try { site = new URL(String(input.siteUrl)); } catch { throw new HttpsError("invalid-argument", "Use your Jira Cloud site URL."); }
  if (site.protocol !== "https:" || !/^[a-z0-9-]+\.atlassian\.net$/.test(site.hostname) ||
      site.port || site.username || site.password || site.search || site.hash || site.pathname !== "/") {
    throw new HttpsError("invalid-argument", "Use https://your-team.atlassian.net without a project path.");
  }
  const projectKey = String(input.projectKey ?? "").trim().toUpperCase();
  const accountEmail = String(input.accountEmail ?? "").trim();
  const apiToken = String(input.apiToken ?? "").trim();
  if (!/^[A-Z][A-Z0-9_]{0,99}$/.test(projectKey) || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(accountEmail) ||
      !apiToken || apiToken.length > 4096) throw new HttpsError("invalid-argument", "Enter a project key, account email and API token.");
  return {siteUrl: site.origin, projectKey, accountEmail, apiToken};
}

export function jiraSecretName(suffix: "api-token" | "account-email"): string {
  const project = process.env.GCLOUD_PROJECT;
  if (!project) throw new HttpsError("failed-precondition", "Firebase project configuration is missing.");
  return `projects/${project}/secrets/feedback-console-jira-${suffix}`;
}

export async function writeJiraSecret(suffix: "api-token" | "account-email", value: string): Promise<void> {
  const name = jiraSecretName(suffix);
  await secretRequest(name.slice(0, name.lastIndexOf("/secrets/")) + "/secrets?secretId=" + name.split("/").at(-1),
    "POST", {replication: {automatic: {}}});
  await secretRequest(`${name}:addVersion`, "POST", {payload: {data: Buffer.from(value).toString("base64")}});
}

export async function readJiraCredentials(config: Record<string, unknown>): Promise<JiraCredentials> {
  const read = async (suffix: "api-token" | "account-email") => {
    const secret = await secretRequest(`${jiraSecretName(suffix)}/versions/latest:access`);
    if (!secret.payload?.data) throw new HttpsError("failed-precondition", "Reconnect Jira; its credentials are unavailable.");
    return Buffer.from(secret.payload.data, "base64").toString();
  };
  const [apiToken, accountEmail] = await Promise.all([read("api-token"), read("account-email")]);
  return validateJiraConfiguration({...config, apiToken, accountEmail});
}

export async function jiraRequest(credentials: JiraCredentials, path: string, method = "GET", body?: unknown): Promise<unknown> {
  const multipart = body instanceof FormData;
  const response = await fetch(`${credentials.siteUrl}/rest/api/3${path}`, {
    method, redirect: "error", signal: AbortSignal.timeout(30000),
    headers: {Authorization: `Basic ${Buffer.from(`${credentials.accountEmail}:${credentials.apiToken}`).toString("base64")}`,
      Accept: "application/json", ...(multipart ? {"X-Atlassian-Token": "no-check"} : {"Content-Type": "application/json"})},
    body: body === undefined ? undefined : multipart ? body : JSON.stringify(body),
  });
  if (!response.ok) throw new HttpsError("failed-precondition", `Jira returned HTTP ${response.status}. Check account permissions and project settings.`);
  return response.status === 204 ? null : response.json();
}

export function asRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new HttpsError("failed-precondition", "Unexpected Jira response.");
  return value as Record<string, unknown>;
}

/** Jira localizes type names; never select an epic or subtask as a feedback task. */
export function selectJiraTaskType(value: unknown): Record<string, unknown> {
  const types = Array.isArray(value) ? value.map(asRecord).filter((type) =>
    type.id && type.subtask === false && (type.hierarchyLevel === undefined || type.hierarchyLevel === 0)) : [];
  const task = types.find((type) => ["task", "zadanie"].includes(String(type.name).trim().toLowerCase()));
  if (!task) throw new HttpsError("failed-precondition", "The project needs a standard Task or Zadanie issue type (not an epic or subtask).");
  return task;
}

export async function verifyJira(credentials: JiraCredentials): Promise<Record<string, unknown>> {
  const account = asRecord(await jiraRequest(credentials, "/myself"));
  const project = asRecord(await jiraRequest(credentials, `/project/${encodeURIComponent(credentials.projectKey)}`));
  const task = selectJiraTaskType(project.issueTypes);
  const permissions = asRecord(await jiraRequest(credentials, `/mypermissions?projectKey=${credentials.projectKey}&permissions=BROWSE_PROJECTS,CREATE_ISSUES,CREATE_ATTACHMENTS,EDIT_ISSUES`));
  const values = asRecord(permissions.permissions);
  for (const permission of ["BROWSE_PROJECTS", "CREATE_ISSUES", "CREATE_ATTACHMENTS", "EDIT_ISSUES"]) {
    if (asRecord(values[permission]).havePermission !== true) throw new HttpsError("failed-precondition", `The Jira account needs ${permission} in this project.`);
  }
  const attachments = asRecord(await jiraRequest(credentials, "/attachment/meta"));
  if (attachments.enabled !== true) throw new HttpsError("failed-precondition", "Enable attachments in Jira before connecting.");
  return {siteUrl: credentials.siteUrl, projectKey: credentials.projectKey, projectName: project.name,
    accountLabel: account.displayName, issueTypeId: String(task.id), lastCheckedAt: new Date().toISOString()};
}
