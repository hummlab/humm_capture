import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'firebase_console_config.dart';

sealed class JiraIntegrationResult<T> {
  const JiraIntegrationResult();
}

final class JiraIntegrationSuccess<T> extends JiraIntegrationResult<T> {
  const JiraIntegrationSuccess(this.value);

  final T value;
}

final class JiraIntegrationFailure<T> extends JiraIntegrationResult<T> {
  const JiraIntegrationFailure(this.message);

  final String message;
}

final class JiraConnectionStatus {
  const JiraConnectionStatus({
    required this.isConfigured,
    required this.isConnected,
    this.siteUrl,
    this.projectKey,
    this.projectName,
    this.accountLabel,
    this.lastCheckedAt,
    this.message,
  });

  final bool isConfigured;
  final bool isConnected;
  final String? siteUrl;
  final String? projectKey;
  final String? projectName;
  final String? accountLabel;
  final DateTime? lastCheckedAt;
  final String? message;

  factory JiraConnectionStatus.fromJson(Map<String, dynamic> json) => JiraConnectionStatus(
    isConfigured: json['configured'] == true,
    isConnected: json['connected'] == true,
    siteUrl: json['siteUrl'] as String?,
    projectKey: json['projectKey'] as String?,
    projectName: json['projectName'] as String?,
    accountLabel: json['accountLabel'] as String?,
    lastCheckedAt: DateTime.tryParse(json['lastCheckedAt'] as String? ?? ''),
    message: json['message'] as String?,
  );
}

/// Calls the configured authenticated feedback backend. Jira credentials never
/// reach Firestore, browser persistence or a third-party endpoint.
final class JiraIntegrationRepository {
  JiraIntegrationRepository({FirebaseAuth? auth, http.Client? client})
    : _auth = auth ?? FirebaseAuth.instance,
      _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;

  Future<JiraIntegrationResult<JiraConnectionStatus>> checkStatus(FirebaseConsoleConfig config) =>
      _send(config: config, path: '/feedback-console/jira/status');

  Future<JiraIntegrationResult<JiraConnectionStatus>> configure({
    required FirebaseConsoleConfig config,
    required String siteUrl,
    required String projectKey,
    required String accountEmail,
    required String apiToken,
  }) => _send(
    config: config,
    path: '/feedback-console/jira/configuration',
    method: _RequestMethod.post,
    body: <String, String>{
      'siteUrl': siteUrl.trim(),
      'projectKey': projectKey.trim().toUpperCase(),
      'accountEmail': accountEmail.trim(),
      'apiToken': apiToken,
    },
  );

  Future<JiraIntegrationResult<JiraConnectionStatus>> remove(FirebaseConsoleConfig config) =>
      _send(config: config, path: '/feedback-console/jira/configuration', method: _RequestMethod.delete);

  Future<JiraIntegrationResult<JiraConnectionStatus>> _send({
    required FirebaseConsoleConfig config,
    required String path,
    Map<String, String>? body,
    _RequestMethod method = _RequestMethod.get,
  }) async {
    if (!config.hasFunctionsBaseUrl) {
      return const JiraIntegrationFailure('This build is not configured with a feedback backend URL.');
    }
    final token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      return const JiraIntegrationFailure('Sign in again to manage the Jira integration.');
    }
    try {
      final uri = Uri.parse('${config.functionsBaseUrl}$path');
      final headers = <String, String>{'X-Firebase-Auth': 'Bearer $token'};
      final response = switch (method) {
        _RequestMethod.get => await _client.get(uri, headers: headers),
        _RequestMethod.post => await _client.post(
          uri,
          headers: <String, String>{...headers, 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ),
        _RequestMethod.delete => await _client.delete(uri, headers: headers),
      };
      final decoded = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return JiraIntegrationFailure(decoded['message'] as String? ?? 'Jira integration could not be updated.');
      }
      return JiraIntegrationSuccess(JiraConnectionStatus.fromJson(decoded));
    } on Exception {
      return const JiraIntegrationFailure('Could not reach the feedback backend.');
    }
  }

  Map<String, dynamic> _decode(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
    } on FormatException {
      return const <String, dynamic>{};
    }
  }
}

enum _RequestMethod { get, post, delete }
