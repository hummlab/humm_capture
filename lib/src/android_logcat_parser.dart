import 'feedback_models.dart';

/// Parses epoch-format logcat output; ignores headers and other process IDs.
List<FeedbackLogEntry> parseAndroidLogcat(String text, int processId) {
  final pattern = RegExp(r'^\s*(\d+\.\d+)\s+(\d+)\s+\d+\s+([VDIWEF])\s+([^:]+):\s?(.*)$');
  final entries = <FeedbackLogEntry>[];
  for (final line in text.split('\n')) {
    final match = pattern.firstMatch(line);
    if (match == null || int.tryParse(match[2]!) != processId) continue;
    final seconds = double.tryParse(match[1]!);
    if (seconds == null || !seconds.isFinite) continue;
    entries.add(
      FeedbackLogEntry(
        timestamp: DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round(), isUtc: true),
        category: 'android.logcat/${match[4]!.trim()}',
        message: match[5]!,
        level: switch (match[3]) {
          'E' || 'F' => FeedbackLogLevel.error,
          'W' => FeedbackLogLevel.warning,
          _ => FeedbackLogLevel.info,
        },
      ),
    );
  }
  return entries;
}
