import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:humm_capture/humm_capture.dart';

void main() {
  for (final enabled in [true, false]) {
    testWidgets('media action respects attachmentsEnabled=$enabled', (tester) async {
      final controller = FeedbackCaptureController();
      await tester.pumpWidget(
        MaterialApp(
          home: FeedbackCaptureBoundary(
            controller: controller,
            reporter: const _NoopReporter(),
            trigger: FeedbackTrigger.none,
            attachmentsEnabled: enabled,
            attachmentPicker: (_) async => [],
            child: const SizedBox.expand(),
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
      expect(find.byTooltip('Media'), enabled ? findsOneWidget : findsNothing);
      expect(find.text('Send feedback'), findsOneWidget);
    });
  }
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
