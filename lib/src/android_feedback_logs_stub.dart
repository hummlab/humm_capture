import 'feedback_models.dart';

/// Explicit unsupported-platform result; never fabricates device logs.
Future<List<FeedbackLogEntry>> collect({
  required FeedbackLogEntry? Function(FeedbackLogEntry) redact,
  required int maxEntries,
}) async => throw UnsupportedError('Android process logs are unavailable on this platform.');
