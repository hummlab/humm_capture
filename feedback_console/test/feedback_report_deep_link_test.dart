import 'dart:async';

import 'package:feedback_console/src/feedback_report.dart';
import 'package:feedback_console/src/feedback_report_deep_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const report = FeedbackReport(
  id: 'report-123',
  applicationName: 'Test',
  applicationId: 'test',
  message: 'Example',
  kind: FeedbackReportKind.feedback,
  status: FeedbackStatus.newReport,
  createdAt: null,
  platform: 'android',
  appVersion: '1.0.1',
);

void main() {
  testWidgets('opens the linked report once, after data loads', (tester) async {
    final reports = StreamController<List<FeedbackReport>>();
    addTearDown(reports.close);
    final opened = <FeedbackReport>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedbackReportDeepLink(
            uri: Uri.parse('https://console.test/?feedback=report-123'),
            reports: reports.stream,
            onOpen: opened.add,
            child: const Text('Inbox'),
          ),
        ),
      ),
    );
    expect(opened, isEmpty);
    reports.add([report]);
    await tester.pump();
    expect(opened, [report]);
    reports.add([report]);
    await tester.pump();
    expect(opened, [report]);
  });

  testWidgets('missing reports show an unavailable message', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedbackReportDeepLink(
            uri: Uri.parse('https://console.test/?feedback=missing'),
            reports: Stream.value([report]),
            onOpen: (_) => fail('Must not open a different report'),
            child: const Text('Inbox'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Report is unavailable.'), findsOneWidget);
  });

  testWidgets('a normal console visit does not open any report', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedbackReportDeepLink(
            uri: Uri.parse('https://console.test/'),
            reports: Stream.value([report]),
            onOpen: (_) => fail('No report was requested'),
            child: const Text('Inbox'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Inbox'), findsOneWidget);
  });
}
