import 'dart:io';

/// Internal atomic storage adapter for mobile/desktop runtimes.
Future<String?> readLogStorage(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  if (await file.length() > 1024 * 1024) throw const FormatException('Feedback log file exceeds its safety limit.');
  return file.readAsString();
}

/// Replaces the owned log file only after the complete snapshot is written.
Future<void> writeLogStorage(String path, String value) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final temporary = File('$path.tmp');
  await temporary.writeAsString(value, flush: true);
  await temporary.rename(path);
}
