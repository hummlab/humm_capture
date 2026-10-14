import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humm_capture/humm_capture.dart';

void main() {
  late Directory directory;
  final now = DateTime.utc(2026, 10, 1, 12);
  setUp(() async => directory = await Directory.systemTemp.createTemp('capture-logs-test-'));
  tearDown(() async => directory.delete(recursive: true));

  test('persists through reopening and expires records after 24 hours', () async {
    final path = '${directory.path}/logs.json';
    final store = await FeedbackLogStore.open(filePath: path, redact: (entry) => entry, clock: () => now);
    await store.add(FeedbackLogEntry(timestamp: now, message: 'saved', category: 'network'));
    final reopened = await FeedbackLogStore.open(filePath: path, redact: (entry) => entry, clock: () => now);
    expect((await reopened.snapshot()).single.message, 'saved');
    final expired = await FeedbackLogStore.open(
      filePath: path,
      redact: (entry) => entry,
      clock: () => now.add(const Duration(hours: 25)),
    );
    expect(await expired.snapshot(), isEmpty);
  });

  test('redacts before persistence, supports concurrent writes and clears disk', () async {
    final path = '${directory.path}/logs.json';
    final store = await FeedbackLogStore.open(
      filePath: path,
      redact: (entry) =>
          entry.category == 'private' ? null : FeedbackLogEntry(timestamp: entry.timestamp, message: '[redacted]'),
      clock: () => now,
    );
    await Future.wait([
      store.add(FeedbackLogEntry(timestamp: now, message: 'password', category: 'private')),
      store.add(FeedbackLogEntry(timestamp: now, message: 'token')),
      store.add(FeedbackLogEntry(timestamp: now, message: 'secret')),
    ]);
    expect((await store.snapshot()).length, 2);
    expect(await File(path).readAsString(), isNot(contains('token')));
    await store.clear();
    expect(await File(path).readAsString(), '[]');
  });

  test('does not overwrite a corrupt existing file', () async {
    final path = '${directory.path}/logs.json';
    await File(path).writeAsString('invalid');
    await expectLater(FeedbackLogStore.open(filePath: path, redact: (entry) => entry), throwsFormatException);
    expect(await File(path).readAsString(), 'invalid');
  });
}
