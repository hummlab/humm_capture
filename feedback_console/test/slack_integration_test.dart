import 'dart:convert';

import 'package:feedback_console/src/firebase_console_config.dart';
import 'package:feedback_console/src/slack_integration_repository.dart';
import 'package:feedback_console/src/slack_integration_workspace.dart';
import 'package:feedback_console/src/feedback_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const config = FirebaseConsoleConfig(
  apiKey: '',
  appId: '',
  messagingSenderId: '',
  projectId: '',
  authDomain: '',
  storageBucket: '',
  functionsBaseUrl: 'https://jira-backend.example.test',
  slackFunctionsBaseUrl: 'https://slack-backend.example.test/feedbackSlackApi',
);

void main() {
  test('uses project Slack backend and verifies configuration without exposing a webhook', () async {
    final repository = SlackIntegrationRepository(
      tokenProvider: () async => 'test-id-token',
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://slack-backend.example.test/feedbackSlackApi/feedback-console/slack/status',
        );
        expect(request.headers['X-Firebase-Auth'], 'Bearer test-id-token');
        expect(request.method, 'GET');
        return http.Response('{"connected":true}', 200);
      }),
    );
    addTearDown(repository.dispose);
    final result = await repository.checkStatus(config);
    expect(result, isA<SlackIntegrationSuccess>());
    expect((result as SlackIntegrationSuccess).status.connected, isTrue);
  });

  test('connect sends webhook only in authenticated HTTPS request body', () async {
    final repository = SlackIntegrationRepository(
      tokenProvider: () async => 'token',
      client: MockClient((request) async {
        expect(request.url.toString(), isNot(contains('testwebhook')));
        expect(jsonDecode(request.body), {'webhook': 'https://hooks.slack.com/services/T/B/testwebhook'});
        expect(request.method, 'POST');
        return http.Response('{"connected":true}', 200);
      }),
    );
    addTearDown(repository.dispose);
    expect(
      await repository.connect(config, 'https://hooks.slack.com/services/T/B/testwebhook'),
      isA<SlackIntegrationSuccess>(),
    );
  });

  test('does not send without authentication', () async {
    final repository = SlackIntegrationRepository(
      tokenProvider: () async => null,
      client: MockClient((_) async {
        fail('Unauthenticated request must not leave the console.');
      }),
    );
    addTearDown(repository.dispose);
    expect(await repository.checkStatus(config), isA<SlackIntegrationFailure>());
  });

  test('denied access and malformed responses return typed failures', () async {
    for (final response in [http.Response('denied', 403), http.Response('not json', 200)]) {
      final repository = SlackIntegrationRepository(
        tokenProvider: () async => 'token',
        client: MockClient((_) async => response),
      );
      expect(await repository.checkStatus(config), isA<SlackIntegrationFailure>());
      repository.dispose();
    }
  });

  test('reads attachment paths from compatible backend metadata', () {
    for (final key in ['path', 'storagePath']) {
      final attachment = FeedbackReportAttachment.fromMap({
        key: 'feedback/report/photo.png',
        'fileName': 'photo.png',
        'mimeType': 'image/png',
        'sizeBytes': 42,
      });
      expect(attachment?.path, 'feedback/report/photo.png');
      expect(attachment?.isVideo, isFalse);
    }
  });

  testWidgets('connected Slack is read-only and offers test and remove actions', (tester) async {
    final repository = SlackIntegrationRepository(
      tokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('{"connected":true}', 200)),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlackIntegrationWorkspace(repository: repository, config: config),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Slack Webhook URL'), findsNothing);
    expect(find.text('Save message settings'), findsOneWidget);
    expect(find.text('Send test'), findsOneWidget);
    expect(find.text('Remove integration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disconnected Slack shows setup guidance and webhook field', (tester) async {
    final repository = SlackIntegrationRepository(
      tokenProvider: () async => 'token',
      client: MockClient((_) async => http.Response('{"connected":false}', 200)),
    );
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SlackIntegrationWorkspace(repository: repository, config: config),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Where to find the webhook'), findsOneWidget);
    expect(find.text('Slack Webhook URL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
