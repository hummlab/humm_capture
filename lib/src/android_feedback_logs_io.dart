import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'android_logcat_parser.dart';
import 'feedback_log_buffer.dart';
import 'feedback_models.dart';

/// Platform implementation for current-process Android diagnostics.
Future<List<FeedbackLogEntry>> collect({
  required FeedbackLogEntry? Function(FeedbackLogEntry) redact,
  required int maxEntries,
}) async {
  if (!Platform.isAndroid) throw UnsupportedError('Android process logs require Android.');
  if (maxEntries < 1 || maxEntries > 1000) throw RangeError.range(maxEntries, 1, 1000, 'maxEntries');
  final process = await Process.start('/system/bin/logcat', ['-d', '-v', 'epoch', '--pid=$pid', '-t', '$maxEntries']);
  final output = BytesBuilder(copy: false);
  var bytes = 0;
  var truncated = false;
  final stdout = process.stdout.listen((chunk) {
    bytes += chunk.length;
    if (bytes > 400000) {
      truncated = true;
      process.kill();
      return;
    }
    output.add(chunk);
  });
  final stderr = process.stderr.listen((_) {});
  final completion = Future.wait<Object?>([process.exitCode, stdout.asFuture<void>(), stderr.asFuture<void>()]);
  try {
    final results = await completion.timeout(const Duration(seconds: 4));
    final exit = results.first as int;
    if (exit != 0 || truncated) throw StateError('Android logcat collection failed or exceeded the size limit.');
    final parsed = parseAndroidLogcat(utf8.decode(output.takeBytes(), allowMalformed: true), pid);
    if (parsed.isEmpty) throw StateError('Android returned no logs for this application process.');
    return recentFeedbackLogs(
      parsed.map(redact).whereType<FeedbackLogEntry>(),
      now: DateTime.now(),
      maxEntries: maxEntries,
    );
  } finally {
    process.kill();
    await stdout.cancel();
    await stderr.cancel();
  }
}
