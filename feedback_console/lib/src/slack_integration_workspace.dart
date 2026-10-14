import 'integration_connection_status.dart';
import 'package:flutter/material.dart';

import 'firebase_console_config.dart';
import 'slack_integration_repository.dart';
import 'feedback_shimmer.dart';
import 'console_section.dart';
import 'slack_message_settings_form.dart';

/// Optional Slack settings for this console's Firebase project, not Humm Hub.
class SlackIntegrationWorkspace extends StatefulWidget {
  const SlackIntegrationWorkspace({
    this.repository,
    this.config = const FirebaseConsoleConfig.fromEnvironment(),
    super.key,
  });
  final SlackIntegrationRepository? repository;
  final FirebaseConsoleConfig config;

  @override
  State<SlackIntegrationWorkspace> createState() => _SlackIntegrationWorkspaceState();
}

class _SlackIntegrationWorkspaceState extends State<SlackIntegrationWorkspace> {
  late final _repository = widget.repository ?? SlackIntegrationRepository();
  final _webhook = TextEditingController();
  SlackConnectionStatus? _status;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _run(() => _repository.checkStatus(widget.config));
  }

  @override
  void dispose() {
    _webhook.dispose();
    if (widget.repository == null) _repository.dispose();
    super.dispose();
  }

  Future<void> _run(Future<SlackIntegrationResult> Function() action, {String? success}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        case SlackIntegrationSuccess(:final status):
          _status = status;
          _webhook.clear();
        case SlackIntegrationFailure(:final message):
          _error = message;
      }
    });
    if (result is SlackIntegrationSuccess && success != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Slack integration?'),
        content: const Text('New reports will no longer notify Slack. Existing feedback is not deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _run(() => _repository.disconnect(widget.config), success: 'Slack integration removed.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connected = _status?.connected == true;
    return ConsoleSettingsPage(
      title: 'Slack notifications',
      subtitle: 'Keep your team in the loop when testers send feedback.',
      children: [
        ConsoleSection(
          title: 'Connection',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_busy && _status == null)
                Semantics(
                  label: 'Loading Slack connection',
                  child: const FeedbackThumbnailShimmer(width: double.infinity, height: 72),
                )
              else
                IntegrationConnectionStatus(
                  integration: 'Slack',
                  label: connected ? 'Connected' : 'Not connected',
                  connected: connected,
                  details: _busy ? 'Checking connection status…' : null,
                  onRefresh: _busy ? null : () => _run(() => _repository.checkStatus(widget.config)),
                ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Text(error, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              if (_status == null && _busy)
                const SizedBox.shrink()
              else if (connected) ...[
                const Text('New reports are sent to your connected Slack channel.'),
                if (_status?.lastDeliveryStatus case final delivery?) ...[
                  const SizedBox(height: 12),
                  Text('Last delivery: $delivery'),
                ],
                if (_status?.lastDeliveredAt case final date?)
                  Text(
                    'Delivered: ${MaterialLocalizations.of(context).formatMediumDate(date.toLocal())} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(date.toLocal()))}',
                  ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() => _repository.test(widget.config), success: 'Test notification sent.'),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Send test'),
                    ),
                    TextButton(onPressed: _busy ? null : _remove, child: const Text('Remove integration')),
                  ],
                ),
              ] else ...[
                Text('Where to find the webhook', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                const SelectableText(
                  '1. Open api.slack.com/apps and create an app for your workspace.\n2. Enable Incoming Webhooks.\n3. Click Add New Webhook to Workspace, choose a channel and authorize.\n4. Copy the Webhook URL and paste it below.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _webhook,
                  obscureText: true,
                  enabled: !_busy && _status != null,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Slack Webhook URL',
                    hintText: 'https://hooks.slack.com/services/T…/B…/…',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Treat this URL as a password. Only feedback administrators can save it. Connecting sends a test message; existing reports are not sent.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy || _status == null
                      ? null
                      : () =>
                            _run(() => _repository.connect(widget.config, _webhook.text), success: 'Slack connected.'),
                  child: const Text('Connect Slack'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (_status case final status?) ...[
          ConsoleSection(
            title: 'Notifications',
            subtitle: 'Customize the message your team receives.',
            child: SlackMessageSettingsForm(
              settings: status.messageSettings,
              busy: _busy,
              onSave: (settings) => _run(
                () => _repository.saveMessageSettings(widget.config, settings),
                success: 'Message settings saved.',
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        ConsoleSection(
          title: 'Help & setup',
          child: const ExpansionTile(
            title: Text('Backend setup and permissions'),
            tilePadding: EdgeInsets.zero,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Deploy the Slack services bundled with this console to your Firebase project. Enable Secret Manager API. The functions service account needs secret create/delete, version add and payload access permissions. Use a dedicated scoped role; never grant Owner or expose the webhook to reviewers. See feedback_console/doc/slack-integration.md for exact setup.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
