import 'package:flutter/material.dart';

/// Quiet, consistent connection identity and explicit refresh action.
class IntegrationConnectionStatus extends StatelessWidget {
  const IntegrationConnectionStatus({
    required this.integration,
    required this.label,
    required this.connected,
    required this.onRefresh,
    this.details,
    super.key,
  });

  final String integration;
  final String label;
  final bool connected;
  final String? details;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Icon(
          connected ? Icons.check_circle_outline : Icons.link_off,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.titleMedium),
              if (details case final text?) ...[
                const SizedBox(height: 6),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
      IconButton(
        tooltip: 'Refresh $integration connection status',
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded, size: 20),
      ),
    ],
  );
}
