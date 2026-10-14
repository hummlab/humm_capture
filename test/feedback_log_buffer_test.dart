import 'package:flutter_test/flutter_test.dart';
import 'package:humm_capture/humm_capture.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1, 12);
  FeedbackLogEntry entry(DateTime at, String message) => FeedbackLogEntry(timestamp: at, message: message);

  test('keeps chronological last 24 hours and excludes future entries', () {
    final logs = recentFeedbackLogs([
      entry(now, 'last'),
      entry(now.subtract(const Duration(hours: 25)), 'expired'),
      entry(now.add(const Duration(seconds: 1)), 'future'),
      entry(now.subtract(const Duration(hours: 24)), 'first'),
    ], now: now);
    expect(logs.map((log) => log.message), ['first', 'last']);
  });

  test('buffer bounds entries and expires them as time advances', () {
    var time = now;
    final buffer = FeedbackLogBuffer(maxEntries: 2, clock: () => time);
    buffer.add(entry(now, 'one'));
    buffer.add(entry(now, 'two'));
    buffer.add(entry(now, 'three'));
    expect(buffer.snapshot().map((log) => log.message), ['two', 'three']);
    time = now.add(const Duration(hours: 25));
    expect(buffer.snapshot(), isEmpty);
    buffer.clear();
  });
  test('bounds long messages so logs cannot invalidate an otherwise valid report', () {
    final logs = recentFeedbackLogs([entry(now, 'x' * 3000)], now: now);
    expect(logs.single.message.length, lessThanOrEqualTo(2000));
    expect(logs.single.message, endsWith('[truncated]'));
  });
}
