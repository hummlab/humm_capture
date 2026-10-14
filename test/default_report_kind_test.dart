import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humm_capture/humm_capture.dart';

void main() {
  for (final kind in FeedbackReportKind.values) {
    testWidgets('starts with host default $kind and permits switching', (tester) async {
      final controller = FeedbackCaptureController();
      final reporter = _RecordingReporter();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedbackCaptureBoundary(
              controller: controller,
              reporter: reporter,
              defaultKind: kind,
              trigger: FeedbackTrigger.none,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      controller.addSystemScreenshot(
        bytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aN1sAAAAASUVORK5CYII=',
        ),
      );
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      final label = kind == FeedbackReportKind.bug ? 'Bug' : 'Feedback';
      final other = kind == FeedbackReportKind.bug ? 'Feedback' : 'Bug';
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(other));
      await tester.pumpAndSettle();
      expect(find.text(other), findsOneWidget);
      expect(find.text(label), findsNothing);
    });
  }
  test('default boundary report kind is Bug', () {
    expect(
      FeedbackCaptureBoundary(reporter: _RecordingReporter(), child: const SizedBox()).defaultKind,
      FeedbackReportKind.bug,
    );
  });
}

class _RecordingReporter implements FeedbackReporter {
  FeedbackReport? report;
  @override
  Future<FeedbackSubmissionResult> submit(FeedbackReport value) async {
    report = value;
    return const FeedbackSubmissionSuccess();
  }
}
