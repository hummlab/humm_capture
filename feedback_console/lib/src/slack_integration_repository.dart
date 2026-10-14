import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'firebase_console_config.dart';

sealed class SlackIntegrationResult {
  const SlackIntegrationResult();
}

final class SlackIntegrationSuccess extends SlackIntegrationResult {
  const SlackIntegrationSuccess(this.status);
  final SlackConnectionStatus status;
}

final class SlackIntegrationFailure extends SlackIntegrationResult {
  const SlackIntegrationFailure(this.message);
  final String message;
}

final class SlackConnectionStatus {
  const SlackConnectionStatus({
    required this.connected,
    this.lastDeliveryStatus,
    this.lastDeliveredAt,
    this.messageSettings = const SlackMessageSettings(),
  });
  final SlackMessageSettings messageSettings;
  final bool connected;
  final String? lastDeliveryStatus;
  final DateTime? lastDeliveredAt;

  factory SlackConnectionStatus.fromJson(Map<String, dynamic> json) => SlackConnectionStatus(
    connected: json['connected'] == true,
    messageSettings: SlackMessageSettings.fromJson(json['messageSettings']),
    lastDeliveryStatus: json['lastDeliveryStatus'] is String ? json['lastDeliveryStatus'] as String : null,
    lastDeliveredAt: DateTime.tryParse('${json['lastDeliveredAt'] ?? ''}'),
  );
}

final class SlackMessageSettings {
  const SlackMessageSettings({
    this.feedbackHeading = 'New feedback',
    this.bugHeading = 'New bug',
    this.linkLabel = 'Open report',
    this.includeDescription = true,
  });
  final String feedbackHeading;
  final String bugHeading;
  final String linkLabel;
  final bool includeDescription;
  factory SlackMessageSettings.fromJson(Object? json) {
    if (json is! Map) return const SlackMessageSettings();
    return SlackMessageSettings(
      feedbackHeading: json['feedbackHeading'] as String? ?? 'New feedback',
      bugHeading: json['bugHeading'] as String? ?? 'New bug',
      linkLabel: json['linkLabel'] as String? ?? 'Open report',
      includeDescription: json['includeDescription'] != false,
    );
  }
  Map<String, Object> toJson() => {
    'feedbackHeading': feedbackHeading,
    'bugHeading': bugHeading,
    'linkLabel': linkLabel,
    'includeDescription': includeDescription,
  };
}

/// Talks only to the adopting application's backend. Never stores a webhook locally.
final class SlackIntegrationRepository {
  SlackIntegrationRepository({Future<String?> Function()? tokenProvider, http.Client? client})
    : _tokenProvider = tokenProvider ?? (() async => FirebaseAuth.instance.currentUser?.getIdToken()),
      _client = client ?? http.Client();

  final Future<String?> Function() _tokenProvider;
  final http.Client _client;

  void dispose() => _client.close();

  Future<SlackIntegrationResult> checkStatus(FirebaseConsoleConfig config) => _send(config, 'status', 'GET');
  Future<SlackIntegrationResult> connect(FirebaseConsoleConfig config, String webhook) =>
      _send(config, 'configuration', 'POST', webhook: webhook.trim());
  Future<SlackIntegrationResult> test(FirebaseConsoleConfig config) => _send(config, 'test', 'POST');
  Future<SlackIntegrationResult> disconnect(FirebaseConsoleConfig config) => _send(config, 'configuration', 'DELETE');
  Future<SlackIntegrationResult> saveMessageSettings(FirebaseConsoleConfig config, SlackMessageSettings settings) =>
      _send(config, 'settings', 'POST', messageSettings: settings);

  Future<SlackIntegrationResult> _send(
    FirebaseConsoleConfig config,
    String path,
    String method, {
    String? webhook,
    SlackMessageSettings? messageSettings,
  }) async {
    final base = Uri.tryParse(config.slackBackendUrl.trim());
    final local = base?.host == 'localhost' || base?.host == '127.0.0.1';
    if (base == null ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        (base.scheme != 'https' && !(local && base.scheme == 'http'))) {
      return const SlackIntegrationFailure(
        'Configure FEEDBACK_SLACK_FUNCTIONS_BASE_URL with your feedback Slack service URL.',
      );
    }
    try {
      final token = await _tokenProvider().timeout(const Duration(seconds: 15));
      if (token == null || token.isEmpty) return const SlackIntegrationFailure('Sign in to manage Slack.');
      final request = http.Request(
        method,
        Uri.parse('${base.toString().replaceFirst(RegExp(r'/+$'), '')}/feedback-console/slack/$path'),
      );
      request.headers['X-Firebase-Auth'] = 'Bearer $token';
      if (webhook != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode({'webhook': webhook});
      }
      if (messageSettings != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode({'messageSettings': messageSettings.toJson()});
      }
      final response = await _client.send(request).then(http.Response.fromStream).timeout(const Duration(seconds: 60));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const SlackIntegrationFailure('The Slack service returned an invalid response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SlackIntegrationFailure(switch (response.statusCode) {
          401 => 'Sign in again to manage Slack.',
          403 => 'Only feedback administrators can manage Slack.',
          412 => 'Check Secret Manager permissions and the saved Slack webhook.',
          400 => 'Use a valid Slack Incoming Webhook URL.',
          _ => 'The Slack service is unavailable. Try again.',
        });
      }
      return SlackIntegrationSuccess(SlackConnectionStatus.fromJson(decoded));
    } on Exception {
      return const SlackIntegrationFailure('Could not reach the Slack service. Check its URL and deployment.');
    }
  }
}
