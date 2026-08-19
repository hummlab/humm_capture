import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'feedback_report.dart';
import 'firebase_console_config.dart';

sealed class JiraIssueCreationResult {
  const JiraIssueCreationResult();
}

final class JiraIssueCreationSuccess extends JiraIssueCreationResult {
  const JiraIssueCreationSuccess({required this.key, required this.url});

  final String key;
  final String url;
}

final class JiraIssueCreationFailure extends JiraIssueCreationResult {
  const JiraIssueCreationFailure(this.message);

  final String message;
}

/// Creates a Jira issue through the project's authenticated feedback backend.
/// Jira credentials and the screenshot never pass through the browser.
final class JiraIssueRepository {
  JiraIssueRepository({FirebaseAuth? auth, http.Client? client})
    : _auth = auth ?? FirebaseAuth.instance,
      _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;

  Future<JiraIssueCreationResult> createFor({
    required FeedbackReport report,
    required String summary,
    required bool includeAttachments,
  }) async {
    const config = FirebaseConsoleConfig.fromEnvironment();
    if (!config.hasFunctionsBaseUrl) {
      return const JiraIssueCreationFailure('This panel is not configured for the feedback backend.');
    }
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      return const JiraIssueCreationFailure('Sign in again to create a Jira issue.');
    }
    try {
      final response = await _client.post(
        Uri.parse('${config.functionsBaseUrl}/feedback-console/reports/${report.id}/jira-issue'),
        headers: <String, String>{'X-Firebase-Auth': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(<String, dynamic>{'summary': summary, 'includeAttachments': includeAttachments}),
      );
      final decoded = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return JiraIssueCreationFailure(decoded['message'] as String? ?? 'Jira issue could not be created.');
      }
      final key = decoded['key'] as String?;
      final url = decoded['url'] as String?;
      if (key == null || url == null) {
        return const JiraIssueCreationFailure('Jira did not return the created issue.');
      }
      return JiraIssueCreationSuccess(key: key, url: url);
    } on Exception {
      return const JiraIssueCreationFailure('Could not reach the feedback backend.');
    }
  }

  Map<String, dynamic> _decode(String source) {
    try {
      final value = jsonDecode(source);
      return value is Map<String, dynamic> ? value : const <String, dynamic>{};
    } on FormatException {
      return const <String, dynamic>{};
    }
  }
}
