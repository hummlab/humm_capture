import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'feedback_models.dart';

/// Supplies request headers immediately before a feedback report is sent.
///
/// Use this to obtain a short-lived application access token from the host
/// application. Do not return an integration secret intended for a backend.
typedef FeedbackRequestHeadersProvider = FutureOr<Map<String, String>> Function();

/// Sends feedback reports as JSON to an application-controlled HTTP endpoint.
///
/// This reporter is deliberately destination-neutral. A Flutter client should
/// normally send to its own authenticated backend or Firebase Function. That
/// backend can persist the report itself or forward it with a server-only
/// integration credential.
final class HttpFeedbackReporter implements FeedbackReporter {
  /// Creates an HTTP reporter for an application-controlled [endpoint].
  ///
  /// HTTPS is required by default. Set [allowInsecureHttp] only for a local
  /// development endpoint. Supplying [client] makes the reporter testable and
  /// lets the host application choose a platform-specific HTTP client.
  HttpFeedbackReporter({
    required this.endpoint,
    FeedbackRequestHeadersProvider? headersProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.allowInsecureHttp = false,
  }) : _headersProvider = headersProvider ?? _emptyHeaders,
       _client = client ?? http.Client(),
       _ownsClient = client == null {
    if (endpoint.scheme != 'https' && !allowInsecureHttp) {
      throw ArgumentError.value(endpoint, 'endpoint', 'HTTPS is required unless allowInsecureHttp is true.');
    }
  }

  /// Application-controlled endpoint which accepts the JSON report contract.
  final Uri endpoint;

  /// Maximum time to wait for one delivery attempt.
  final Duration timeout;

  /// Whether a non-HTTPS endpoint is allowed for local development only.
  final bool allowInsecureHttp;

  final FeedbackRequestHeadersProvider _headersProvider;
  final http.Client _client;
  final bool _ownsClient;
  var _isClosed = false;

  /// Sends [report] as a portable JSON document.
  @override
  Future<FeedbackSubmissionResult> submit(FeedbackReport report) async {
    if (_isClosed) {
      return const FeedbackSubmissionFailure(message: 'Feedback delivery is no longer available.', isRetryable: false);
    }
    try {
      final suppliedHeaders = await _headersProvider();
      final headers = <String, String>{
        ...suppliedHeaders,
        'content-type': 'application/json',
        'accept': 'application/json',
      };
      final response = await _client
          .post(endpoint, headers: headers, body: jsonEncode(_encodeReport(report)))
          .timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return FeedbackSubmissionSuccess(
          reference: _responseReference(response.body),
          message: _responseSuccessMessage(response.body),
        );
      }
      return FeedbackSubmissionFailure(
        message: _responseMessage(response.body),
        isRetryable: response.statusCode == 408 || response.statusCode == 429 || response.statusCode >= 500,
      );
    } on TimeoutException {
      return const FeedbackSubmissionFailure(message: 'Sending feedback timed out. Please try again.');
    } on Exception {
      return const FeedbackSubmissionFailure(message: 'Feedback could not be sent. Please try again.');
    }
  }

  /// Releases the internally created client.
  ///
  /// Calling this has no effect on a client supplied by the host application.
  void close() {
    if (_ownsClient) _client.close();
    _isClosed = true;
  }

  static Map<String, String> _emptyHeaders() => const <String, String>{};

  static Map<String, Object?> _encodeReport(FeedbackReport report) {
    return <String, Object?>{
      'capturedAt': report.createdAt.toUtc().toIso8601String(),
      'imageBase64': base64Encode(report.image.bytes),
      'contentType': report.image.mimeType,
      'fileName': report.image.fileName,
      'imageSource': switch (report.image.source) {
        FeedbackImageSource.inApp => 'in_app',
        FeedbackImageSource.systemScreenshot => 'system_screenshot',
      },
      'message': report.message,
      'kind': report.kind.value,
      'requestTaskCreation': report.requestTaskCreation,
      if (report.attachments.isNotEmpty)
        'attachments': report.attachments
            .map(
              (attachment) => <String, String>{
                'fileName': attachment.fileName,
                'mimeType': attachment.mimeType,
                'dataBase64': base64Encode(attachment.bytes),
              },
            )
            .toList(growable: false),
      if (report.logs.isNotEmpty)
        'logs': report.logs
            .map(
              (entry) => <String, String>{
                'timestamp': entry.timestamp.toUtc().toIso8601String(),
                'level': entry.level.value,
                'message': entry.message,
                if (entry.category case final category?) 'category': category,
              },
            )
            .toList(growable: false),
      'annotationStrokes': report.strokes
          .map(
            (stroke) => <String, Object>{
              'color': stroke.color,
              'width': stroke.width,
              'points': stroke.points
                  .map((point) => <String, double>{'x': point.dx, 'y': point.dy})
                  .toList(growable: false),
            },
          )
          .toList(growable: false),
      'context': _encodeContext(report.context),
    }..removeWhere((_, value) => value == null);
  }

  static Map<String, Object>? _encodeContext(FeedbackContext? context) {
    if (context == null) return null;
    return <String, Object>{
      if (context.appVersion case final value?) 'appVersion': value,
      if (context.buildNumber case final value?) 'buildNumber': value,
      'platform': _platformValue(context.platform),
      if (context.operatingSystemVersion case final value?) 'operatingSystemVersion': value,
      if (context.screenName case final value?) 'screenName': value,
      if (context.locale case final value?) 'locale': value,
      if (context.userId case final value?) 'userId': value,
      if (context.metadata.isNotEmpty) 'metadata': context.metadata,
    };
  }

  static String _platformValue(FeedbackPlatform platform) => switch (platform) {
    FeedbackPlatform.android => 'android',
    FeedbackPlatform.ios => 'ios',
    FeedbackPlatform.web => 'web',
    FeedbackPlatform.macos => 'macos',
    FeedbackPlatform.windows => 'windows',
    FeedbackPlatform.linux => 'linux',
    FeedbackPlatform.unknown => 'unknown',
  };

  static String? _responseReference(String body) {
    final object = _responseObject(body);
    for (final key in <String>['feedbackId', 'reference', 'id']) {
      if (object?[key] case final String value when value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static String? _responseSuccessMessage(String body) {
    if (_responseObject(body)?['message'] case final String value when value.isNotEmpty && value.length <= 160) {
      return value;
    }
    return null;
  }

  static String _responseMessage(String body) {
    if (_responseObject(body)?['error'] case final String value when value.isNotEmpty && value.length <= 160) {
      return value;
    }
    return 'Feedback could not be sent. Please try again.';
  }

  static Map<String, Object?>? _responseObject(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      return Map<String, Object?>.from(decoded);
    } on FormatException {
      return null;
    }
  }
}
