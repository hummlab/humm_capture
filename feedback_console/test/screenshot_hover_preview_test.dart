import 'package:feedback_console/src/screenshot_hover_preview.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final height in [600.0, 340.0]) {
    testWidgets('hover fits height $height, stays outside text and disappears on exit', (tester) async {
      tester.view.physicalSize = Size(1000, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.only(left: 250, top: 40),
              child: ScreenshotHoverPreview(
                preview: Center(child: Text('Large preview')),
                child: SizedBox(
                  width: 650,
                  height: 72,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(key: Key('thumbnail'), width: 48, height: 72),
                      SizedBox(width: 20),
                      Text('Report description'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byKey(const Key('thumbnail'))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Large preview'), findsOneWidget);
      final preview = tester.getRect(find.byWidgetPredicate((widget) => widget is Material && widget.elevation == 6));
      expect(preview.top, greaterThanOrEqualTo(12));
      expect(preview.bottom, lessThanOrEqualTo(height - 12));
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.text('Large preview')).right,
        lessThan(tester.getRect(find.text('Report description')).left),
      );
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      expect(find.text('Large preview'), findsNothing);
      await mouse.moveTo(tester.getCenter(find.text('Report description')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Large preview'), findsOneWidget);
      await mouse.moveTo(Offset.zero);
      await tester.pump();
      await mouse.moveTo(const Offset(850, 75));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Large preview'), findsOneWidget);
      await mouse.removePointer();
    });
  }
}
