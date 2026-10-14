import 'package:flutter_test/flutter_test.dart';
import 'package:humm_capture/src/android_logcat_parser.dart';
import 'package:humm_capture/humm_capture.dart';

void main() {
  test('real process records retain UTC time and severity; other PIDs are excluded', () {
    final entries = parseAndroidLogcat('''--------- beginning of main
1791951752.253 123 124 I flutter : actual stdout
1791951753.000 999 999 E other : must not collect another application
1791951754.000 123 124 E NativeTag: actual error
''', 123);
    expect(entries, hasLength(2));
    expect(entries.first.category, 'android.logcat/flutter');
    expect(entries.first.timestamp.isUtc, isTrue);
    expect(entries.last.level, FeedbackLogLevel.error);
    expect(entries.last.message, 'actual error');
  });
  test('unstructured lines are not fabricated into device records', () {
    expect(parseAndroidLogcat('permission denied\nnot a log entry', 123), isEmpty);
  });
}
