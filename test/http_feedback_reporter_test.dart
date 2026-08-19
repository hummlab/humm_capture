import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:humm_capture/humm_capture.dart';

void main() {
  group('HttpFeedbackReporter', () {
    test('serializes a report and returns the server reference', () async {
      late Map<String, Object?> body;
      final reporter = HttpFeedbackReporter(
        endpoint: Uri.parse('https://feedback.example.test/reports'),
        headersProvider: () => const {'authorization': 'Bearer tester-token'},
        client: MockClient((request) async {
          body = Map<String, Object?>.from(jsonDecode(request.body) as Map);
          expect(request.headers['authorization'], 'Bearer tester-token');
          expect(request.headers['content-type'], 'application/json');
          return http.Response('{"feedbackId":"report-42"}', 201);
        }),
      );

      final result = await reporter.submit(_report());

      expect(result, isA<FeedbackSubmissionSuccess>());
      expect((result as FeedbackSubmissionSuccess).reference, 'report-42');
      expect(body['contentType'], 'image/png');
      expect(body['imageSource'], 'in_app');
      expect(body['message'], 'Primary action is clipped');
      expect(body['kind'], 'bug');
      expect(body['requestTaskCreation'], isTrue);
      expect(body['attachments'], <Object?>[
        <String, Object?>{
          'fileName': 'reference.png',
          'mimeType': 'image/png',
          'dataBase64': base64Encode(<int>[4, 5, 6]),
        },
      ]);
      expect(body['context'], <String, Object>{'appVersion': '1.2.0', 'platform': 'android', 'screenName': 'checkout'});
    });

    test('marks authentication failures as non-retryable', () async {
      final reporter = HttpFeedbackReporter(
        endpoint: Uri.parse('https://feedback.example.test/reports'),
        client: MockClient((_) async => http.Response('{"error":"Not authorized."}', 401)),
      );

      final result = await reporter.submit(_report());

      expect(result, isA<FeedbackSubmissionFailure>());
      expect((result as FeedbackSubmissionFailure).isRetryable, isFalse);
      expect(result.message, 'Not authorized.');
    });

    test('requires HTTPS unless local HTTP is explicitly enabled', () {
      expect(() => HttpFeedbackReporter(endpoint: Uri.parse('http://localhost:8080/feedback')), throwsArgumentError);
      expect(
        () => HttpFeedbackReporter(endpoint: Uri.parse('http://localhost:8080/feedback'), allowInsecureHttp: true),
        returnsNormally,
      );
    });
  });
}

FeedbackReport _report() => FeedbackReport(
  image: FeedbackImage(bytes: Uint8List.fromList(<int>[1, 2, 3]), source: FeedbackImageSource.inApp),
  createdAt: DateTime.utc(2026, 8, 17),
  message: 'Primary action is clipped',
  kind: FeedbackReportKind.bug,
  requestTaskCreation: true,
  context: FeedbackContext(appVersion: '1.2.0', platform: FeedbackPlatform.android, screenName: 'checkout'),
  strokes: <FeedbackStroke>[
    FeedbackStroke(points: const <Offset>[Offset(0.2, 0.3)], color: 0xff4d2fe8, width: 4),
  ],
  attachments: <FeedbackAttachment>[
    FeedbackAttachment(bytes: Uint8List.fromList(<int>[4, 5, 6]), fileName: 'reference.png', mimeType: 'image/png'),
  ],
);
