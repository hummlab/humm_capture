import 'package:feedback_console/src/feedback_image_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery switches images by keyboard, retries failures and closes', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => FeedbackImageGallery(
                  images: [
                    FeedbackGalleryImage(label: 'Screenshot', loadUrl: () async => null),
                    FeedbackGalleryImage(
                      label: 'Profile photo',
                      loadUrl: () async {
                        attempts++;
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Could not load image.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(attempts, 1);
    await tester.tap(find.text('Retry image'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackImageGallery), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape closes after Next reaches the last image', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => FeedbackImageGallery(
                images: [
                  FeedbackGalleryImage(label: 'Before', loadUrl: () async => null),
                  FeedbackGalleryImage(label: 'After', loadUrl: () async => null),
                ],
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next image'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(FocusManager.instance.primaryFocus?.debugLabel, 'Feedback gallery');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackImageGallery), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gallery handles narrow viewport and long file names', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackImageGallery(
          images: [
            FeedbackGalleryImage(
              label: 'A very long screenshot file name from a tester.png',
              loadUrl: () async => null,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
