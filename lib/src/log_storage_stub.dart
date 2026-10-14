/// Persistent file logging is unavailable in a browser runtime.
Future<String?> readLogStorage(String path) => Future.error(UnsupportedError('Use your own logsProvider on web.'));

/// Persistent file logging is unavailable in a browser runtime.
Future<void> writeLogStorage(String path, String value) =>
    Future.error(UnsupportedError('Use your own logsProvider on web.'));
