import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humm_capture/humm_capture.dart';

void main() {
  testWidgets('shows a recovery message instead of loading forever for an invalid system screenshot', (tester) async {
    final controller = FeedbackCaptureController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedbackCaptureBoundary(
            controller: controller,
            reporter: const _NoopReporter(),
            trigger: FeedbackTrigger.none,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    controller.addSystemScreenshot(bytes: Uint8List.fromList(<int>[0]), mimeType: 'image/png');
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    expect(find.text('This screenshot could not be opened.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

class _NoopReporter implements FeedbackReporter {
  const _NoopReporter();

  @override
  Future<FeedbackSubmissionResult> submit(FeedbackReport report) async => const FeedbackSubmissionSuccess();
}
