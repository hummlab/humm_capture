import {describe, expect, it} from "vitest";
import {feedbackSlackMessage} from "../src/slackMessage.js";

describe("Slack report presentation", () => {
  it("supports custom headings/link and omits descriptions when disabled", () => {
    const payload = feedbackSlackMessage({kind: "bug", message: "private description"}, "id", "https://console.test",
      {feedbackHeading: "Feedback received", bugHeading: "Bug reported", linkLabel: "View details", includeDescription: false});
    expect(payload.blocks[0]).toMatchObject({text: {text: "Bug reported"}});
    expect(JSON.stringify(payload)).not.toContain("private description");
    expect(payload.blocks.at(-1)).toMatchObject({text: {text: "<https://console.test/?feedback=id|View details>"}});
  });
  it("sends an optional title, description and exact report link", () => {
    const payload = feedbackSlackMessage({title: "Open button", message: "Button overlaps",
      context: {environment: "dev", appVersion: "1.0.1", buildNumber: "2"}}, "report/1", "https://console.test/?other=1");
    expect(payload.blocks[0]).toMatchObject({text: {text: "Open button"}});
    expect(payload.blocks).toContainEqual({type: "section", text: {type: "plain_text", text: "Button overlaps", emoji: false}});
    expect(payload.text).toContain("feedback=report%2F1");
    expect(payload.text).toContain("other=1");
    expect(payload.blocks.at(-1)).toMatchObject({type: "section", text: {type: "mrkdwn",
      text: "<https://console.test/?other=1&amp;feedback=report%2F1|Open report>"}});
    expect(JSON.stringify(payload.blocks)).not.toContain('"type":"button"');
  });
  it("falls back by kind and omits empty descriptions", () => {
    const payload = feedbackSlackMessage({kind: "bug", title: " ", message: " "}, "id", "https://console.test");
    expect(payload.blocks[0]).toMatchObject({text: {text: "New bug"}});
    expect(payload.blocks).toHaveLength(3);
  });
  it("bounds content, uses literal text and never includes private media", () => {
    const payload = feedbackSlackMessage({title: "x".repeat(200), message: "<!channel> " + "x".repeat(4000),
      screenshotPath: "secret/image", logsPath: "secret/logs", attachments: [{url: "https://private.test"}]}, "id", "https://console.test");
    expect(payload.blocks[0]).toMatchObject({text: {text: "x".repeat(150), type: "plain_text"}});
    expect(JSON.stringify(payload)).not.toContain("secret/");
    expect(JSON.stringify(payload)).not.toContain("private.test");
    expect(payload.blocks[2]).toMatchObject({text: {type: "plain_text"}});
    expect(payload.text).not.toContain("<!channel>");
  });
});
