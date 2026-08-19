import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:humm_capture/humm_capture.dart';

void main() {
  test('preserves a system screenshot as a report attachment', () {
    final image = FeedbackImage(
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
      source: FeedbackImageSource.systemScreenshot,
      fileName: 'Screenshot.png',
    );
    final report = FeedbackReport(image: image, createdAt: DateTime(2026, 8, 17));

    expect(report.image.source, FeedbackImageSource.systemScreenshot);
    expect(report.image.fileName, 'Screenshot.png');
  });

  test('keeps stroke points immutable after construction', () {
    final sourcePoints = <Offset>[const Offset(0.2, 0.4)];
    final stroke = FeedbackStroke(points: sourcePoints, color: 0xFFF04438, width: 7);
    sourcePoints.add(const Offset(0.6, 0.8));

    expect(stroke.points, hasLength(1));
  });

  test('rejects annotation points outside normalized screenshot coordinates', () {
    expect(
      () => FeedbackStroke(points: const <Offset>[Offset(1.1, 0.4)], color: 0xFFF04438, width: 7),
      throwsArgumentError,
    );
  });

  test('keeps support metadata immutable in a report context', () {
    final metadata = <String, String>{'environment': 'staging'};
    final context = FeedbackContext(
      appVersion: '1.4.0',
      buildNumber: '42',
      platform: FeedbackPlatform.android,
      screenName: 'checkout.payment',
      metadata: metadata,
    );
    metadata['environment'] = 'production';

    expect(context.appVersion, '1.4.0');
    expect(context.platform, FeedbackPlatform.android);
    expect(context.metadata, <String, String>{'environment': 'staging'});
  });

  test('exposes typed feedback delivery results', () {
    const success = FeedbackSubmissionSuccess(reference: 'feedback-42', message: 'Task was created.');
    const failure = FeedbackSubmissionFailure(message: 'Could not send feedback.', isRetryable: false);

    expect(success.reference, 'feedback-42');
    expect(success.message, 'Task was created.');
    expect(failure.isRetryable, isFalse);
  });
}
