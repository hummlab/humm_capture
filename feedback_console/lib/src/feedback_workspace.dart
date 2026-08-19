import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'external_url_opener.dart';
import 'feedback_report.dart';
import 'feedback_repository.dart';
import 'feedback_shimmer.dart';
import 'jira_issue_repository.dart';
import 'jira_integration_workspace.dart';

const _canvas = Color(0xFFF7F7F9);
const _surface = Color(0xFFFFFFFF);
const _ink = Color(0xFF25252C);
const _muted = Color(0xFF6C6B76);
const _primary = Color(0xFF4D2FE8);

void _openExternalUrl(Uri uri) {
  openExternalUrl(uri);
}

enum _WorkspaceDestination { inbox, jira, access }

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
  const FeedbackWorkspace({super.key});

  @override
  State<FeedbackWorkspace> createState() => _FeedbackWorkspaceState();
}

class _FeedbackWorkspaceState extends State<FeedbackWorkspace> {
  final _repository = FeedbackRepository();
  _WorkspaceDestination _destination = _WorkspaceDestination.inbox;
  FeedbackStatus? _status;
  _FeedbackDateFilter? _dateFilter;
  String? _platform;
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
        backgroundColor: _canvas,
        body: Row(
          children: <Widget>[
            _WorkspaceRail(
              destination: destination,
              canManageAccess: canManageAccess,
              onDestinationChanged: (destination) => setState(() => _destination = destination),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: SafeArea(
                child: switch (destination) {
                  _WorkspaceDestination.inbox => _InboxWorkspace(
                    repository: _repository,
                    canDelete: canManageAccess,
                    canCreateJiraTasks: canCreateJiraTasks,
                    query: _query,
                    status: _status,
                    dateFilter: _dateFilter,
                    platform: _platform,
                    version: _version,
                    onQueryChanged: (query) => setState(() => _query = query),
                    onStatusChanged: (status) => setState(() => _status = status),
                    onDateFilterChanged: (filter) => setState(() => _dateFilter = filter),
                    onPlatformChanged: (platform) => setState(() => _platform = platform),
                    onVersionChanged: (version) => setState(() => _version = version),
                  ),
                  _WorkspaceDestination.jira => const JiraIntegrationWorkspace(),
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

class _WorkspaceRail extends StatelessWidget {
  const _WorkspaceRail({required this.destination, required this.canManageAccess, required this.onDestinationChanged});

  final _WorkspaceDestination destination;
  final bool canManageAccess;
  final ValueChanged<_WorkspaceDestination> onDestinationChanged;

  @override
  Widget build(BuildContext context) => Container(
    width: 84,
    color: _surface,
    child: Column(
      children: <Widget>[
        const SizedBox(height: 20),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: const Color(0xFFEEE8FF), borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Icon(Icons.forum_outlined, color: _primary, size: 21)),
        ),
        const SizedBox(height: 24),
        _RailDestination(
          icon: Icons.inbox_outlined,
          label: 'Inbox',
          selected: destination == _WorkspaceDestination.inbox,
          onTap: () => onDestinationChanged(_WorkspaceDestination.inbox),
        ),
        if (canManageAccess) ...<Widget>[
          const SizedBox(height: 12),
          _RailDestination(
            icon: Icons.integration_instructions_outlined,
            label: 'Jira',
            selected: destination == _WorkspaceDestination.jira,
            onTap: () => onDestinationChanged(_WorkspaceDestination.jira),
          ),
        ],
        if (canManageAccess) ...<Widget>[
          const SizedBox(height: 12),
          _RailDestination(
            icon: Icons.people_outline,
            label: 'Access',
            selected: destination == _WorkspaceDestination.access,
            onTap: () => onDestinationChanged(_WorkspaceDestination.access),
          ),
        ],
        const Spacer(),
        IconButton(
          tooltip: 'Sign out',
          onPressed: FirebaseAuth.instance.signOut,
          icon: const Icon(Icons.logout_outlined, color: _muted),
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}

class _RailDestination extends StatelessWidget {
  const _RailDestination({required this.icon, required this.label, required this.selected, required this.onTap});

  final IconData icon;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEEE8FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: <Widget>[
          Icon(icon, size: 20, color: selected ? _primary : _muted),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: selected ? _primary : _muted)),
        ],
      ),
    ),
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
    required this.version,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onDateFilterChanged,
    required this.onPlatformChanged,
    required this.onVersionChanged,
  });

  final FeedbackRepository repository;
  final bool canDelete;
  final bool canCreateJiraTasks;
  final String query;
  final FeedbackStatus? status;
  final _FeedbackDateFilter? dateFilter;
  final String? platform;
  final String? version;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<FeedbackStatus?> onStatusChanged;
  final ValueChanged<_FeedbackDateFilter?> onDateFilterChanged;
  final ValueChanged<String?> onPlatformChanged;
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
            return matchesStatus && matchesDate && matchesPlatform && matchesVersion && matchesQuery;
          })
          .toList(growable: false);
      return _WorkspacePage(
        title: 'Feedback',
        subtitle: 'Visual reports from connected applications.',
        trailing: const SizedBox.shrink(),
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
                        query.isNotEmpty || status != null || dateFilter != null || platform != null || version != null,
                    onClearFilters: () {
                      onQueryChanged('');
                      onStatusChanged(null);
                      onDateFilterChanged(null);
                      onPlatformChanged(null);
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
                    version: version,
                    onQueryChanged: onQueryChanged,
                    onStatusChanged: onStatusChanged,
                    onDateFilterChanged: onDateFilterChanged,
                    onPlatformChanged: onPlatformChanged,
                    onVersionChanged: onVersionChanged,
                  );
                  if (constraints.maxWidth < 860) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        filters,
                        const SizedBox(height: 20),
                        Expanded(child: results),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(width: 264, child: filters),
                      const VerticalDivider(width: 40),
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
        padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: _ink)),
                      const SizedBox(height: 6),
                      Text(subtitle, style: const TextStyle(color: _muted)),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
            const SizedBox(height: 32),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class _InboxFilterPanel extends StatelessWidget {
  const _InboxFilterPanel({
    required this.reports,
    required this.resultCount,
    required this.query,
    required this.status,
    required this.dateFilter,
    required this.platform,
    required this.version,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onDateFilterChanged,
    required this.onPlatformChanged,
    required this.onVersionChanged,
  });

  final List<FeedbackReport> reports;
  final int resultCount;
  final String query;
  final FeedbackStatus? status;
  final _FeedbackDateFilter? dateFilter;
  final String? platform;
  final String? version;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<FeedbackStatus?> onStatusChanged;
  final ValueChanged<_FeedbackDateFilter?> onDateFilterChanged;
  final ValueChanged<String?> onPlatformChanged;
  final ValueChanged<String?> onVersionChanged;

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        query.isNotEmpty || status != null || dateFilter != null || platform != null || version != null;
    final platforms = reports.map((report) => report.platform).where((value) => value.isNotEmpty).toSet().toList()
      ..sort();
    final versions = reports.map(_versionFilterValue).where((value) => value.isNotEmpty).toSet().toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Filter reports', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        TextField(
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Search feedback',
            prefixIcon: Icon(Icons.search, color: _muted),
          ),
        ),
        const SizedBox(height: 14),
        _PanelFilterMenu<FeedbackStatus?>(
          label: 'Status',
          value: status?.label ?? 'All reports',
          onSelected: onStatusChanged,
          items: <PopupMenuEntry<FeedbackStatus?>>[
            PopupMenuItem<FeedbackStatus?>(
              value: null,
              onTap: () => onStatusChanged(null),
              child: Text('All reports (${reports.length})'),
            ),
            ...FeedbackStatus.values.map(
              (item) => PopupMenuItem<FeedbackStatus?>(
                value: item,
                child: Text('${item.label} (${reports.where((report) => report.status == item).length})'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PanelFilterMenu<_FeedbackDateFilter?>(
          label: 'Reported',
          value: dateFilter == null ? 'Any time' : _dateFilterLabel(dateFilter!),
          onSelected: onDateFilterChanged,
          items: <PopupMenuEntry<_FeedbackDateFilter?>>[
            PopupMenuItem<_FeedbackDateFilter?>(
              value: null,
              onTap: () => onDateFilterChanged(null),
              child: const Text('Any time'),
            ),
            ..._FeedbackDateFilter.values.map(
              (filter) => PopupMenuItem<_FeedbackDateFilter?>(value: filter, child: Text(_dateFilterLabel(filter))),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _PanelFilterMenu<String?>(
          label: 'Platform',
          value: platform ?? 'All platforms',
          onSelected: onPlatformChanged,
          items: <PopupMenuEntry<String?>>[
            PopupMenuItem<String?>(
              value: null,
              onTap: () => onPlatformChanged(null),
              child: const Text('All platforms'),
            ),
            ...platforms.map((item) => PopupMenuItem<String?>(value: item, child: Text(item))),
          ],
        ),
        const SizedBox(height: 10),
        _PanelFilterMenu<String?>(
          label: 'Version',
          value: version ?? 'All versions',
          onSelected: onVersionChanged,
          items: <PopupMenuEntry<String?>>[
            PopupMenuItem<String?>(value: null, onTap: () => onVersionChanged(null), child: const Text('All versions')),
            ...versions.map((item) => PopupMenuItem<String?>(value: item, child: Text(item))),
          ],
        ),
        const SizedBox(height: 20),
        Text('$resultCount ${resultCount == 1 ? 'result' : 'results'}', style: const TextStyle(color: _muted)),
        if (hasActiveFilters)
          TextButton(
            onPressed: () {
              onQueryChanged('');
              onStatusChanged(null);
              onDateFilterChanged(null);
              onPlatformChanged(null);
              onVersionChanged(null);
            },
            style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero),
            child: const Text('Clear filters'),
          ),
      ],
    );
  }
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = switch (constraints.maxWidth) {
          >= 980 => 3,
          >= 620 => 2,
          _ => 1,
        };
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: crossAxisCount == 1 ? 2.1 : 0.88,
          ),
          itemCount: reports.length,
          itemBuilder: (context, index) => _FeedbackCard(
            report: reports[index],
            reports: reports,
            reportIndex: index,
            repository: repository,
            canDelete: canDelete,
            canCreateJiraTasks: canCreateJiraTasks,
          ),
        );
      },
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
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetails(context),
        hoverColor: const Color(0xFFF7F4FF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _FeedbackScreenshotPreview(report: report, repository: repository),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          report.message.isEmpty ? 'No description' : report.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FeedbackStatusMenu(report: report, repository: repository),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${report.applicationName} · ${_platformLabel(report)} · ${_versionLabel(report)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _dateTimeLabel(context, report.capturedAt ?? report.createdAt),
                          style: const TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                      if (report.jiraIssueKey case final issueKey?)
                        _JiraIssueLink(issueKey: issueKey, issueUrl: report.jiraIssueUrl),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FeedbackScreenshotPreview extends StatefulWidget {
  const _FeedbackScreenshotPreview({required this.report, required this.repository});

  final FeedbackReport report;
  final FeedbackRepository repository;

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
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF0EFF5),
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
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const _ThumbnailFallback(),
        );
      },
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
    title: 'Feedback',
    subtitle: 'Visual reports from connected applications.',
    trailing: const SizedBox.shrink(),
    child: ListView.separated(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(vertical: 4),
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 88, endIndent: 20),
      itemBuilder: (context, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: <Widget>[
            FeedbackThumbnailShimmer(width: 64, height: 56),
            SizedBox(width: 16),
            Expanded(child: FeedbackThumbnailShimmer(width: double.infinity, height: 16)),
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
    color: Color(0xFFF0EFF5),
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
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.$1, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          status.label,
          style: TextStyle(color: colors.$2, fontWeight: FontWeight.w600),
        ),
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
    insetPadding: const EdgeInsets.all(32),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 1360,
        maxHeight: (MediaQuery.sizeOf(context).height - 48).clamp(480.0, 900.0).toDouble(),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 20, 16),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(_report.reference, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 3),
                      Text(
                        '${_report.applicationName} · ${_dateTimeLabel(context, _report.capturedAt ?? _report.createdAt)}',
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: _DetailScreenshot(report: _report, repository: widget.repository),
                  ),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 344,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                    child: SingleChildScrollView(
                      child: _FeedbackDetailSidebar(
                        report: _report,
                        repository: widget.repository,
                        canCreateJiraTasks: widget.canCreateJiraTasks,
                        isCreatingJiraIssue: _isCreatingJiraIssue,
                        jiraError: _jiraError,
                        createdJiraIssue: _createdJiraIssue,
                        onCreateJiraIssue: _createJiraIssue,
                      ),
                    ),
                  ),
                ),
              ],
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

class _DetailScreenshot extends StatefulWidget {
  const _DetailScreenshot({required this.report, required this.repository});

  final FeedbackReport report;
  final FeedbackRepository repository;

  @override
  State<_DetailScreenshot> createState() => _DetailScreenshotState();
}

class _DetailScreenshotState extends State<_DetailScreenshot> {
  final _transformationController = TransformationController();
  late Future<String?> _screenshotUrl;
  double _scale = 1;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _screenshotUrl = widget.repository.screenshotUrlFor(widget.report);
  }

  @override
  void didUpdateWidget(covariant _DetailScreenshot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.id == widget.report.id && oldWidget.report.screenshotPath == widget.report.screenshotPath) {
      return;
    }
    _screenshotUrl = widget.repository.screenshotUrlFor(widget.report);
    _scale = 1;
    _showControls = false;
    _transformationController.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _setScale(double value) {
    final scale = value.clamp(1.0, 2.0).toDouble();
    setState(() {
      _scale = scale;
      _transformationController.value = Matrix4.diagonal3Values(scale, scale, 1);
    });
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFFF1F1F4),
    child: FutureBuilder<String?>(
      future: _screenshotUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: FeedbackThumbnailShimmer(width: 420, height: 280));
        }
        final url = snapshot.data;
        if (url == null) return const _ThumbnailFallback();
        return LayoutBuilder(
          builder: (context, constraints) => MouseRegion(
            onEnter: (_) => setState(() => _showControls = true),
            onExit: (_) => setState(() => _showControls = false),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1,
                  maxScale: 2,
                  boundaryMargin: const EdgeInsets.all(160),
                  onInteractionEnd: (_) => setState(() => _scale = _transformationController.value.getMaxScaleOnAxis()),
                  child: Center(
                    child: RepaintBoundary(
                      child: GestureDetector(
                        onTap: () => setState(() => _showControls = true),
                        onDoubleTap: () => _setScale(_scale == 1 ? 2 : 1),
                        child: Image.network(
                          url,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      opacity: _showControls ? 1 : 0,
                      child: Center(
                        child: Material(
                          color: _surface,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  tooltip: 'Zoom out',
                                  onPressed: _scale <= 1 ? null : () => _setScale(_scale - 0.25),
                                  icon: const Icon(Icons.remove_rounded),
                                ),
                                TextButton(onPressed: () => _setScale(1), child: Text('${(_scale * 100).round()}%')),
                                IconButton(
                                  tooltip: 'Zoom in',
                                  onPressed: _scale >= 2 ? null : () => _setScale(_scale + 0.25),
                                  icon: const Icon(Icons.add_rounded),
                                ),
                                const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                                TextButton(onPressed: () => _setScale(1), child: const Text('Fit')),
                                const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                                TextButton.icon(
                                  onPressed: () => _openExternalUrl(Uri.parse(url)),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                  label: const Text('Open original'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
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
  });

  final FeedbackReport report;
  final FeedbackRepository repository;
  final bool canCreateJiraTasks;
  final bool isCreatingJiraIssue;
  final String? jiraError;
  final JiraIssueCreationSuccess? createdJiraIssue;
  final VoidCallback onCreateJiraIssue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      const _DetailSectionTitle('Description'),
      const SizedBox(height: 8),
      Text(report.message.isEmpty ? 'No description provided.' : report.message),
      const SizedBox(height: 28),
      const _DetailSectionTitle('Status'),
      const SizedBox(height: 6),
      _FeedbackStatusMenu(report: report, repository: repository),
      const SizedBox(height: 28),
      if (report.attachments.isNotEmpty) ...<Widget>[
        _FeedbackAttachments(report: report, repository: repository),
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
      if (report.logs.isNotEmpty) ...<Widget>[
        const SizedBox(height: 28),
        _FeedbackLogs(report: report, repository: repository),
      ],
      const SizedBox(height: 28),
      _FeedbackActivity(report: report, repository: repository),
    ],
  );
}

class _FeedbackAttachments extends StatelessWidget {
  const _FeedbackAttachments({required this.report, required this.repository});

  final FeedbackReport report;
  final FeedbackRepository repository;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _DetailSectionTitle('Attachments · ${report.attachments.length}'),
      const SizedBox(height: 10),
      ...report.attachments.map(
        (attachment) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _FeedbackAttachmentTile(attachment: attachment, repository: repository),
        ),
      ),
    ],
  );
}

class _FeedbackAttachmentTile extends StatefulWidget {
  const _FeedbackAttachmentTile({required this.attachment, required this.repository});

  final FeedbackReportAttachment attachment;
  final FeedbackRepository repository;

  @override
  State<_FeedbackAttachmentTile> createState() => _FeedbackAttachmentTileState();
}

class _FeedbackAttachmentTileState extends State<_FeedbackAttachmentTile> {
  late Future<String?> _url;

  @override
  void initState() {
    super.initState();
    _url = widget.repository.attachmentUrlFor(widget.attachment);
  }

  @override
  void didUpdateWidget(covariant _FeedbackAttachmentTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.path != widget.attachment.path) {
      _url = widget.repository.attachmentUrlFor(widget.attachment);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _url,
    builder: (context, snapshot) {
      final url = snapshot.data;
      final uri = url == null ? null : Uri.tryParse(url);
      Widget buildTile(VoidCallback? onOpen) => Material(
        color: const Color(0xFFF7F6FA),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: uri == null ? null : onOpen,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 42,
                  height: 42,
                  child: widget.attachment.isVideo
                      ? const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFE9E5F7),
                            borderRadius: BorderRadius.all(Radius.circular(7)),
                          ),
                          child: Icon(Icons.videocam_outlined, color: _primary),
                        )
                      : url == null
                      ? const FeedbackThumbnailShimmer(width: 42, height: 42)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const _ThumbnailFallback(),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(widget.attachment.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.attachment.isVideo ? 'Video' : 'Image'} · ${_fileSizeLabel(widget.attachment.sizeBytes)}',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.open_in_new_rounded, color: _primary, size: 17),
              ],
            ),
          ),
        ),
      );
      if (uri == null || !uri.hasScheme) return buildTile(null);
      return buildTile(() => _openExternalUrl(uri));
    },
  );
}

String _fileSizeLabel(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
      _DetailSectionTitle('App logs · last 24 h'),
      const SizedBox(height: 8),
      Text('${widget.report.logs.length} diagnostic entries', style: const TextStyle(color: _muted)),
      const SizedBox(height: 8),
      ...widget.report.logs
          .take(4)
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${entry.timestamp.toLocal().toIso8601String()} · ${entry.message}',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          ),
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
    final background = isAdmin ? const Color(0xFFE6F5EB) : const Color(0xFFF0EFF5);
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
