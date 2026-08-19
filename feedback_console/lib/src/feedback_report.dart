import 'package:cloud_firestore/cloud_firestore.dart';

/// Lifecycle values understood by the initial Feedback Console.
enum FeedbackStatus {
  newReport('new', 'New'),
  inReview('in_review', 'In review'),
  resolved('resolved', 'Resolved'),
  rejected('rejected', 'Rejected');

  const FeedbackStatus(this.value, this.label);

  final String value;
  final String label;

  static FeedbackStatus fromValue(Object? value) =>
      FeedbackStatus.values.firstWhere((status) => status.value == value, orElse: () => FeedbackStatus.newReport);
}

/// Classification supplied by the mobile feedback SDK.
enum FeedbackReportKind {
  feedback('feedback', 'Feedback'),
  bug('bug', 'Bug');

  const FeedbackReportKind(this.value, this.label);

  final String value;
  final String label;

  static FeedbackReportKind fromValue(Object? value) => value == bug.value ? bug : feedback;
}

/// A feedback-specific console role assigned to an existing application user.
enum FeedbackConsoleRole {
  admin('admin', 'Admin'),
  reviewer('reviewer', 'Reviewer');

  const FeedbackConsoleRole(this.value, this.label);

  final String value;
  final String label;

  static FeedbackConsoleRole? fromValue(Object? value) {
    for (final role in FeedbackConsoleRole.values) {
      if (role.value == value) return role;
    }
    return null;
  }
}

DateTime? _dateTimeValue(Object? value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime dateTime => dateTime,
  String value => DateTime.tryParse(value),
  _ => null,
};

/// A feedback record persisted by an application's server-side intake.
final class FeedbackReport {
  const FeedbackReport({
    required this.id,
    required this.applicationName,
    required this.applicationId,
    required this.message,
    required this.kind,
    this.reportNumber,
    required this.status,
    required this.createdAt,
    required this.platform,
    required this.appVersion,
    this.buildNumber,
    this.screenName,
    this.osVersion,
    this.deviceModel,
    this.locale,
    this.capturedAt,
    this.screenshotPath,
    this.logsPath,
    this.annotationCount = 0,
    this.attachments = const <FeedbackReportAttachment>[],
    this.logs = const <FeedbackReportLogEntry>[],
    this.jiraIssueKey,
    this.jiraIssueUrl,
  });

  final String id;
  final String applicationName;
  final String applicationId;
  final String message;
  final FeedbackReportKind kind;
  final int? reportNumber;
  final FeedbackStatus status;
  final DateTime? createdAt;
  final String platform;
  final String appVersion;
  final String? buildNumber;
  final String? screenName;
  final String? osVersion;
  final String? deviceModel;
  final String? locale;
  final DateTime? capturedAt;
  final String? screenshotPath;
  final String? logsPath;
  final int annotationCount;
  final List<FeedbackReportAttachment> attachments;
  final List<FeedbackReportLogEntry> logs;
  final String? jiraIssueKey;
  final String? jiraIssueUrl;

  String get reference => reportNumber == null ? kind.label : '${kind.label} #$reportNumber';

  /// A new report already has a stable server-side number. Older reports are
  /// numbered lazily by the backend when their first Jira task is created.
  String get referenceForJira => reportNumber == null ? '' : reference;

  factory FeedbackReport.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final context = data['context'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final metadata = context['metadata'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final rawReportNumber = data['reportNumber'];
    return FeedbackReport(
      id: snapshot.id,
      applicationName: data['applicationName'] as String? ?? 'Unknown app',
      applicationId: data['applicationId'] as String? ?? 'unknown',
      message: data['message'] as String? ?? '',
      kind: FeedbackReportKind.fromValue(data['kind']),
      reportNumber: rawReportNumber is num ? rawReportNumber.toInt() : null,
      status: FeedbackStatus.fromValue(data['status']),
      createdAt: _dateTimeValue(data['createdAt']),
      platform: context['platform'] as String? ?? 'unknown',
      appVersion: context['appVersion'] as String? ?? 'Unknown version',
      buildNumber: context['buildNumber'] as String?,
      screenName: context['screenName'] as String?,
      osVersion: context['operatingSystemVersion'] as String?,
      deviceModel: metadata['deviceModel'] as String? ?? metadata['device'] as String?,
      locale: context['locale'] as String?,
      capturedAt: _dateTimeValue(data['capturedAt']),
      screenshotPath: data['screenshotPath'] as String?,
      logsPath: data['logsPath'] as String?,
      annotationCount: data['annotationCount'] as int? ?? 0,
      attachments: _feedbackAttachments(data['attachments']),
      logs: _feedbackLogs(data['logs']),
      jiraIssueKey: data['jiraIssueKey'] as String?,
      jiraIssueUrl: data['jiraIssueUrl'] as String?,
    );
  }
}

List<FeedbackReportAttachment> _feedbackAttachments(Object? value) {
  if (value is! List) return const <FeedbackReportAttachment>[];
  return value
      .whereType<Map<Object?, Object?>>()
      .map((entry) => FeedbackReportAttachment.fromMap(entry.map((key, value) => MapEntry(key.toString(), value))))
      .whereType<FeedbackReportAttachment>()
      .toList(growable: false);
}

/// A private image or video selected intentionally by a feedback reporter.
final class FeedbackReportAttachment {
  const FeedbackReportAttachment({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String path;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  bool get isVideo => mimeType.startsWith('video/');

  static FeedbackReportAttachment? fromMap(Map<String, Object?> value) {
    final path = value['path'];
    final fileName = value['fileName'];
    final mimeType = value['mimeType'];
    final sizeBytes = value['sizeBytes'];
    if (path is! String ||
        path.isEmpty ||
        fileName is! String ||
        fileName.isEmpty ||
        mimeType is! String ||
        mimeType.isEmpty) {
      return null;
    }
    return FeedbackReportAttachment(
      path: path,
      fileName: fileName,
      mimeType: mimeType,
      sizeBytes: sizeBytes is num ? sizeBytes.toInt() : 0,
    );
  }
}

List<FeedbackReportLogEntry> _feedbackLogs(Object? value) {
  if (value is! List) return const <FeedbackReportLogEntry>[];
  return value
      .whereType<Map<Object?, Object?>>()
      .map((entry) => FeedbackReportLogEntry.fromMap(entry.map((key, value) => MapEntry(key.toString(), value))))
      .whereType<FeedbackReportLogEntry>()
      .toList(growable: false);
}

/// A bounded diagnostic entry submitted with a feedback report.
final class FeedbackReportLogEntry {
  const FeedbackReportLogEntry({required this.timestamp, required this.level, required this.message, this.category});

  final DateTime timestamp;
  final String level;
  final String message;
  final String? category;

  static FeedbackReportLogEntry? fromMap(Map<String, Object?> value) {
    final timestamp = _dateTimeValue(value['timestamp']);
    final message = value['message'];
    if (timestamp == null || message is! String || message.trim().isEmpty) return null;
    final category = value['category'];
    return FeedbackReportLogEntry(
      timestamp: timestamp,
      level: value['level'] is String ? value['level'] as String : 'info',
      message: message.trim(),
      category: category is String && category.trim().isNotEmpty ? category.trim() : null,
    );
  }
}

/// A person who already has an account in the host application's Firebase Auth.
final class FeedbackMember {
  const FeedbackMember({
    required this.id,
    required this.email,
    required this.displayName,
    this.consoleRole,
    this.canCreateJiraTasks = false,
  });

  final String id;
  final String email;
  final String? displayName;
  final FeedbackConsoleRole? consoleRole;
  final bool canCreateJiraTasks;

  String get label => displayName?.trim().isNotEmpty == true ? displayName! : email;

  bool get canManageFeedbackAccess => consoleRole == FeedbackConsoleRole.admin;

  factory FeedbackMember.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final consoleRole = data['role'] == FeedbackConsoleRole.admin.value
        ? FeedbackConsoleRole.admin
        : FeedbackConsoleRole.fromValue(data['feedbackRole']);
    return FeedbackMember(
      id: snapshot.id,
      email: data['email'] as String? ?? 'Unknown user',
      displayName: data['displayName'] as String?,
      consoleRole: consoleRole,
      canCreateJiraTasks: data['feedbackCanCreateJiraTasks'] == true,
    );
  }
}

/// An immutable event written alongside a feedback status transition.
final class FeedbackStatusEvent {
  const FeedbackStatusEvent({
    required this.id,
    required this.fromStatus,
    required this.toStatus,
    required this.actorLabel,
    required this.createdAt,
  });

  final String id;
  final FeedbackStatus fromStatus;
  final FeedbackStatus toStatus;
  final String actorLabel;
  final DateTime? createdAt;

  factory FeedbackStatusEvent.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    return FeedbackStatusEvent(
      id: snapshot.id,
      fromStatus: FeedbackStatus.fromValue(data['fromStatus']),
      toStatus: FeedbackStatus.fromValue(data['toStatus']),
      actorLabel: data['actorLabel'] as String? ?? 'Unknown user',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
