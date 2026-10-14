/** Human-readable diagnostic file suitable for download or Jira attachment. */
export function formatFeedbackLogs(report: {
  capturedAt: string;
  context: Record<string, unknown>;
  logs: {timestamp: string; level: unknown; message: string; category?: string}[];
}) {
  const printable = (value: unknown) => String(value ?? "unspecified").replace(/[\r\n\t]/g, " ");
  const context = report.context;
  const lines = ["Feedback diagnostics", "Times: UTC", `Captured: ${report.capturedAt}`,
    `Environment: ${printable(context.environment)}`,
    `Platform: ${printable(context.platform)}`,
    `Version: ${printable(context.appVersion)} | Build: ${printable(context.buildNumber)}`,
    `Entries: ${report.logs.length}`, "", "Time | Level | Category | Message"];
  for (const log of report.logs) {
    lines.push(`${new Date(log.timestamp).toISOString()} | ${printable(log.level).toUpperCase()} | ${printable(log.category ?? "app")} | ${log.message.replace(/\r?\n/g, "\n    ")}`);
  }
  return lines.join("\n") + "\n";
}
