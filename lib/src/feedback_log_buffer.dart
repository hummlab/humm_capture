import 'dart:collection';
import 'dart:convert';

import 'feedback_models.dart';

/// Bounded, in-memory diagnostics supplied explicitly by the host logger.
///
/// Does not intercept console output or survive application restarts. The host
/// must redact credentials and personal data before calling [add].
final class FeedbackLogBuffer {
  /// Creates a buffer with up to 1000 entries and an optional test clock.
  FeedbackLogBuffer({this.maxEntries = 1000, DateTime Function()? clock})
    : assert(maxEntries > 0 && maxEntries <= 1000),
      _clock = clock ?? DateTime.now;

  /// Maximum retained count, independent from the 24-hour age limit.
  final int maxEntries;
  final DateTime Function() _clock;
  final Queue<FeedbackLogEntry> _entries = Queue<FeedbackLogEntry>();

  /// Records an already-redacted diagnostic event.
  void add(FeedbackLogEntry entry) {
    _entries.addLast(entry);
    _prune();
  }

  /// Returns the last 24 hours, oldest first, without future-dated entries.
  List<FeedbackLogEntry> snapshot() {
    _prune();
    return recentFeedbackLogs(_entries, now: _clock(), maxEntries: maxEntries);
  }

  /// Clears diagnostic events, for example when the host user signs out.
  void clear() => _entries.clear();

  void _prune() {
    final cutoff = _clock().subtract(const Duration(hours: 24));
    _entries.removeWhere((entry) => entry.timestamp.isBefore(cutoff));
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
  }
}

/// Normalizes host-supplied logs to the supported intake window and count.
List<FeedbackLogEntry> recentFeedbackLogs(
  Iterable<FeedbackLogEntry> entries, {
  required DateTime now,
  int maxEntries = 1000,
}) {
  final cutoff = now.subtract(const Duration(hours: 24));
  final recent = entries.where((entry) => !entry.timestamp.isBefore(cutoff) && !entry.timestamp.isAfter(now)).toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  final bounded = <FeedbackLogEntry>[];
  var bytes = 2;
  for (final entry in recent.reversed.take(maxEntries)) {
    final message = entry.message.length > 2000 ? '${entry.message.substring(0, 1988)} [truncated]' : entry.message;
    final category = entry.category;
    final normalized = FeedbackLogEntry(
      timestamp: entry.timestamp,
      message: message,
      level: entry.level,
      category: category != null && category.length > 100 ? category.substring(0, 100) : category,
    );
    final size =
        utf8
            .encode(
              jsonEncode({
                'timestamp': normalized.timestamp.toUtc().toIso8601String(),
                'message': normalized.message,
                'level': normalized.level.value,
                'category': normalized.category,
              }),
            )
            .length +
        1;
    if (bytes + size > 400000) break;
    bytes += size;
    bounded.add(normalized);
  }
  return List.unmodifiable(bounded.reversed);
}
