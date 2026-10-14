# Feedback Console UI

The current specification is [DESIGN.md](../DESIGN.md). The console is a
feedback review tool: real screenshots, tester descriptions and diagnostics
establish its visual identity.

A warm sidebar carries Capture branding and labeled navigation at desktop widths.
The white inbox uses a strong heading, a counted status-tab baseline, a search /
filter toolbar and virtualized rows. Secondary filters expand inline. Reset clears
all filters and the visible search value. Phone navigation uses a drawer; status
tabs scroll horizontally.

A report uses a neutral screenshot surface and white reading column on desktop.
The description and status lead the reading column; Jira, attachments, technical
context, logs and activity follow. Phone layouts place the screenshot directly
below the overview. The gallery supports image attachments, previous / next,
keyboard navigation, Escape, zoom and original-file access. Videos keep their
existing browser-player link.

Jira and Slack share heading, input and connection styling. Refresh preserves
known content. Initial placeholders are static and labeled for accessibility.
Credentials are never displayed or fabricated in form fields. Existing backend
permissions, persisted data and integration actions are unchanged.

## References and research limits

- [Taste Redesign Skill](https://github.com/Leonxlnx/taste-skill/blob/main/skills/redesign-skill/SKILL.md)
- [Web Interface Guidelines](https://github.com/vercel-labs/web-interface-guidelines/blob/main/AGENTS.md)
- [Linear triage](https://linear.app/docs/triage)

Apply relevant product-interface guidance rather than marketing effects.
No callable Mobbin MCP is available in the current session; authenticated Mobbin
screen research is not claimed. Flutter work follows flutter-dart-global-rules.

Verify real inbox, search/reset, filters, report/gallery, media/log access and
integration refresh at phone and desktop sizes. Unit/widget checks do not replace
visual browser verification. No production deployment is implied.
