import 'dart:convert';

import 'feedback_log_buffer.dart';
import 'feedback_models.dart';
import 'log_storage_stub.dart' if (dart.library.io) 'log_storage_io.dart' as storage;

/// Optional persistent diagnostics. Supply an app-private, SDK-owned file path.
///
/// Records are plaintext: redact before storage, exclude credentials/PII, and
/// clear on sign-out. A single store instance must own the file. No global
/// print interception or cross-process locking is provided.
final class FeedbackLogStore {
  FeedbackLogStore._(this._path, this._clock, this._redact);

  final String _path;
  final DateTime Function() _clock;
  final FeedbackLogEntry? Function(FeedbackLogEntry) _redact;
  List<FeedbackLogEntry> _entries = [];
  Future<void> _pending = Future.value();
  Future<void> _lastOperation = Future.value();

  /// Loads and prunes a private file. Corrupt files return a clear error rather
  /// than silently overwriting diagnostics. Web hosts use their own provider.
  static Future<FeedbackLogStore> open({
    required String filePath,
    required FeedbackLogEntry? Function(FeedbackLogEntry) redact,
    DateTime Function()? clock,
  }) async {
    if (filePath.trim().isEmpty) throw ArgumentError.value(filePath, 'filePath');
    final store = FeedbackLogStore._(filePath, clock ?? DateTime.now, redact);
    final source = await storage.readLogStorage(filePath);
    if (source != null) {
      final decoded = jsonDecode(source);
      if (decoded is! List || decoded.length > 1000) throw const FormatException('Invalid feedback log file.');
      for (final value in decoded) {
        if (value is! Map || value['timestamp'] is! String || value['message'] is! String) {
          throw const FormatException('Invalid feedback log record.');
        }
        final timestamp = DateTime.parse(value['timestamp'] as String);
        final entry = FeedbackLogEntry(
          timestamp: timestamp,
          message: value['message'] as String,
          category: value['category'] as String?,
          level: FeedbackLogLevel.values.firstWhere(
            (level) => level.name == value['level'],
            orElse: () => FeedbackLogLevel.info,
          ),
        );
        if (redact(entry) case final safe?) store._entries.add(safe);
      }
    }
    await store._persist();
    return store;
  }

  /// Adds a host log after applying the required redaction/drop callback.
  Future<void> add(FeedbackLogEntry entry) => _serialize(() async {
    if (_redact(entry) case final safe?) _entries.add(safe);
    await _persist();
  });

  /// Captures a consistent last-24-hour snapshot, including pending writes.
  Future<List<FeedbackLogEntry>> snapshot() async {
    await _lastOperation;
    return recentFeedbackLogs(_entries, now: _clock());
  }

  /// Removes persisted records. Call on user sign-out/account switching.
  Future<void> clear() => _serialize(() async {
    _entries = [];
    await _persist();
  });

  /// Waits for completed writes before shutdown or test teardown.
  Future<void> flush() => _lastOperation;

  Future<void> _serialize(Future<void> Function() action) {
    final next = _pending.then((_) => action());
    _lastOperation = next;
    // Return errors to callers, while allowing subsequent operations to recover.
    _pending = next.then((_) {}, onError: (Object _) {});
    return next;
  }

  Future<void> _persist() async {
    _entries = recentFeedbackLogs(_entries, now: _clock()).toList();
    await storage.writeLogStorage(
      _path,
      jsonEncode(
        _entries
            .map(
              (entry) => {
                'timestamp': entry.timestamp.toUtc().toIso8601String(),
                'message': entry.message,
                'level': entry.level.name,
                'category': entry.category,
              },
            )
            .toList(),
      ),
    );
  }
}
