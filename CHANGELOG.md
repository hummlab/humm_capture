# 2.0.0

- Support synchronous and asynchronous diagnostic providers. **Migration:**
  `FeedbackLogsProvider` now returns `FutureOr<List<FeedbackLogEntry>>`; await
  direct provider calls. Existing synchronous callbacks remain accepted.
- Add opt-in bounded diagnostic buffers, persistent app-owned log storage and
  current-process Android logcat collection with explicit redaction.
- Add explicit deployment environment and optional report title fields.
- Allow hosts to disable user-selected attachments while preserving screenshots.
- Update the standalone console with adaptive inbox navigation, image gallery,
  readable diagnostic previews and Jira/Slack integration settings.
- Document Firebase onboarding and independent SDK/backend/console releases.
- Exclude local configuration and generated application builds from publication.

# 1.0.1

- Refactor feedback composer into modular components under strict file size guidelines.
- Remove internal debug logging from SDK.
- Update feedback console configuration to support dynamic and self-hosted environments.

# 1.0.0

First stable release of the backend-neutral Flutter feedback SDK under the
`humm_capture` package name.

- Correct publication-facing documentation and the public package layout.
- Document that system screenshot import is available through the host API.
- Split the default composer into focused internal widgets and rendering code.
- Add validation for normalized annotation coordinates and a widget test for
  invalid screenshots, so malformed host input cannot leave the composer in an
  infinite loading state.
- Release native image resources safely when capture or annotation rendering
  fails.

# 0.1.0-dev.3

- Close the composer after image preparation and deliver reports in the
  background instead of blocking the tester on network and backend cold starts.
- Add `FeedbackDeliveryCallbacks` for host-controlled delivery notices.
- Show default delivery notices when the host does not provide callbacks.

## 0.1.0-dev.2

- Add explicit support context for app version, build, platform, screen, locale
  and host-defined metadata.
- Add destination-agnostic `FeedbackReporter` and typed delivery results.
- Add retryable delivery failure UI in the feedback composer.
- Document host integration and the planned Hummlab Hub adapter boundary.

## 0.1.0-dev.1

- Add an initial feedback capture boundary and public data model.
- Support hidden three-finger capture and host-supplied system screenshots.
- Add freehand marker annotations with undo and clear actions.
