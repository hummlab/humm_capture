import {describe, expect, it} from "vitest";
import {formatFeedbackLogs} from "../src/logFile.js";

describe("readable diagnostics", () => {
  it("includes environment, version, severity, category and multiline context", () => {
    const file = formatFeedbackLogs({capturedAt: "2026-10-01T12:00:00Z",
      context: {environment: "stage", appVersion: "1.0.1", buildNumber: "2"},
      logs: [{timestamp: "2026-10-01T13:00:00+01:00", level: "error", category: "network",
        message: "Request failed\nStack trace"}]});
    expect(file).toContain("Environment: stage");
    expect(file).toContain("Version: 1.0.1 | Build: 2");
    expect(file).toContain("2026-10-01T12:00:00.000Z | ERROR | network | Request failed\n    Stack trace");
  });
});
