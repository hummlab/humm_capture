import 'package:flutter/material.dart';

import 'external_url_opener.dart';
import 'feedback_report.dart';
import 'feedback_report_deep_link.dart';
import 'feedback_attachments.dart';
import 'feedback_log_preview.dart';
import 'console_section.dart';
import 'console_theme.dart';
import 'inbox_status_tabs.dart';
import 'workspace_navigation.dart';
import 'feedback_image_gallery.dart';
import 'feedback_repository.dart';
import 'feedback_shimmer.dart';
import 'jira_issue_repository.dart';
import 'jira_integration_workspace.dart';
import 'slack_integration_workspace.dart';
import 'firebase_console_config.dart';

const _surface = ConsoleColors.surface;
const _ink = ConsoleColors.ink;
const _muted = ConsoleColors.muted;
const _primary = ConsoleColors.accent;

void _openExternalUrl(Uri uri) {
  openExternalUrl(uri);
}

enum _WorkspaceDestination { inbox, jira, slack, access }

enum _FeedbackDateFilter { today, yesterday, last7Days }

String _dateFilterLabel(_FeedbackDateFilter filter) => switch (filter) {
  _FeedbackDateFilter.today => 'Today',
  _FeedbackDateFilter.yesterday => 'Yesterday',
  _FeedbackDateFilter.last7Days => 'Last 7 days',
};

String _versionFilterValue(FeedbackReport report) => switch (report.buildNumber) {
  final build? when build.isNotEmpty => '${report.appVersion} ($build)',
  _ => report.appVersion,
};

bool _matchesDateFilter(DateTime? value, _FeedbackDateFilter? filter) {
  if (filter == null || value == null) return true;
  final startOfToday = DateUtils.dateOnly(DateTime.now());
  final localValue = value.toLocal();
  final start = switch (filter) {
    _FeedbackDateFilter.today => startOfToday,
    _FeedbackDateFilter.yesterday => startOfToday.subtract(const Duration(days: 1)),
    _FeedbackDateFilter.last7Days => startOfToday.subtract(const Duration(days: 6)),
  };
  final end = filter == _FeedbackDateFilter.yesterday ? startOfToday : startOfToday.add(const Duration(days: 1));
  return !localValue.isBefore(start) && localValue.isBefore(end);
}

class FeedbackWorkspace extends StatefulWidget {
  const FeedbackWorkspace({this.config = const FirebaseConsoleConfig.fromEnvironment(), super.key});
  final FirebaseConsoleConfig config;

  @override
  State<FeedbackWorkspace> createState() => _FeedbackWorkspaceState();
}

class _FeedbackWorkspaceState extends State<FeedbackWorkspace> {
  final _repository = FeedbackRepository();
  _WorkspaceDestination _destination = _WorkspaceDestination.inbox;
  FeedbackStatus? _status;
  _FeedbackDateFilter? _dateFilter;
  String? _platform;
  String? _environment;
  String? _version;
  String _query = '';

  @override
  Widget build(BuildContext context) => StreamBuilder<FeedbackMember?>(
    stream: _repository.watchCurrentMember(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _WorkspaceFailure(error: snapshot.error);
      if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      final canManageAccess = snapshot.data?.canManageFeedbackAccess ?? false;
      final canCreateJiraTasks = canManageAccess || (snapshot.data?.canCreateJiraTasks ?? false);
      final destination = canManageAccess ? _destination : _WorkspaceDestination.inbox;
      return Scaffold(
        backgroundColor: _surface,
        appBar: MediaQuery.sizeOf(context).width <= 600
            ? AppBar(title: const Text('Capture Console'), toolbarHeight: 52)
            : null,
        drawer: MediaQuery.sizeOf(context).width <= 600
            ? Drawer(
                child: WorkspaceNavigation(
                  selectedIndex: destination.index,
                  canManageAccess: canManageAccess,
                  expanded: true,
                  onSelected: (index) {
                    setState(() => _destination = _WorkspaceDestination.values[index]);
                    Navigator.pop(context);
                  },
                ),
              )
            : null,
        body: Row(
          children: <Widget>[
            if (MediaQuery.sizeOf(context).width > 600) ...[
              WorkspaceNavigation(
                selectedIndex: destination.index,
                canManageAccess: canManageAccess,
                expanded: MediaQuery.sizeOf(context).width >= 900,
                onSelected: (index) => setState(() => _destination = _WorkspaceDestination.values[index]),
              ),
              const VerticalDivider(width: 1),
            ],
            Expanded(
              child: SafeArea(
                child: switch (destination) {
                  _WorkspaceDestination.inbox => FeedbackReportDeepLink(
                    reports: _repository.watchReports(),
                    onOpen: (report) => showDialog<void>(
                      context: context,
                      builder: (context) => _FeedbackDetailDialog(
                        reports: [report],
                        initialReportIndex: 0,
                        repository: _repository,
                        canDelete: canManageAccess,
                        canCreateJiraTasks: canCreateJiraTasks,
                      ),
                    ),
                    child: _InboxWorkspace(
                      repository: _repository,
                      canDelete: canManageAccess,
                      canCreateJiraTasks: canCreateJiraTasks,
                      query: _query,
                      status: _status,
                      dateFilter: _dateFilter,
                      platform: _platform,
                      environment: _environment,
                      version: _version,
                      onQueryChanged: (query) => setState(() => _query = query),
                      onStatusChanged: (status) => setState(() => _status = status),
                      onDateFilterChanged: (filter) => setState(() => _dateFilter = filter),
                      onPlatformChanged: (platform) => setState(() => _platform = platform),
                      onEnvironmentChanged: (value) => setState(() => _environment = value),
                      onVersionChanged: (version) => setState(() => _version = version),
                    ),
                  ),
                  _WorkspaceDestination.jira => const JiraIntegrationWorkspace(),
                  _WorkspaceDestination.slack => SlackIntegrationWorkspace(config: widget.config),
                  _WorkspaceDestination.access => _AccessWorkspace(repository: _repository),
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _InboxWorkspace extends StatelessWidget {
  const _InboxWorkspace({
    required this.repository,
    required this.canDelete,
    required this.canCreateJiraTasks,
    required this.query,
    required this.status,
    required this.dateFilter,
    required this.platform,
    required this.environment,
    required this.version,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onDateFilterChanged,
    required this.onPlatformChanged,
    required this.onEnvironmentChanged,
    required this.onVersionChanged,
  });

  final FeedbackRepository repository;
  final bool canDelete;
  final bool canCreateJiraTasks;
  final String query;
  final FeedbackStatus? status;
  final _FeedbackDateFilter? dateFilter;
  final String? platform;
  final String? environment;
  final String? version;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<FeedbackStatus?> onStatusChanged;
  final ValueChanged<_FeedbackDateFilter?> onDateFilterChanged;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onEnvironmentChanged;
  final ValueChanged<String?> onVersionChanged;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<FeedbackReport>>(
    stream: repository.watchReports(),
    builder: (context, snapshot) {
      if (snapshot.hasError) return _WorkspaceFailure(error: snapshot.error);
      if (!snapshot.hasData) return const _InboxLoading();
      final reports = snapshot.data!;
      final visibleReports = reports
          .where((report) {
            final matchesStatus = status == null || report.status == status;
            final matchesDate = _matchesDateFilter(report.capturedAt ?? report.createdAt, dateFilter);
            final matchesPlatform = platform == null || report.platform == platform;
            final matchesVersion = version == null || _versionFilterValue(report) == version;
            final normalizedQuery = query.trim().toLowerCase();
            final matchesQuery =
                normalizedQuery.isEmpty ||
                report.message.toLowerCase().contains(normalizedQuery) ||
                report.applicationName.toLowerCase().contains(normalizedQuery);
            return matchesStatus &&
                matchesDate &&
                matchesPlatform &&
                matchesVersion &&
                matchesQuery &&
                (environment == null || report.environment == environment);
          })
          .toList(growable: false);
      return _WorkspacePage(
        title: 'Inbox',
        subtitle: 'Review what your testers see. Turn feedback into fixes.',
        trailing: MediaQuery.sizeOf(context).width < 700
            ? const SizedBox.shrink()
            : Text(
                '${visibleReports.length} ${visibleReports.length == 1 ? 'report' : 'reports'}',
                style: const TextStyle(color: _muted, fontSize: 13),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final results = _FeedbackResults(
                    reports: visibleReports,
                    repository: repository,
                    canDelete: canDelete,
                    canCreateJiraTasks: canCreateJiraTasks,
                    hasFilter:
                        query.isNotEmpty ||
                        status != null ||
                        dateFilter != null ||
                        platform != null ||
                        version != null ||
                        environment != null,
                    onClearFilters: () {
                      onQueryChanged('');
                      onStatusChanged(null);
                      onDateFilterChanged(null);
                      onPlatformChanged(null);
                      onEnvironmentChanged(null);
                      onVersionChanged(null);
                    },
                  );
                  final filters = _InboxFilterPanel(
                    reports: reports,
                    resultCount: visibleReports.length,
                    query: query,
                    status: status,
                    dateFilter: dateFilter,
                    platform: platform,
                    environment: environment,
                    version: version,
                    onQueryChanged: onQueryChanged,
                    onStatusChanged: onStatusChanged,
                    onDateFilterChanged: onDateFilterChanged,
                    onPlatformChanged: onPlatformChanged,
                    onEnvironmentChanged: onEnvironmentChanged,
                    onVersionChanged: onVersionChanged,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.55),
                        child: SingleChildScrollView(child: filters),
                      ),
                      const Divider(height: 1),
                      Expanded(child: results),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _WorkspacePage extends StatelessWidget {
  const _WorkspacePage({required this.title, required this.subtitle, required this.trailing, required this.child});

  final String title;
  final String subtitle;
  final Widget trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1280),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.sizeOf(context).width < 700 ? 16 : 32,
          vertical: MediaQuery.sizeOf(context).width < 700 ? 16 : 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: _ink,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle, style: const TextStyle(color: _muted)),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
            const SizedBox(height: 28),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class _InboxFilterPanel extends StatefulWidget {
  const _InboxFilterPanel({
    required this.reports,
    required this.resultCount,
    required this.query,
    required this.status,
    required this.dateFilter,
    required this.platform,
    required this.environment,
    required this.version,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onDateFilterChanged,
    required this.onPlatformChanged,
    required this.onEnvironmentChanged,
    required this.onVersionChanged,
  });

  final List<FeedbackReport> reports;
  final int resultCount;
  final String query;
  final FeedbackStatus? status;
  final _FeedbackDateFilter? dateFilter;
  final String? platform;
  final String? environment;
  final String? version;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<FeedbackStatus?> onStatusChanged;
  final ValueChanged<_FeedbackDateFilter?> onDateFilterChanged;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onEnvironmentChanged;
  final ValueChanged<String?> onVersionChanged;

  @override
  State<_InboxFilterPanel> createState() => _InboxFilterPanelState();
}

class _InboxFilterPanelState extends State<_InboxFilterPanel> {
  bool _showFilters = false;
  @override
  Widget build(BuildContext context) {
    final reports = widget.reports;
    final query = widget.query;
    final status = widget.status;
    final dateFilter = widget.dateFilter;
    final platform = widget.platform;
    final environment = widget.environment;
    final version = widget.version;
    final onQueryChanged = widget.onQueryChanged;
    final onStatusChanged = widget.onStatusChanged;
    final onDateFilterChanged = widget.onDateFilterChanged;
    final onPlatformChanged = widget.onPlatformChanged;
    final onEnvironmentChanged = widget.onEnvironmentChanged;
    final onVersionChanged = widget.onVersionChanged;

    final platforms = reports.map((r) => r.platform).where((v) => v.isNotEmpty).toSet().toList()..sort();
    final versions = reports.map(_versionFilterValue).where((v) => v.isNotEmpty).toSet().toList()..sort();
    final activeCount = [dateFilter, platform, environment, version].where((v) => v != null).length;
    void clear() {
      onQueryChanged('');
      onStatusChanged(null);
      onDateFilterChanged(null);
      onPlatformChanged(null);
      onEnvironmentChanged(null);
      onVersionChanged(null);
    }

    return ConsoleSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _InboxSearch(query: query, onChanged: onQueryChanged),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(() => _showFilters = !_showFilters),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(activeCount == 0 ? 'Filters' : 'Filters · $activeCount'),
              ),
              if (query.isNotEmpty || status != null || activeCount > 0)
                IconButton(tooltip: 'Clear filters', onPressed: clear, icon: const Icon(Icons.filter_alt_off_outlined)),
            ],
          ),
          const SizedBox(height: 8),
          InboxStatusTabs(reports: reports, selected: status, onSelected: onStatusChanged),
          if (_showFilters)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth < 500 ? constraints.maxWidth : 190,
                      child: _PanelFilterMenu<_FeedbackDateFilter?>(
                        label: 'Reported',
                        value: dateFilter == null ? 'Any time' : _dateFilterLabel(dateFilter),
                        onSelected: onDateFilterChanged,
                        items: [
                          PopupMenuItem(
                            value: null,
                            onTap: () => onDateFilterChanged(null),
                            child: const Text('Any time'),
                          ),
                          for (final f in _FeedbackDateFilter.values)
                            PopupMenuItem(value: f, child: Text(_dateFilterLabel(f))),
                        ],
                      ),
                    ),
                    for (final spec in [
                      ('Platform', platform, platforms, onPlatformChanged),
                      ('Environment', environment, ['dev', 'stage', 'prod'], onEnvironmentChanged),
                      ('Version', version, versions, onVersionChanged),
                    ])
                      SizedBox(
                        width: constraints.maxWidth < 500 ? constraints.maxWidth : 190,
                        child: _PanelFilterMenu<String?>(
                          label: spec.$1,
                          value: spec.$2 ?? 'All',
                          onSelected: spec.$4,
                          items: [
                            PopupMenuItem(value: null, onTap: () => spec.$4(null), child: const Text('All')),
                            for (final v in spec.$3) PopupMenuItem(value: v, child: Text(v)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InboxSearch extends StatefulWidget {
  const _InboxSearch({required this.query, required this.onChanged});
  final String query;
  final ValueChanged<String> onChanged;
  @override
  State<_InboxSearch> createState() => _InboxSearchState();
}

class _InboxSearchState extends State<_InboxSearch> {
  late final _controller = TextEditingController(text: widget.query);
  @override
  void didUpdateWidget(covariant _InboxSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.query) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    style: TextStyle(fontSize: MediaQuery.sizeOf(context).width <= 600 ? 16 : 14),
    onChanged: widget.onChanged,
    decoration: InputDecoration(
      hintText: 'Search feedback…',
      filled: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      prefixIcon: const Icon(Icons.search),
      suffixIcon: widget.query.isEmpty
          ? null
          : IconButton(tooltip: 'Clear search', onPressed: () => widget.onChanged(''), icon: const Icon(Icons.close)),
    ),
  );
}

class _PanelFilterMenu<T> extends StatelessWidget {
  const _PanelFilterMenu({required this.label, required this.value, required this.items, required this.onSelected});

  final String label;
  final String value;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    onSelected: onSelected,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    itemBuilder: (_) => items,
    child: InputDecorator(
      decoration: const InputDecoration(
        suffixIcon: Icon(Icons.keyboard_arrow_down_rounded, color: _muted),
      ).copyWith(labelText: label),
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}

class _FeedbackResults extends StatelessWidget {
  const _FeedbackResults({
    required this.reports,
    required this.repository,
    required this.canDelete,
    required this.canCreateJiraTasks,
    required this.hasFilter,
    required this.onClearFilters,
  });

  final List<FeedbackReport> reports;
  final FeedbackRepository repository;
  final bool canDelete;
  final bool canCreateJiraTasks;
  final bool hasFilter;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) return _EmptyReports(hasFilter: hasFilter, onClearFilters: onClearFilters);
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: reports.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => _FeedbackCard(
        report: reports[index],
        reports: reports,
        reportIndex: index,
        repository: repository,
        canDelete: canDelete,
        canCreateJiraTasks: canCreateJiraTasks,
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.report,
    required this.reports,
    required this.reportIndex,
    required this.repository,
    required this.canDelete,
    required this.canCreateJiraTasks,
  });

  final FeedbackReport report;
  final List<FeedbackReport> reports;
  final int reportIndex;
  final FeedbackRepository repository;
  final bool canDelete;
  final bool canCreateJiraTasks;

  void _openDetails(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => _FeedbackDetailDialog(
        reports: reports,
        initialReportIndex: reportIndex,
        repository: repository,
        canDelete: canDelete,
        canCreateJiraTasks: canCreateJiraTasks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Open feedback details',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: ConsoleColors.wash,
        focusColor: ConsoleColors.wash,
        onTap: () => _openDetails(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 540;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: compact ? 44 : 48,
                    height: compact ? 68 : 72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _FeedbackScreenshotPreview(report: report, repository: repository),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.message.isEmpty ? 'No description' : report.message,
                          maxLines: compact ? 3 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500, height: 1.4),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${report.applicationName} · ${report.environment ?? 'Unspecified'} · ${report.platform}',
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _dateTimeLabel(context, report.capturedAt ?? report.createdAt),
                              style: const TextStyle(color: _muted, fontSize: 12),
                            ),
                            if (compact) _FeedbackStatusMenu(report: report, repository: repository),
                            if (report.attachments.isNotEmpty)
                              Text(
                                '${report.attachments.length} attachments',
                                style: const TextStyle(color: _muted, fontSize: 12),
                              ),
                            if (report.jiraIssueKey case final issueKey?)
                              _JiraIssueLink(issueKey: issueKey, issueUrl: report.jiraIssueUrl),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 24),
                    _FeedbackStatusMenu(report: report, repository: repository),
                    const SizedBox(width: 12),
                    const Icon(Icons.chevron_right, size: 18, color: _muted),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _FeedbackScreenshotPreview extends StatefulWidget {
  const _FeedbackScreenshotPreview({required this.report, required this.repository, this.fit = BoxFit.contain});

  final FeedbackReport report;
  final FeedbackRepository repository;
  final BoxFit fit;

  @override
  State<_FeedbackScreenshotPreview> createState() => _FeedbackScreenshotPreviewState();
}

class _FeedbackScreenshotPreviewState extends State<_FeedbackScreenshotPreview> {
  late Future<String?> _screenshotUrl;

  @override
  void initState() {
    super.initState();
    _screenshotUrl = widget.repository.screenshotUrlFor(widget.report);
  }

  @override
  void didUpdateWidget(covariant _FeedbackScreenshotPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.screenshotPath != widget.report.screenshotPath) {
      _screenshotUrl = widget.repository.screenshotUrlFor(widget.report);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: ColoredBox(
      color: ConsoleColors.wash,
      child: FutureBuilder<String?>(
        future: _screenshotUrl,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const FeedbackThumbnailShimmer(width: double.infinity, height: double.infinity);
          }
          final url = snapshot.data;
          if (url == null) return const _ThumbnailFallback();
          return Image.network(
            url,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const _ThumbnailFallback(),
          );
        },
      ),
    ),
  );
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports({required this.hasFilter, required this.onClearFilters});

  final bool hasFilter;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(hasFilter ? 'No matching feedback' : 'No feedback yet', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          hasFilter
              ? 'Change the search phrase or status to see other reports.'
              : 'Reports will appear here after the first tester sends feedback from a connected application.',
          style: const TextStyle(color: _muted),
        ),
        if (hasFilter) ...<Widget>[
          const SizedBox(height: 8),
          TextButton(onPressed: onClearFilters, child: const Text('Clear filters')),
        ],
      ],
    ),
  );
}

class _InboxLoading extends StatelessWidget {
  const _InboxLoading();

  @override
  Widget build(BuildContext context) => _WorkspacePage(
    title: 'Inbox',
    subtitle: 'Review what your testers see. Turn feedback into fixes.',
    trailing: const SizedBox.shrink(),
    child: ListView.separated(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(vertical: 4),
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 88, endIndent: 20),
      itemBuilder: (context, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            FeedbackThumbnailShimmer(width: 48, height: 72),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FeedbackThumbnailShimmer(width: 220, height: 16),
                  SizedBox(height: 10),
                  FeedbackThumbnailShimmer(width: 160, height: 12),
                  SizedBox(height: 8),
                  FeedbackThumbnailShimmer(width: 96, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FeedbackStatusMenu extends StatelessWidget {
  const _FeedbackStatusMenu({required this.report, required this.repository});

  final FeedbackReport report;
  final FeedbackRepository repository;

  @override
  Widget build(BuildContext context) => PopupMenuButton<FeedbackStatus>(
    tooltip: 'Change status',
    onSelected: (status) => repository.updateStatus(report: report, status: status),
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    itemBuilder: (context) => FeedbackStatus.values
        .map(
          (status) => PopupMenuItem(
            value: status,
            child: Row(
              children: <Widget>[
                Icon(status == report.status ? Icons.check_rounded : Icons.circle_outlined, size: 18),
                const SizedBox(width: 8),
                Text(status.label),
              ],
            ),
          ),
        )
        .toList(growable: false),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StatusBadge(status: report.status),
        const SizedBox(width: 4),
        const Icon(Icons.keyboard_arrow_down_rounded, color: _muted, size: 18),
      ],
    ),
  );
}

class _JiraIssueLink extends StatelessWidget {
  const _JiraIssueLink({required this.issueKey, this.issueUrl});

  final String issueKey;
  final String? issueUrl;

  @override
  Widget build(BuildContext context) {
    final url = Uri.tryParse(issueUrl ?? '');
    if (url == null || !url.hasScheme) return _JiraIssueLabel(issueKey: issueKey);
    return Tooltip(
      message: 'Open $issueKey in Jira',
      child: _JiraIssueLabel(issueKey: issueKey, onTap: () => _openExternalUrl(url)),
    );
  }
}

class _JiraIssueLabel extends StatelessWidget {
  const _JiraIssueLabel({required this.issueKey, this.onTap});

  final String issueKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.open_in_new_rounded, size: 13, color: _primary),
            const SizedBox(width: 4),
            Text(
              issueKey,
              style: const TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: ConsoleColors.wash,
    child: Center(child: Icon(Icons.image_outlined, color: _muted)),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final FeedbackStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      FeedbackStatus.newReport => (const Color(0xFFE8EFFF), const Color(0xFF194DAB)),
      FeedbackStatus.inReview => (const Color(0xFFFFF2D9), const Color(0xFF855C00)),
      FeedbackStatus.resolved => (const Color(0xFFE6F5EB), const Color(0xFF277A48)),
      FeedbackStatus.rejected => (const Color(0xFFFFE9E7), const Color(0xFFB3261E)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: colors.$2, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            status.label,
            style: TextStyle(color: colors.$2, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _FeedbackDetailDialog extends StatefulWidget {
  const _FeedbackDetailDialog({
    required this.reports,
    required this.initialReportIndex,
    required this.repository,
    required this.canDelete,
    required this.canCreateJiraTasks,
  });

  final List<FeedbackReport> reports;
  final int initialReportIndex;
  final FeedbackRepository repository;
  final bool canDelete;
  final bool canCreateJiraTasks;

  @override
  State<_FeedbackDetailDialog> createState() => _FeedbackDetailDialogState();
}

class _FeedbackDetailDialogState extends State<_FeedbackDetailDialog> {
  final _jiraIssueRepository = JiraIssueRepository();
  late int _selectedReportIndex;
  bool _isCreatingJiraIssue = false;
  String? _jiraError;
  JiraIssueCreationSuccess? _createdJiraIssue;

  FeedbackReport get _report => widget.reports[_selectedReportIndex];

  @override
  void initState() {
    super.initState();
    _selectedReportIndex = widget.initialReportIndex;
  }

  void _selectReport(int index) {
    if (index < 0 || index >= widget.reports.length) return;
    setState(() {
      _selectedReportIndex = index;
      _isCreatingJiraIssue = false;
      _jiraError = null;
      _createdJiraIssue = null;
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 700 ? 8 : 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 1360,
        maxHeight: (MediaQuery.sizeOf(context).height - 48).clamp(0.0, 1000.0).toDouble(),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 700 ? 16 : 28, 20, 16, 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Feedback report',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_report.applicationName} · ${_dateTimeLabel(context, _report.capturedAt ?? _report.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted),
                      ),
                    ],
                  ),
                ),
                if (widget.reports.length > 1) ...<Widget>[
                  IconButton(
                    tooltip: 'Previous feedback',
                    onPressed: _selectedReportIndex == 0 ? null : () => _selectReport(_selectedReportIndex - 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text(
                    '${_selectedReportIndex + 1} of ${widget.reports.length}',
                    style: const TextStyle(color: _muted),
                  ),
                  IconButton(
                    tooltip: 'Next feedback',
                    onPressed: _selectedReportIndex == widget.reports.length - 1
                        ? null
                        : () => _selectReport(_selectedReportIndex + 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                  const SizedBox(width: 8),
                ],
                if (widget.canDelete)
                  PopupMenuButton<String>(
                    tooltip: 'More actions',
                    onSelected: (value) {
                      if (value == 'delete') _confirmDelete();
                    },
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    itemBuilder: (context) => const <PopupMenuEntry<String>>[
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Color(0xFFB3261E)),
                          title: Text('Delete feedback', style: TextStyle(color: Color(0xFFB3261E))),
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
                const SizedBox(width: 4),
                IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidebar = _FeedbackDetailSidebar(
                  report: _report,
                  repository: widget.repository,
                  canCreateJiraTasks: widget.canCreateJiraTasks,
                  isCreatingJiraIssue: _isCreatingJiraIssue,
                  jiraError: _jiraError,
                  createdJiraIssue: _createdJiraIssue,
                  onCreateJiraIssue: _createJiraIssue,
                  inlineScreenshot: constraints.maxWidth < 760,
                );
                final image = _DetailScreenshot(report: _report, repository: widget.repository);
                if (constraints.maxWidth < 760) {
                  return ListView(padding: const EdgeInsets.all(16), children: [sidebar]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: ColoredBox(
                        color: ConsoleColors.canvas,
                        child: Padding(padding: const EdgeInsets.all(24), child: image),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: sidebar),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _confirmDelete() async {
    final navigator = Navigator.of(context);
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete feedback?'),
        content: const Text('The report and its private screenshot will be permanently deleted.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    await widget.repository.deleteReport(_report);
    if (mounted) navigator.pop();
  }

  Future<void> _createJiraIssue() async {
    final draft = await showDialog<_JiraTaskDraft>(
      context: context,
      builder: (context) => _JiraSummaryDialog(report: _report),
    );
    if (draft == null || !mounted) return;
    setState(() {
      _isCreatingJiraIssue = true;
      _jiraError = null;
    });
    final result = await _jiraIssueRepository.createFor(
      report: _report,
      summary: draft.summary,
      includeAttachments: draft.includeAttachments,
    );
    if (!mounted) return;
    setState(() {
      _isCreatingJiraIssue = false;
      switch (result) {
        case final JiraIssueCreationSuccess success:
          _createdJiraIssue = success;
          _jiraError = success.warning;
        case JiraIssueCreationFailure(:final message):
          _jiraError = message;
      }
    });
  }
}

class _JiraSummaryDialog extends StatefulWidget {
  const _JiraSummaryDialog({required this.report});

  final FeedbackReport report;

  @override
  State<_JiraSummaryDialog> createState() => _JiraSummaryDialogState();
}

class _JiraSummaryDialogState extends State<_JiraSummaryDialog> {
  late final TextEditingController _controller;
  bool _includeAttachments = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.report.referenceForJira);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create Jira task'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'This is the title visible in Jira. Keep the generated feedback ID or enter a short custom title. The feedback description and technical context will be added automatically.',
            style: TextStyle(color: _muted),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Jira task title',
              hintText: 'For example: Adjust the Open button',
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _includeAttachments = !_includeAttachments),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Checkbox(
                    value: _includeAttachments,
                    onChanged: (value) => setState(() => _includeAttachments = value ?? false),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Attach screenshot and media to Jira', style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 3),
                          Text(
                            'By default, these files stay private in Feedback Console. Select this only when they should be copied to Jira.',
                            style: TextStyle(color: _muted, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    actions: <Widget>[
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _JiraTaskDraft(summary: _controller.text.trim(), includeAttachments: _includeAttachments),
        ),
        child: const Text('Create task'),
      ),
    ],
  );
}

final class _JiraTaskDraft {
  const _JiraTaskDraft({required this.summary, required this.includeAttachments});

  final String summary;
  final bool includeAttachments;
}

class _DetailScreenshot extends StatelessWidget {
  const _DetailScreenshot({required this.report, required this.repository});
  final FeedbackReport report;
  final FeedbackRepository repository;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text('Screenshot', overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
          ),
          TextButton.icon(
            onPressed: () => openFeedbackGallery(context, report: report, repository: repository),
            icon: const Icon(Icons.open_in_full, size: 16),
            label: const Text('Open gallery'),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: InkWell(
              onTap: () => openFeedbackGallery(context, report: report, repository: repository),
              child: _FeedbackScreenshotPreview(report: report, repository: repository, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    ],
  );
}

class _FeedbackDetailSidebar extends StatelessWidget {
  const _FeedbackDetailSidebar({
    required this.report,
    required this.repository,
    required this.canCreateJiraTasks,
    required this.isCreatingJiraIssue,
    required this.jiraError,
    required this.createdJiraIssue,
    required this.onCreateJiraIssue,
    this.inlineScreenshot = false,
  });

  final FeedbackReport report;
  final FeedbackRepository repository;
  final bool canCreateJiraTasks;
  final bool isCreatingJiraIssue;
  final String? jiraError;
  final JiraIssueCreationSuccess? createdJiraIssue;
  final VoidCallback onCreateJiraIssue;
  final bool inlineScreenshot;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _ReportOverview(report: report, repository: repository),
      const SizedBox(height: 28),
      if (inlineScreenshot) ...[
        SizedBox(
          height: 420,
          child: _DetailScreenshot(report: report, repository: repository),
        ),
        const SizedBox(height: 28),
      ],
      if (report.attachments.isNotEmpty) ...<Widget>[
        FeedbackAttachments(report: report, repository: repository),
        const SizedBox(height: 28),
      ],
      const _DetailSectionTitle('Jira'),
      const SizedBox(height: 10),
      _JiraIssueAction(
        report: report,
        canCreateJiraTasks: canCreateJiraTasks,
        isCreating: isCreatingJiraIssue,
        errorMessage: jiraError,
        createdIssue: createdJiraIssue,
        onCreate: onCreateJiraIssue,
      ),
      const SizedBox(height: 28),
      const _DetailSectionTitle('Technical details'),
      const SizedBox(height: 10),
      _FeedbackMetadata(report: report),
      if (report.logs.isNotEmpty || report.logsPath != null) ...<Widget>[
        const SizedBox(height: 28),
        _FeedbackLogs(report: report, repository: repository),
      ],
      const SizedBox(height: 28),
      _FeedbackActivity(report: report, repository: repository),
    ],
  );
}

class _ReportOverview extends StatelessWidget {
  const _ReportOverview({required this.report, required this.repository});
  final FeedbackReport report;
  final FeedbackRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FeedbackStatusMenu(report: report, repository: repository),
      const SizedBox(height: 12),
      SelectableText(
        report.message.isEmpty ? 'No description provided.' : report.message,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontSize: 20, height: 1.45, fontWeight: FontWeight.w500, letterSpacing: -0.4),
      ),
    ],
  );
}

class _DetailSectionTitle extends StatelessWidget {
  const _DetailSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(label, style: Theme.of(context).textTheme.titleSmall);
}

class _JiraIssueAction extends StatelessWidget {
  const _JiraIssueAction({
    required this.report,
    required this.canCreateJiraTasks,
    required this.isCreating,
    required this.errorMessage,
    required this.createdIssue,
    required this.onCreate,
  });

  final FeedbackReport report;
  final bool canCreateJiraTasks;
  final bool isCreating;
  final String? errorMessage;
  final JiraIssueCreationSuccess? createdIssue;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final issueKey = createdIssue?.key ?? report.jiraIssueKey;
    final issueUrl = createdIssue?.url ?? report.jiraIssueUrl;
    final warning =
        errorMessage ??
        (report.jiraExportState == 'attachments_failed'
            ? 'Task created, but some attachments could not be uploaded. Check the files in Jira.'
            : null);
    if (issueKey != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (Uri.tryParse(issueUrl ?? '') case final url? when url.hasScheme)
            TextButton.icon(
              onPressed: () => _openExternalUrl(url),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Open $issueKey in Jira'),
            ),
          if (warning case final message?) ...<Widget>[
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      );
    }
    if (!canCreateJiraTasks) {
      return const Text(
        'Ask a feedback administrator for permission to create Jira tasks.',
        style: TextStyle(color: _muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton.icon(
          onPressed: isCreating ? null : onCreate,
          icon: isCreating
              ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_task_outlined),
          label: Text(isCreating ? 'Creating task…' : 'Create Jira task'),
        ),
        if (errorMessage case final message?) ...<Widget>[
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
        ],
      ],
    );
  }
}

class _FeedbackMetadata extends StatelessWidget {
  const _FeedbackMetadata({required this.report});

  final FeedbackReport report;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('App', report.applicationName),
      ('Environment', report.environment ?? 'Unspecified'),
      ('Version', _versionLabel(report)),
      ('Platform', _platformLabel(report)),
      if (report.deviceModel case final device?) ('Device', device),
      if (report.locale case final locale?) ('Locale', locale),
      ('Reported', _dateTimeLabel(context, report.capturedAt ?? report.createdAt)),
      if (report.annotationCount > 0) ('Annotations', '${report.annotationCount}'),
    ];
    return Column(
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 92,
                    child: Text(entry.$1, style: const TextStyle(color: _muted)),
                  ),
                  Expanded(child: Text(entry.$2)),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _FeedbackLogs extends StatefulWidget {
  const _FeedbackLogs({required this.report, required this.repository});

  final FeedbackReport report;
  final FeedbackRepository repository;

  @override
  State<_FeedbackLogs> createState() => _FeedbackLogsState();
}

class _FeedbackLogsState extends State<_FeedbackLogs> {
  late Future<String?> _logsUrl;

  @override
  void initState() {
    super.initState();
    _logsUrl = widget.repository.logsUrlFor(widget.report);
  }

  @override
  void didUpdateWidget(covariant _FeedbackLogs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.id == widget.report.id && oldWidget.report.logsPath == widget.report.logsPath) return;
    _logsUrl = widget.repository.logsUrlFor(widget.report);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _DetailSectionTitle('App logs'),
      const SizedBox(height: 8),
      Text(
        '${widget.report.logCount ?? widget.report.logs.length} diagnostic entries',
        style: const TextStyle(color: _muted),
      ),
      const SizedBox(height: 8),
      FeedbackLogPreview(entries: widget.report.logs),
      FutureBuilder<String?>(
        future: _logsUrl,
        builder: (context, snapshot) {
          final url = snapshot.data;
          final uri = url == null ? null : Uri.tryParse(url);
          if (uri == null || !uri.hasScheme) return const SizedBox.shrink();
          return TextButton.icon(
            onPressed: () => _openExternalUrl(uri),
            icon: const Icon(Icons.download_outlined, size: 17),
            label: const Text('Open log file'),
          );
        },
      ),
    ],
  );
}

String _versionLabel(FeedbackReport report) => switch (report.buildNumber) {
  final build? when build.isNotEmpty => '${report.appVersion} ($build)',
  _ => report.appVersion,
};

String _platformLabel(FeedbackReport report) => switch (report.osVersion) {
  final osVersion? when osVersion.isNotEmpty => '${report.platform} · $osVersion',
  _ => report.platform,
};

String _dateTimeLabel(BuildContext context, DateTime? value) {
  if (value == null) return 'Unknown time';
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(value)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(value))}';
}

class _FeedbackActivity extends StatelessWidget {
  const _FeedbackActivity({required this.report, required this.repository});

  final FeedbackReport report;
  final FeedbackRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const _DetailSectionTitle('History'),
      const SizedBox(height: 12),
      StreamBuilder<List<FeedbackStatusEvent>>(
        stream: repository.watchStatusEvents(report.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const _ActivityLoading();
          final events = snapshot.data!;
          if (events.isEmpty) return const Text('No activity yet.', style: TextStyle(color: _muted));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: events
                .map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${event.actorLabel} moved ${event.fromStatus.label} to ${event.toStatus.label}.',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (event.createdAt case final createdAt?)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              _dateTimeLabel(context, createdAt),
                              style: const TextStyle(color: _muted, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    ],
  );
}

class _ActivityLoading extends StatelessWidget {
  const _ActivityLoading();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2));
}

class _AccessWorkspace extends StatelessWidget {
  const _AccessWorkspace({required this.repository});

  final FeedbackRepository repository;

  @override
  Widget build(BuildContext context) => _WorkspacePage(
    title: 'Access',
    subtitle: 'Choose who can review feedback. Testers submit it from the connected application.',
    trailing: const SizedBox.shrink(),
    child: StreamBuilder<List<FeedbackMember>>(
      stream: repository.watchMembers(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _WorkspaceFailure(error: snapshot.error);
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final members = snapshot.data!;
        return SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: constraints.maxWidth < 680 ? 680 : constraints.maxWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _surface,
                    border: Border.all(color: const Color(0xFFE1E1E7)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: <Widget>[
                      const _AccessHeader(),
                      const Divider(height: 1),
                      ...members.expand(
                        (member) => <Widget>[
                          _AccessRow(member: member, repository: repository),
                          if (member != members.last) const Divider(height: 1),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _AccessHeader extends StatelessWidget {
  const _AccessHeader();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'User',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: 150,
          child: Text(
            'Review feedback',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: 160,
          child: Text(
            'Create Jira issues',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: 92,
          child: Text(
            'Role',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _AccessRow extends StatelessWidget {
  const _AccessRow({required this.member, required this.repository});

  final FeedbackMember member;
  final FeedbackRepository repository;

  @override
  Widget build(BuildContext context) {
    final isAdmin = member.consoleRole == FeedbackConsoleRole.admin;
    final canReview = member.consoleRole == FeedbackConsoleRole.reviewer;
    final primaryLabel = member.displayName?.trim().isNotEmpty == true && member.displayName != member.email
        ? member.displayName!
        : member.email;
    final showEmail = primaryLabel != member.email;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            child: Text(primaryLabel.isEmpty ? '?' : primaryLabel.substring(0, 1).toUpperCase()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (showEmail) Text(member.email, style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(
            width: 150,
            child: Tooltip(
              message: isAdmin ? 'Admins can review all feedback.' : 'Allow this user to review feedback.',
              child: Checkbox(
                value: isAdmin || canReview,
                onChanged: isAdmin
                    ? null
                    : (value) => repository.updateReviewerAccess(member: member, enabled: value ?? false),
              ),
            ),
          ),
          SizedBox(
            width: 160,
            child: Tooltip(
              message: isAdmin ? 'Admins can create Jira issues.' : 'Allow this reviewer to create Jira issues.',
              child: Checkbox(
                value: isAdmin || member.canCreateJiraTasks,
                onChanged: isAdmin || !canReview
                    ? null
                    : (value) => repository.updateJiraTaskCreatorAccess(member: member, enabled: value ?? false),
              ),
            ),
          ),
          SizedBox(width: 92, child: _AccessRoleLabel(isAdmin: isAdmin)),
        ],
      ),
    );
  }
}

class _AccessRoleLabel extends StatelessWidget {
  const _AccessRoleLabel({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final background = isAdmin ? const Color(0xFFE6F5EB) : ConsoleColors.wash;
    final foreground = isAdmin ? const Color(0xFF277A48) : _muted;
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          isAdmin ? 'Admin' : 'Member',
          style: TextStyle(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _WorkspaceFailure extends StatelessWidget {
  const _WorkspaceFailure({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) => _WorkspacePage(
    title: 'Unable to load this workspace',
    subtitle: 'Check your account access and try again.',
    trailing: const SizedBox.shrink(),
    child: Text('$error', style: const TextStyle(color: _muted)),
  );
}
