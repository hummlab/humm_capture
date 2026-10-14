import 'feedback_models.dart';
import 'android_feedback_logs_stub.dart' if (dart.library.io) 'android_feedback_logs_io.dart' as platform;

/// Reads recent Android logcat records from this app's current process only.
/// No ADB, root, READ_LOGS permission or other applications' logs are used.
/// The OS ring buffer has no guaranteed retention; use FeedbackLogStore for
/// persistent application diagnostics. Unsupported platforms throw explicitly.
Future<List<FeedbackLogEntry>> collectAndroidFeedbackLogs({
  required FeedbackLogEntry? Function(FeedbackLogEntry) redact,
  int maxEntries = 200,
}) => platform.collect(redact: redact, maxEntries: maxEntries);
