# Capture Console design

This is a working feedback inbox, not a marketing dashboard. A reviewer should
scan descriptions, inspect the actual screenshot and make a decision.

## Visual language

- Geist is bundled locally under its SIL Open Font License. Use regular for body,
  medium for controls and semibold for headings; avoid making everything bold.
- Palette comes from `lib/src/console_theme.dart`: warm off-white canvas, charcoal
  text, muted forest actions, one consistent neutral family. Status colors remain
  semantic and always include labels.
- Space and type establish hierarchy. Settings are open sections divided by thin
  lines, with a narrow heading column and a wider control column on desktop.
- Inbox reports are virtualized rows with small real screenshot previews,
  descriptions and contextual metadata. No repeated equal-size dashboard cards.
- Inputs have quiet fills, 6px corners, visible labels and a clear focused border.
  Primary controls have 44px minimum height. Do not replace values with placeholders.
- Connection details are text, not disabled inputs. Never render secret values.
- Report details use a media / context split; phone layouts stack the content.
  Fullscreen gallery keeps image controls visible and supports keyboard navigation.

## Anti-patterns

No card inside card inside card; no frame around filters; no container solely to
hold a heading. No decorative gradients, glass, glows, rounded status pills,
marketing eyebrows, ornamental animations or fake dashboard metrics. No new UI
packages solely for styling. Do not add fake imagery to a diagnostic product.
Keep data and permissions unchanged while redesigning presentation.

## Sources and interpretation

- https://github.com/Leonxlnx/taste-skill/blob/main/skills/redesign-skill/SKILL.md
- https://github.com/vercel-labs/web-interface-guidelines/blob/main/AGENTS.md
- https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- https://github.com/VoltAgent/awesome-design-md/blob/main/design-md/linear.app/DESIGN.md
- https://linear.app/docs/triage
- https://developer.android.com/develop/ui/views/layout/build-responsive-navigation

These are design references, not claims of compliance with every checklist.
Taste's main v2 skill excludes dashboards; the existing-project redesign guide
was used instead. UI/UX Pro Max's initial design-system suggestion was marketing
oriented; the subsequent internal issue-tracker search had no matching profile.
That palette/composition was rejected. The implementation uses project-specific
flat inbox decisions and the verified Flutter theming recommendations. Linear's
reference is an interpretation of its marketing site, not an official application
specification. No CSS/React animation library is added to this Flutter app.

## Verification

Review real inbox, report/gallery, Slack/Jira connected and disconnected states,
search/filter/reset behavior, long user content and phone/desktop layouts. Keep
keyboard focus, readable contrast, errors and loading visible. Dark mode is not
part of the current product and is not claimed as tested.

## Review cycle refinements

Navigation uses a menu and drawer at widths up to 600 logical pixels, a compact
rail below 900 and left-aligned labels from 900. Destinations
scroll independently of sign-out so short landscape windows remain usable.
Search, Filters and reset share a toolbar. Statuses scroll horizontally and mark
selection with an underline, weight and accessible selected state. Additional filters are
revealed by the toolbar action, without a second card or full-height accordion.

Report previews use portrait thumbnails. On phones, description and status are
followed immediately by the screenshot; attachments, Jira and diagnostics follow
the image. Desktop media receives more width than secondary context. Jira and
Slack share one connection-status component with a labeled refresh control.

Jira uses the configured project as the primary connection identity, with site
and account beneath it. Refresh preserves known content and disables busy
actions. Initial placeholders are static, neutral and match the expected content;
they have accessible loading labels and no repeating shimmer. Setup help uses
one disclosure. Account display names and masked tokens never populate credential
fields, because they are not usable authentication values.

## Composition refinements

The navigation has a compact Capture identity, a distinct Inbox destination and
a secondary Workspace group. A warm sidebar and white content surface establish
the page boundary without another rounded container. Inbox uses a 32px semibold
heading, a concise review instruction and a real filtered report count. Statuses
share one baseline. Rows use portrait previews, medium-weight descriptions and
quieter metadata; hover and focus provide feedback across the full row.

Report details put the actual tester description ahead of diagnostics, with
status directly above it. The screenshot sits on a neutral media surface while
the reading column stays white. Image corners are tighter than the dialog frame.
Settings use the same heading rhythm and separator. No fake charts, sample users,
ornamental gradients, new packages or backend changes are introduced.

The reference checklists are contextual guidance, not a requirement to add every
marketing technique. Grain, glass, parallax, stock imagery, animated typography,
cookie banners and legal footers do not address this authenticated review tool.
Applicable checks cover hierarchy, content width, states, targets, focus, mobile
input text, real counts, virtualization and consistent surfaces.
