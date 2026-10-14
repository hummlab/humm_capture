import 'integration_connection_status.dart';
import 'package:flutter/material.dart';

import 'firebase_console_config.dart';
import 'feedback_shimmer.dart';
import 'console_section.dart';
import 'console_theme.dart';
import 'jira_integration_repository.dart';

const _muted = ConsoleColors.muted;
const _primary = ConsoleColors.accent;

class JiraIntegrationWorkspace extends StatefulWidget {
  const JiraIntegrationWorkspace({super.key});

  @override
  State<JiraIntegrationWorkspace> createState() => _JiraIntegrationWorkspaceState();
}

class _JiraIntegrationWorkspaceState extends State<JiraIntegrationWorkspace> {
  final _repository = JiraIntegrationRepository();
  final _siteUrlController = TextEditingController();
  final _projectKeyController = TextEditingController();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  JiraConnectionStatus? _status;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isSaving = false;

  static const _config = FirebaseConsoleConfig.fromEnvironment();

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _siteUrlController.dispose();
    _projectKeyController.dispose();
    _emailController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _repository.checkStatus(_config);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      switch (result) {
        case JiraIntegrationSuccess(:final value):
          _status = value;
          _applyStatus(value);
          _errorMessage = null;
        case JiraIntegrationFailure(:final message):
          _errorMessage = message;
      }
    });
  }

  Future<void> _saveConfiguration() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final result = await _repository.configure(
      config: _config,
      siteUrl: _siteUrlController.text,
      projectKey: _projectKeyController.text,
      accountEmail: _emailController.text,
      apiToken: _tokenController.text,
    );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      switch (result) {
        case JiraIntegrationSuccess(:final value):
          _status = value;
          _applyStatus(value);
          _tokenController.clear();
        case JiraIntegrationFailure(:final message):
          _errorMessage = message;
      }
    });
  }

  void _applyStatus(JiraConnectionStatus status) {
    if (status.siteUrl case final siteUrl?) _siteUrlController.text = siteUrl;
    if (status.projectKey case final projectKey?) _projectKeyController.text = projectKey;
    // The backend returns a display label, not an account email or API token.
    // Leave access fields for explicit input rather than fabricating credentials.
  }

  Future<void> _removeConfiguration() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Jira integration?'),
        content: const Text(
          'The saved Jira account email and API token will be removed from Google Secret Manager. '
          'Creating Jira issues from feedback will stop until a new connection is configured.',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Remove integration')),
        ],
      ),
    );
    if (shouldRemove != true || !mounted) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    final result = await _repository.remove(_config);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      switch (result) {
        case JiraIntegrationSuccess(:final value):
          _status = value;
          _tokenController.clear();
        case JiraIntegrationFailure(:final message):
          _errorMessage = message;
      }
    });
  }

  @override
  Widget build(BuildContext context) => ConsoleSettingsPage(
    title: 'Jira',
    subtitle: 'Turn a reviewed report into a task in your team’s project.',
    children: [
      if (_isLoading && _status == null)
        const _JiraIntegrationLoading()
      else ...[
        _ConnectionStatusCard(status: _status, isLoading: _isLoading, onRefresh: _loadStatus),
        if (_status?.isConnected == true) ...[
          const SizedBox(height: 20),
          _SavedJiraConnection(status: _status!),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: _ConnectedIntegrationActions(isSaving: _isSaving || _isLoading, onRemove: _removeConfiguration),
          ),
        ] else ...[
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: _ConnectionForm(
                isSaving: _isSaving || _isLoading,
                siteUrlController: _siteUrlController,
                projectKeyController: _projectKeyController,
                emailController: _emailController,
                tokenController: _tokenController,
                onConnect: _saveConfiguration,
              ),
            ),
          ),
        ],
      ],
      if (_errorMessage case final message?) ...[
        const SizedBox(height: 20),
        Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
      const SizedBox(height: 28),
      const Divider(height: 1),
      const SizedBox(height: 16),
      _ProgressiveHelp(connected: _status?.isConnected == true),
    ],
  );
}

class _SavedJiraConnection extends StatelessWidget {
  const _SavedJiraConnection({required this.status});
  final JiraConnectionStatus status;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (status.siteUrl case final site?) SelectableText(site, style: const TextStyle(color: _muted)),
      if (status.accountLabel case final account?) ...[
        const SizedBox(height: 4),
        SelectableText(account, style: const TextStyle(color: _muted)),
      ],
      const SizedBox(height: 12),
      const Text(
        'Credentials stored securely · Issues are created only when requested.',
        style: TextStyle(color: _muted, fontSize: 12),
      ),
    ],
  );
}

class _ConnectionForm extends StatelessWidget {
  const _ConnectionForm({
    required this.isSaving,
    required this.siteUrlController,
    required this.projectKeyController,
    required this.emailController,
    required this.tokenController,
    required this.onConnect,
  });

  final bool isSaving;
  final TextEditingController siteUrlController;
  final TextEditingController projectKeyController;
  final TextEditingController emailController;
  final TextEditingController tokenController;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('Issue destination', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),
      _Field(label: 'Jira site', controller: siteUrlController, hintText: 'https://your-team.atlassian.net'),
      const SizedBox(height: 14),
      _Field(label: 'Project key', controller: projectKeyController, hintText: 'GF'),
      const SizedBox(height: 28),
      Text('Account access', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      const Text('Use an account that can create issues in this project.', style: TextStyle(color: _muted)),
      const SizedBox(height: 16),
      _Field(label: 'Atlassian account email', controller: emailController, hintText: 'name@company.com'),
      const SizedBox(height: 14),
      _Field(
        label: 'Jira API token',
        controller: tokenController,
        hintText: 'Paste a token created in Atlassian',
        obscureText: true,
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: isSaving ? null : onConnect,
        icon: isSaving
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.lock_outline),
        label: Text(isSaving ? 'Checking Jira…' : 'Connect Jira'),
      ),
    ],
  );
}

class _ConnectedIntegrationActions extends StatelessWidget {
  const _ConnectedIntegrationActions({required this.isSaving, required this.onRemove});

  final bool isSaving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: isSaving ? null : onRemove,
    icon: const Icon(Icons.link_off_rounded, size: 16),
    label: Text(isSaving ? 'Updating connection…' : 'Disconnect Jira'),
    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class _ProgressiveHelp extends StatelessWidget {
  const _ProgressiveHelp({required this.connected});
  final bool connected;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      if (!connected) const _HelpDisclosure(title: 'Find your Jira connection details', child: _ConnectionHelp()),
      const _HelpDisclosure(title: 'Permissions and credentials', child: _IntegrationScope()),
      if (!connected) const _HelpDisclosure(title: 'Backend setup', child: _SetupGuide()),
    ],
  );
}

class _HelpDisclosure extends StatelessWidget {
  const _HelpDisclosure({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      childrenPadding: const EdgeInsets.only(bottom: 16),
      children: <Widget>[child],
    ),
  );
}

class _SetupGuide extends StatelessWidget {
  const _SetupGuide();

  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _GuideStep(
        number: '1',
        title: 'Prepare the feedback backend',
        description:
            'Deploy the feedback Cloud Function in the same Firebase project as this panel. '
            'The panel uses this backend to check the connection and store Jira credentials securely.',
      ),
      _GuideStep(
        number: '2',
        title: 'Give the function access to Secret Manager',
        description:
            'In Google Cloud Console → IAM, assign a custom role to the Cloud Functions service account. '
            'It needs only: secretmanager.secrets.create, secretmanager.secrets.get, '
            'secretmanager.versions.add, secretmanager.versions.access and secretmanager.secrets.delete.',
      ),
      _GuideStep(
        number: '3',
        title: 'Prepare a least-privileged Jira account',
        description:
            'Use a dedicated account where possible. In the selected project, grant Browse projects, Create issues, Edit issues '
            'and Create attachments. Do not grant Jira administrator, project administrator, transition or delete '
            'permissions just for feedback.',
      ),
      _GuideStep(
        number: '4',
        title: 'Create an Atlassian API token',
        description:
            'In Atlassian account security, create an API token without scopes for that account. This integration supports '
            'Jira Cloud sites with a Task issue type and enabled attachments. The account email entered below must own '
            'the token and have access to the selected Jira project.',
      ),
      _GuideStep(
        number: '5',
        title: 'Connect and verify',
        description:
            'Paste the account email and token, then select Connect Jira. The backend verifies the account and project '
            'before it stores a new secret version. The token is never shown in the panel again.',
      ),
    ],
  );
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.number, required this.title, required this.description});

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: ConsoleColors.wash, shape: BoxShape.circle),
          child: Text(
            number,
            style: const TextStyle(color: _primary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              SelectionArea(
                child: Text(description, style: const TextStyle(color: _muted, height: 1.35)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ConnectionHelp extends StatelessWidget {
  const _ConnectionHelp();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: _primary, width: 2)),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 14),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Text('Where to find each value', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 10),
            _HelpItem(
              label: 'Jira site',
              description: 'Copy the base address from your browser, for example https://your-team.atlassian.net.',
            ),
            _HelpItem(
              label: 'Project key',
              description: 'Use the short code in the project URL: /projects/GF means the value is GF, not GF35.',
            ),
            _HelpItem(
              label: 'Atlassian account email',
              description:
                  'Use the email of the Atlassian account that owns the API token and can create issues in the project.',
            ),
            _HelpItem(
              label: 'API token',
              description:
                  'Open id.atlassian.com/manage-profile/security/api-tokens → Create API token → copy it once → paste it below.',
            ),
          ],
        ),
      ),
    ),
  );
}

class _IntegrationScope extends StatelessWidget {
  const _IntegrationScope();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: ConsoleColors.wash, borderRadius: BorderRadius.circular(12)),
    child: const Padding(
      padding: EdgeInsets.all(16),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('What this connection changes', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text(
              'A permitted console user can create one Jira issue for each feedback report. When an issue is created, a New report moves to In review. '
              'The issue receives the tester description, technical context and screenshot. Nothing is created automatically, and Jira issues are not edited, moved or deleted by this integration.',
              style: TextStyle(color: _muted, height: 1.4),
            ),
            SizedBox(height: 14),
            Text('How credentials are handled', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text(
              'The API token is sent once over HTTPS to this Firebase project. It is stored in Google Secret Manager, never displayed in the panel, '
              'and is used only by the feedback backend. Remove the connection to delete the saved credentials and stop future Jira creation.',
              style: TextStyle(color: _muted, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HelpItem extends StatelessWidget {
  const _HelpItem({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.arrow_forward_rounded, size: 16, color: _primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(color: _muted, height: 1.4),
              children: <InlineSpan>[
                TextSpan(
                  text: '$label — ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _ConnectionStatusCard extends StatelessWidget {
  const _ConnectionStatusCard({required this.status, required this.isLoading, required this.onRefresh});

  final JiraConnectionStatus? status;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final connected = status?.isConnected == true;
    final configured = status?.isConfigured == true;
    final label = connected ? 'Connected' : (configured ? 'Needs attention' : 'Not connected');
    final details = connected
        ? '${status?.projectName ?? status?.projectKey ?? 'Jira project'} · ${status?.accountLabel ?? 'Connected account'}'
        : (status?.message ?? 'Add the Jira site, project key and an API token to enable issue creation.');
    return IntegrationConnectionStatus(
      integration: 'Jira',
      label: connected ? (status?.projectName ?? status?.projectKey ?? 'Jira project') : label,
      connected: connected,
      details: isLoading ? 'Checking connection status…' : (connected ? 'Connected to Jira' : details),
      onRefresh: isLoading ? null : onRefresh,
    );
  }
}

class _JiraIntegrationLoading extends StatelessWidget {
  const _JiraIntegrationLoading();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading Jira connection',
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FeedbackThumbnailShimmer(width: 180, height: 20),
        SizedBox(height: 12),
        FeedbackThumbnailShimmer(width: 240, height: 14),
        SizedBox(height: 8),
        FeedbackThumbnailShimmer(width: 160, height: 14),
      ],
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, required this.hintText, this.obscureText = false});

  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 7),
      TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(hintText: hintText),
      ),
    ],
  );
}
