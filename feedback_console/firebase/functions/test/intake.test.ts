import {describe, expect, it} from "vitest";
import {parseFeedback} from "../src/intake.js";
const image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aN1sAAAAASUVORK5CYII=";
const report = () => ({contentType: "image/png", imageBase64: image, capturedAt: "2026-10-01T10:00:00Z", kind: "bug", context: {environment: "stage", userId: "spoofed"}});
describe("standalone intake validation", () => {
  it("preserves environment and ignores unverified user identity", () => {
    const parsed = parseFeedback(report());
    expect(parsed.context).toEqual({environment: "stage"});
    expect(parsed.kind).toBe("bug");
  });
  it("rejects forged media MIME", () => expect(() => parseFeedback({...report(), contentType: "image/jpeg"})).toThrow());
  it("rejects invalid environment", () => expect(() => parseFeedback({...report(), context: {environment: "test"}})).toThrow());
  it("rejects invalid capture date", () => expect(() => parseFeedback({...report(), capturedAt: "no"})).toThrow());
  it("rejects too many attachments", () => expect(() => parseFeedback({...report(), attachments: Array(6).fill({})})).toThrow());
  it("accepts image attachments", () => expect(parseFeedback({...report(), attachments: [{fileName: "test.png", mimeType: "image/png", dataBase64: image}]}).attachments).toHaveLength(1));
  it("rejects malformed base64", () => expect(() => parseFeedback({...report(), imageBase64: "not base64"})).toThrow());
  it("rejects oversized descriptions", () => expect(() => parseFeedback({...report(), message: "x".repeat(10001)})).toThrow());
});
