import {beforeEach, describe, expect, it, vi} from "vitest";

const fixture = vi.hoisted(() => ({
  user: {feedbackRole: "admin"} as Record<string, unknown>,
  verifyToken: vi.fn(), manage: vi.fn(),
}));
vi.mock("firebase-admin/app", () => ({initializeApp: vi.fn()}));
vi.mock("firebase-admin/auth", () => ({getAuth: () => ({verifyIdToken: fixture.verifyToken})}));
vi.mock("firebase-admin/firestore", () => ({getFirestore: () => ({doc: () => ({get: async () => ({data: () => fixture.user})})})}));
vi.mock("firebase-functions/params", () => ({defineString: () => ({value: () => "https://customer-feedback.test"})}));
vi.mock("firebase-functions/v2/firestore", () => ({onDocumentCreated: (_: unknown, handler: unknown) => handler}));
vi.mock("firebase-functions/v2/https", async (loadOriginal) => ({
  ...await loadOriginal<Record<string, unknown>>(),
  onRequest: (_: unknown, handler: unknown) => handler,
}));
vi.mock("../src/slack.js", () => ({manageFeedbackSlack: fixture.manage, notifyFeedbackSlack: vi.fn()}));

import {feedbackSlackApi} from "../src/index.js";

beforeEach(() => {
  vi.clearAllMocks();
  fixture.user = {feedbackRole: "admin"};
  fixture.verifyToken.mockResolvedValue({uid: "test-user"});
  fixture.manage.mockResolvedValue({connected: true});
});

async function request({method = "GET", path = "/feedback-console/slack/status", token = "Bearer test-token", origin = "https://customer-feedback.test", size = 0} = {}) {
  const req = {method, path, headers: {origin}, get: () => token, rawBody: {length: size}, body: {}};
  const res = {status: vi.fn(), set: vi.fn(), json: vi.fn(), send: vi.fn()};
  for (const method of ["status", "set", "json", "send"] as const) res[method].mockReturnValue(res);
  await feedbackSlackApi(req as never, res as never);
  return res;
}

describe("standalone Slack HTTP authorization", () => {
  it("validates Firebase identity and administrator role", async () => {
    const res = await request();
    expect(fixture.verifyToken).toHaveBeenCalledWith("test-token", true);
    expect(fixture.manage).toHaveBeenCalledWith({action: "status", webhook: undefined});
    expect(res.json).toHaveBeenCalledWith({connected: true});
  });
  it("rejects unauthenticated requests", async () => {
    const res = await request({token: ""});
    expect(res.status).toHaveBeenCalledWith(401);
    expect(fixture.manage).not.toHaveBeenCalled();
  });
  it("rejects revoked tokens without returning the exception", async () => {
    fixture.verifyToken.mockRejectedValue(new Error("private diagnostic"));
    const res = await request();
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({message: "Sign in again to manage Slack."});
    expect(fixture.manage).not.toHaveBeenCalled();
  });
  it("rejects reviewers even when they call the API directly", async () => {
    fixture.user = {feedbackRole: "reviewer"};
    const res = await request({method: "POST", path: "/feedback-console/slack/configuration"});
    expect(res.status).toHaveBeenCalledWith(403);
    expect(fixture.manage).not.toHaveBeenCalled();
  });
  it("rejects another browser origin before processing credentials", async () => {
    const res = await request({origin: "https://untrusted.test"});
    expect(res.status).toHaveBeenCalledWith(403);
    expect(fixture.verifyToken).not.toHaveBeenCalled();
  });
  it("handles CORS preflight without sending a notification", async () => {
    const res = await request({method: "OPTIONS", token: ""});
    expect(res.status).toHaveBeenCalledWith(204);
    expect(fixture.manage).not.toHaveBeenCalled();
  });
  it("rejects oversized requests and unknown routes", async () => {
    expect((await request({size: 4097})).status).toHaveBeenCalledWith(400);
    expect((await request({path: "/unrecognized"})).status).toHaveBeenCalledWith(404);
    expect(fixture.manage).not.toHaveBeenCalled();
  });
});
