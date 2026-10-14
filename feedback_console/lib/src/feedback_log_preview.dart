import 'package:flutter/material.dart';

import 'feedback_report.dart';

/// A bounded, readable preview; the complete diagnostic file remains available.
class FeedbackLogPreview extends StatelessWidget {
  const FeedbackLogPreview({required this.entries, super.key});

  final List<FeedbackReportLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: entries.reversed
          .take(4)
          .map((entry) {
            final level = entry.level.toUpperCase();
            final foreground = switch (level) {
              'ERROR' || 'FATAL' => colors.error,
              'WARNING' || 'WARN' => const Color(0xFF855C00),
              _ => colors.onSurfaceVariant,
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.outlineVariant)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$level · ${entry.category ?? 'app'}',
                    style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    entry.message,
                    style: TextStyle(color: colors.onSurface, fontSize: 12, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    entry.timestamp.toUtc().toIso8601String(),
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
