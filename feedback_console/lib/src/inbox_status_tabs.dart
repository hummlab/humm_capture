import 'package:flutter/material.dart';

import 'console_theme.dart';
import 'feedback_report.dart';

/// Status navigation uses one baseline rather than a group of floating chips.
class InboxStatusTabs extends StatelessWidget {
  const InboxStatusTabs({required this.reports, required this.selected, required this.onSelected, super.key});

  final List<FeedbackReport> reports;
  final FeedbackStatus? selected;
  final ValueChanged<FeedbackStatus?> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final status in [null, ...FeedbackStatus.values])
          _StatusTab(
            label: status?.label ?? 'All reports',
            count: status == null ? reports.length : reports.where((report) => report.status == status).length,
            selected: selected == status,
            onPressed: () => onSelected(status),
          ),
      ],
    ),
  );
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({required this.label, required this.count, required this.selected, required this.onPressed});
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: selected ? ConsoleColors.accent : Colors.transparent, width: 2)),
      ),
      child: TextButton(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 48),
          foregroundColor: selected ? ConsoleColors.ink : ConsoleColors.muted,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                color: ConsoleColors.muted,
                fontSize: 12,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
