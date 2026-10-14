import {beforeEach, describe, expect, it, vi} from "vitest";

const fixture = vi.hoisted(() => ({documents: new Map<string, Record<string, unknown>>(), creates: 0, uploadFails: false}));
vi.mock("../src/slack.js", () => ({secretRequest: async () => ({payload: {data: Buffer.from("test@example.com").toString("base64")}})}));
vi.mock("firebase-functions/params", () => ({defineString: () => ({value: () => "test-bucket"})}));
vi.mock("firebase-admin/storage", () => ({getStorage: () => ({bucket: () => ({file: () => ({
  getMetadata: async () => [{size: 4}], download: async () => [Buffer.from("test")],
})})})}));
vi.mock("firebase-admin/firestore", () => {
  const doc = (path: string): any => ({
    get: async () => ({data: () => fixture.documents.get(path)}),
    set: async (value: Record<string, unknown>) => {fixture.documents.set(path, value);},
    update: async (value: Record<string, unknown>) => {fixture.documents.set(path, {...fixture.documents.get(path), ...value});},
    collection: () => ({doc: () => doc(`${path}/statusEvents/test`)}),
  });
  return {FieldValue: {serverTimestamp: () => "timestamp"}, getFirestore: () => ({doc,
    runTransaction: async (run: (tx: unknown) => unknown) => run({get: (ref: any) => ref.get(), update: (ref: any, data: unknown) => ref.update(data), set: (ref: any, data: unknown) => ref.set(data)}),
  })};
});

import {selectJiraTaskType, validateJiraConfiguration} from "../src/jiraClient.js";
import {assertJiraCreator, createJiraIssue, jiraDescription} from "../src/jira.js";

const credentials = {siteUrl: "https://test.atlassian.net", projectKey: "GF", accountEmail: "test@example.com", apiToken: "test-only"};
beforeEach(() => {
  fixture.documents.clear(); fixture.creates = 0; fixture.uploadFails = false;
  vi.stubEnv("GCLOUD_PROJECT", "test-project");
  fixture.documents.set("feedbackIntegrations/jira", {...credentials, configured: true, issueTypeId: "10001"});
  fixture.documents.set("feedbackReports/report1", {message: "Tester description", status: "new", screenshotPath: "feedback/report1/screenshot", logsPath: "feedback/report1/logs.txt", context: {environment: "stage", appVersion: "1.0.1"}});
  vi.stubGlobal("fetch", vi.fn(async (url: string, options: RequestInit) => {
    if (url.endsWith("/issue") && options.method === "POST") { fixture.creates++; return Response.json({key: "GF-1"}); }
    if (url.endsWith("/attachments")) {
      if (fixture.uploadFails) return new Response("denied", {status: 403});
      return Response.json([{filename: "test.png", content: "https://test.atlassian.net/rest/api/3/attachment/content/1"}]);
    }
    return new Response(null, {status: 204});
  }));
});

describe("standalone Jira export", () => {
  it("accepts Polish task names and excludes subtasks and epics", () => {
    expect(selectJiraTaskType([{id: "1", name: "Zadanie", subtask: false, hierarchyLevel: 0}]).id).toBe("1");
    expect(selectJiraTaskType([{id: "2", name: "Task", subtask: false}]).id).toBe("2");
    for (const type of [{id: "3", name: "Task", subtask: true}, {id: "4", name: "Zadanie", subtask: false, hierarchyLevel: 1}]) {
      expect(() => selectJiraTaskType([type])).toThrow();
    }
  });
  it("restricts credential destinations", () => {
    expect(validateJiraConfiguration(credentials).siteUrl).toBe(credentials.siteUrl);
    for (const siteUrl of ["https://localhost", "https://test.atlassian.net.evil.org", "http://test.atlassian.net", "https://test.atlassian.net/projects/GF", "https://user@test.atlassian.net"]) {
      expect(() => validateJiraConfiguration({...credentials, siteUrl})).toThrow();
    }
  });
  it("requires explicit reviewer permission", () => {
    expect(() => assertJiraCreator({feedbackRole: "admin"})).not.toThrow();
    expect(() => assertJiraCreator({feedbackRole: "reviewer", feedbackCanCreateJiraTasks: true})).not.toThrow();
    expect(() => assertJiraCreator({feedbackRole: "reviewer"})).toThrow();
    expect(() => assertJiraCreator({feedbackCanCreateJiraTasks: true})).toThrow();
  });
  it("preserves description and environment", () => {
    const description = JSON.stringify(jiraDescription(fixture.documents.get("feedbackReports/report1")!, "report1"));
    expect(description).toContain("Tester description"); expect(description).toContain("stage");
    expect(description).not.toContain("Screenshot and selected media are attached");
  });
  it("formats details and attachment links as structured ADF", () => {
    const result = jiraDescription({message: "First line\nSecond line", applicationName: "Test", context: {buildNumber: 0}}, "report1",
      [{name: "screenshot.png", url: "https://test.atlassian.net/file/1"}]);
    const serialized = JSON.stringify(result);
    expect(serialized).toContain('"type":"heading"');
    expect(serialized).toContain('"type":"bulletList"');
    expect(serialized).toContain('"type":"strong"');
    expect(serialized).toContain("Build: ");
    expect(serialized).toContain("Second line");
    expect(serialized).not.toContain("applicationName:");
    expect(serialized).toContain("https://test.atlassian.net/file/1");
  });
  it("saves key, status and files without creating a second task", async () => {
    await createJiraIssue("report1", {summary: "Feedback 1", includeAttachments: false}, "admin");
    const repeated = await createJiraIssue("report1", {summary: "Feedback 1", includeAttachments: false}, "admin");
    expect(repeated).toEqual({key: "GF-1", url: "https://test.atlassian.net/browse/GF-1"});
    expect(fixture.creates).toBe(1);
    expect(fixture.documents.get("feedbackReports/report1")).toMatchObject({jiraExportState: "complete", status: "in_review"});
  });
  it("keeps the created key and warns when attachments fail", async () => {
    fixture.uploadFails = true;
    expect(await createJiraIssue("report1", {summary: "Feedback 1", includeAttachments: true}, "admin")).toHaveProperty("warning");
    expect(fixture.documents.get("feedbackReports/report1")).toMatchObject({jiraIssueKey: "GF-1", jiraExportState: "attachments_failed"});
    await createJiraIssue("report1", {summary: "Feedback 1", includeAttachments: true}, "admin");
    expect(fixture.creates).toBe(1);
  });
  it("does not retry an ambiguous external creation", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => { throw new Error("timeout"); }));
    await expect(createJiraIssue("report1", {summary: "Feedback 1", includeAttachments: false}, "admin")).rejects.toThrow();
    expect(fixture.documents.get("feedbackReports/report1")).toMatchObject({jiraExportState: "uncertain"});
    await expect(createJiraIssue("report1", {summary: "Feedback 1", includeAttachments: false}, "admin")).rejects.toThrow("already started");
  });
});
