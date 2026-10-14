/** Portable webhook payload. Never exposes private media download URLs. */
export const defaultSlackMessageSettings = {feedbackHeading: "New feedback", bugHeading: "New bug", linkLabel: "Open report", includeDescription: true};

export function feedbackSlackMessage(report: Record<string, unknown>, reportId: string, consoleUrl: string,
  settings: typeof defaultSlackMessageSettings = defaultSlackMessageSettings) {
  const value = (input: unknown, limit: number) => typeof input === "string" ? input.trim().slice(0, limit) : "";
  const kind = report.kind === "bug" ? settings.bugHeading : settings.feedbackHeading;
  const title = value(report.title, 150) || kind;
  const description = settings.includeDescription ? value(report.message, 2900) : "";
  const context = typeof report.context === "object" && report.context !== null ?
    report.context as Record<string, unknown> : {};
  const summary = [value(report.applicationName, 200) || "Application",
    value(context.environment, 30), value(context.platform, 50),
    value(context.appVersion, 50), context.buildNumber ? `build ${value(context.buildNumber, 50)}` : ""]
    .filter(Boolean).join(" · ");
  const url = new URL(consoleUrl);
  url.searchParams.set("feedback", reportId);
  const blocks: Record<string, unknown>[] = [
    {type: "header", text: {type: "plain_text", text: title, emoji: false}},
    {type: "context", elements: [{type: "plain_text", text: summary, emoji: false}]},
  ];
  if (description) blocks.push({type: "section", text: {type: "plain_text", text: description, emoji: false}});
  const escape = (text: string) => text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  // A normal link needs no interactive endpoint or action acknowledgement.
  const linkLabel = settings.linkLabel.replace(/[<>|\r\n]/g, " ");
  blocks.push({type: "section", text: {type: "mrkdwn", text: `<${escape(url.href)}|${escape(linkLabel)}>`}});
  return {text: [title, summary, description, url.href].filter(Boolean).map(escape).join("\n"),
    blocks, unfurl_links: false, unfurl_media: false};
}
