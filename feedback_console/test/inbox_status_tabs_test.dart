import 'package:feedback_console/src/feedback_report.dart';
import 'package:feedback_console/src/inbox_status_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('status navigation works with keyboard and remains reachable on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FeedbackStatus? selection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InboxStatusTabs(reports: const [], selected: null, onSelected: (value) => selection = value),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selection, FeedbackStatus.newReport);
    await tester.ensureVisible(find.text('Rejected'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rejected'));
    expect(selection, FeedbackStatus.rejected);
    expect(tester.takeException(), isNull);
  });
}
