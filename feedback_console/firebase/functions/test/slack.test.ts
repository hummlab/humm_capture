import {beforeEach, describe, expect, it, vi} from "vitest";

const fixture = vi.hoisted(() => ({documents: new Map<string, Record<string, unknown>>()}));
vi.mock("firebase-admin/app", () => ({getApp: () => ({options: {credential: {getAccessToken: async () => ({access_token: "test-oauth"})}}})}));
vi.mock("firebase-admin/firestore", () => {
  const doc = (path: string) => ({
    get: async () => ({data: () => fixture.documents.get(path)}),
    set: async (value: Record<string, unknown>) => { fixture.documents.set(path, value); },
    update: async (value: Record<string, unknown>) => { fixture.documents.set(path, {...fixture.documents.get(path), ...value}); },
  });
  return {
    FieldValue: {serverTimestamp: () => ({toDate: () => new Date("2026-09-30T12:00:00Z")})},
    getFirestore: () => ({doc, runTransaction: async (run: (transaction: unknown) => unknown) => run({get: (ref: ReturnType<typeof doc>) => ref.get(), update: (ref: ReturnType<typeof doc>, value: Record<string, unknown>) => ref.update(value)})}),
  };
});

import {manageFeedbackSlack, notifyFeedbackSlack, validateSlackWebhook, validateSlackMessageSettings} from "../src/slack.js";
import {defaultSlackMessageSettings} from "../src/slackMessage.js";
import {assertFeedbackAdministrator} from "../src/authorization.js";

const webhook = "https://hooks.slack.com/services/TTEST/BTEST/testtoken";
let slackCalls: number;
let slackStatus: number;
beforeEach(() => {
  fixture.documents.clear();
  fixture.documents.set("feedbackIntegrations/slack", {connected: true});
  fixture.documents.set("feedbackReports/report1", {message: "Button overlaps", context: {environment: "stage"}});
  slackCalls = 0;
  slackStatus = 200;
  vi.stubEnv("GCLOUD_PROJECT", "test-project");
  vi.stubGlobal("fetch", vi.fn(async (url: string) => {
    if (url.startsWith("https://hooks.slack.com/")) {
      slackCalls++;
      return new Response("ok", {status: slackStatus});
    }
    return new Response(JSON.stringify({payload: {data: Buffer.from(webhook).toString("base64")}}), {status: 200});
  }));
});

describe("standalone Slack service", () => {
  it("accepts only Slack HTTPS webhook destinations", () => expect(validateSlackWebhook(webhook)).toBe(webhook));
  it.each([
    "not a url", "http://hooks.slack.com/services/T/B/token",
    "https://hooks.slack.com:444/services/T/B/token",
    "https://localhost/services/T/B/token", "https://hooks.slack.com.evil.test/services/T/B/token",
    "https://user:password@hooks.slack.com/services/T/B/token", "https://hooks.slack.com/services/T/B/token?secret=1",
  ])("rejects unsafe destination %s", (url) => expect(() => validateSlackWebhook(url)).toThrow());

  it("permits administrators and rejects reviewers or absent users", () => {
    expect(() => assertFeedbackAdministrator({feedbackRole: "admin"})).not.toThrow();
    expect(() => assertFeedbackAdministrator({role: "admin"})).not.toThrow();
    expect(() => assertFeedbackAdministrator({feedbackRole: "reviewer"})).toThrow();
    expect(() => assertFeedbackAdministrator(undefined)).toThrow();
  });
  it("returns safe connection metadata without reading the secret", async () => {
    expect(await manageFeedbackSlack({action: "status"})).toEqual({connected: true, lastDeliveryStatus: null, lastDeliveredAt: null,
      messageSettings: defaultSlackMessageSettings});
    expect(fetch).not.toHaveBeenCalled();
  });
  it("rejects malformed message settings and link injection", () => {
    expect(() => validateSlackMessageSettings({...defaultSlackMessageSettings, linkLabel: '<!channel>'})).toThrow();
    expect(() => validateSlackMessageSettings({...defaultSlackMessageSettings, includeDescription: 'yes'})).toThrow();
  });
  it("sends a new report once and persists successful delivery", async () => {
    await notifyFeedbackSlack("report1", "https://customer-feedback.test");
    await notifyFeedbackSlack("report1", "https://customer-feedback.test");
    expect(slackCalls).toBe(1);
    expect(fixture.documents.get("feedbackReports/report1")?.slackDeliveryStatus).toBe("sent");
    const body = (fetch as ReturnType<typeof vi.fn>).mock.calls.find(([url]) => String(url).startsWith("https://hooks.slack.com/"))?.[1].body;
    expect(body).toContain("stage");
    expect(body).not.toContain("hummlab");
  });
  it("does not send when integration is disconnected or report is absent", async () => {
    fixture.documents.set("feedbackIntegrations/slack", {connected: false});
    await notifyFeedbackSlack("report1", "https://customer-feedback.test");
    fixture.documents.set("feedbackIntegrations/slack", {connected: true});
    await notifyFeedbackSlack("missing", "https://customer-feedback.test");
    expect(fetch).not.toHaveBeenCalled();
  });
  it("stops after five transient attempts", async () => {
    slackStatus = 503;
    for (let attempt = 0; attempt < 5; attempt++) {
      await expect(notifyFeedbackSlack("report1", "https://customer-feedback.test")).rejects.toThrow("will be retried");
    }
    await notifyFeedbackSlack("report1", "https://customer-feedback.test");
    expect(slackCalls).toBe(5);
    expect(fixture.documents.get("feedbackReports/report1")?.slackDeliveryStatus).toBe("failed");
  });
  it("stops immediately for a revoked webhook", async () => {
    slackStatus = 404;
    await notifyFeedbackSlack("report1", "https://customer-feedback.test");
    await notifyFeedbackSlack("report1", "https://customer-feedback.test");
    expect(slackCalls).toBe(1);
    expect(fixture.documents.get("feedbackReports/report1")?.slackDeliveryStatus).toBe("failed");
  });
});
