import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Identifies the platform on which feedback was created.
enum FeedbackPlatform {
  /// Android application.
  android,

  /// iOS application.
  ios,

  /// Web application.
  web,

  /// macOS application.
  macos,

  /// Windows application.
  windows,

  /// Linux application.
  linux,

  /// A platform that the host application does not identify.
  unknown,
}

/// Optional support context captured with a [FeedbackReport].
///
/// The host application supplies this data explicitly. The SDK does not read
/// account identifiers, diagnostics, route names, or analytics automatically.
@immutable
final class FeedbackContext {
  /// Creates explicitly supplied support context.
  FeedbackContext({
    this.appVersion,
    this.buildNumber,
    this.platform = FeedbackPlatform.unknown,
    this.operatingSystemVersion,
    this.screenName,
    this.locale,
    this.userId,
    Map<String, String> metadata = const <String, String>{},
  }) : metadata = Map<String, String>.unmodifiable(metadata);

  /// Human-readable application version supplied by the host.
  final String? appVersion;

  /// Build identifier supplied by the host.
  final String? buildNumber;

  /// Platform on which the report was captured.
  final FeedbackPlatform platform;

  /// Operating-system version supplied by the host.
  final String? operatingSystemVersion;

  /// Current screen, route, or feature identifier supplied by the host.
  final String? screenName;

  /// Active locale supplied by the host.
  final String? locale;

  /// Optional user identifier supplied intentionally by the host.
  final String? userId;

  /// Additional serializable support fields supplied by the host.
  final Map<String, String> metadata;
}

/// Identifies how an image was obtained for a feedback report.
enum FeedbackImageSource {
  /// Pixels rendered by the Flutter application.
  inApp,

  /// An image supplied by the user, for example a device screenshot.
  systemScreenshot,
}

/// Classifies a visual report before it is delivered to the host application.
enum FeedbackReportKind {
  /// General product or UX feedback.
  feedback,

  /// A reproducible defect or unexpected application behaviour.
  bug;

  /// Portable value used by destination adapters.
  String get value => name;

  /// Short label used by the default composer.
  String get label => switch (this) {
    FeedbackReportKind.feedback => 'Feedback',
    FeedbackReportKind.bug => 'Bug',
  };
}

/// A screenshot attached to a feedback report.
@immutable
final class FeedbackImage {
  /// Creates an image attachment.
  const FeedbackImage({required this.bytes, required this.source, this.fileName, this.mimeType = 'image/png'});

  /// Raw image bytes.
  final Uint8List bytes;

  /// Origin of the image.
  final FeedbackImageSource source;

  /// Optional source file name.
  final String? fileName;

  /// MIME type associated with [bytes].
  final String mimeType;
}

/// A completed report ready to be persisted by the host application.
@immutable
final class FeedbackReport {
  /// Creates a report.
  FeedbackReport({
    required this.image,
    required this.createdAt,
    List<FeedbackStroke> strokes = const <FeedbackStroke>[],
    this.message,
    this.context,
    this.kind = FeedbackReportKind.feedback,
    this.requestTaskCreation = false,
    List<FeedbackAttachment> attachments = const <FeedbackAttachment>[],
    List<FeedbackLogEntry> logs = const <FeedbackLogEntry>[],
  }) : strokes = List<FeedbackStroke>.unmodifiable(strokes),
       attachments = List<FeedbackAttachment>.unmodifiable(attachments),
       logs = List<FeedbackLogEntry>.unmodifiable(logs);

  /// Main screenshot associated with the report.
  final FeedbackImage image;

  /// Time at which the feedback flow started.
  final DateTime createdAt;

  /// Marker strokes drawn over [image], using coordinates normalized to 0–1.
  final List<FeedbackStroke> strokes;

  /// Optional tester description.
  final String? message;

  /// Optional application and support context captured with the report.
  final FeedbackContext? context;

  /// Classification selected by the reporter.
  final FeedbackReportKind kind;

  /// Whether the reporter requested that the destination creates a linked task.
  ///
  /// The destination must validate this request against its own authorization
  /// rules; client-side UI is never an authorization boundary.
  final bool requestTaskCreation;

  /// Optional user-supplied images or videos associated with the report.
  final List<FeedbackAttachment> attachments;

  /// Explicit diagnostic records supplied by the host application.
  ///
  /// The SDK never collects application logs implicitly.
  final List<FeedbackLogEntry> logs;
}

/// An image or video attached intentionally by the reporter.
@immutable
final class FeedbackAttachment {
  /// Creates a binary feedback attachment.
  FeedbackAttachment({required this.bytes, required this.fileName, required this.mimeType}) {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'A feedback attachment cannot be empty.');
    }
    if (!mimeType.startsWith('image/') && !mimeType.startsWith('video/')) {
      throw ArgumentError.value(mimeType, 'mimeType', 'Only image and video attachments are supported.');
    }
  }

  /// Raw attachment bytes.
  final Uint8List bytes;

  /// Display name supplied by the platform picker.
  final String fileName;

  /// MIME type associated with [bytes].
  final String mimeType;
}

/// A diagnostic record explicitly supplied by the host application.
@immutable
final class FeedbackLogEntry {
  /// Creates a serializable diagnostic record.
  const FeedbackLogEntry({
    required this.timestamp,
    required this.message,
    this.level = FeedbackLogLevel.info,
    this.category,
  });

  /// Local time at which the host application recorded the entry.
  final DateTime timestamp;

  /// Human-readable diagnostic message.
  final String message;

  /// Severity chosen by the host application.
  final FeedbackLogLevel level;

  /// Optional subsystem or feature label.
  final String? category;
}

/// Severity values for explicitly supplied feedback logs.
enum FeedbackLogLevel {
  /// Informational record.
  info,

  /// Non-fatal unusual condition.
  warning,

  /// Error observed by the host application.
  error;

  /// Portable value used by destination adapters.
  String get value => name;
}

/// A freehand marker stroke represented independently of the screenshot size.
@immutable
final class FeedbackStroke {
  /// Creates a marker stroke.
  FeedbackStroke({required List<Offset> points, required this.color, required this.width})
    : points = List<Offset>.unmodifiable(points) {
    if (points.isEmpty) {
      throw ArgumentError.value(points, 'points', 'A feedback stroke must contain at least one point.');
    }
    if (width <= 0) {
      throw ArgumentError.value(width, 'width', 'A feedback stroke width must be greater than zero.');
    }
    if (points.any((point) => point.dx < 0 || point.dx > 1 || point.dy < 0 || point.dy > 1)) {
      throw ArgumentError.value(points, 'points', 'Feedback stroke points must use normalized values from 0 to 1.');
    }
  }

  /// Points normalized against the captured image width and height.
  final List<Offset> points;

  /// ARGB color value of the stroke.
  final int color;

  /// Width normalized against the shorter side of the captured image.
  ///
  /// Values from older reports may use logical pixels. Renderers should retain
  /// support for values greater than one while new strokes use a ratio.
  final double width;

  /// Returns a copy containing [points].
  FeedbackStroke copyWith({required List<Offset> points}) {
    return FeedbackStroke(points: points, color: color, width: width);
  }
}

/// A result returned by a [FeedbackReporter].
sealed class FeedbackSubmissionResult {
  /// Creates a feedback submission result.
  const FeedbackSubmissionResult();
}

/// Confirms that a reporter has accepted a feedback report.
@immutable
final class FeedbackSubmissionSuccess extends FeedbackSubmissionResult {
  /// Creates a successful submission result.
  const FeedbackSubmissionSuccess({this.reference, this.message});

  /// Optional external reference returned by the destination.
  final String? reference;

  /// Optional destination message, for example a linked-task warning.
  final String? message;
}

/// Describes a recoverable or terminal feedback delivery failure.
@immutable
final class FeedbackSubmissionFailure extends FeedbackSubmissionResult {
  /// Creates a failed submission result.
  const FeedbackSubmissionFailure({required this.message, this.isRetryable = true});

  /// User-facing explanation suitable for the feedback composer.
  final String message;

  /// Whether the user can safely try to submit the same report again.
  final bool isRetryable;
}

/// Delivers [FeedbackReport] instances to a destination selected by the host.
abstract interface class FeedbackReporter {
  /// Delivers a completed feedback report.
  Future<FeedbackSubmissionResult> submit(FeedbackReport report);
}

/// Allows a host application to replace the default delivery notices.
///
/// The composer closes after preparing the report. Delivery then continues in
/// the background, so these callbacks are suitable for host notifications and
/// analytics.
@immutable
final class FeedbackDeliveryCallbacks {
  /// Creates callbacks for feedback delivery lifecycle events.
  const FeedbackDeliveryCallbacks({this.onStarted, this.onCompleted});

  /// Invoked after the composer closes and background delivery begins.
  final VoidCallback? onStarted;

  /// Invoked when the destination accepts or rejects the report.
  final ValueChanged<FeedbackSubmissionResult>? onCompleted;
}

/// Supplies a context snapshot when a feedback flow starts.
typedef FeedbackContextProvider = FeedbackContext? Function();

/// Supplies the bounded diagnostic records that may travel with one report.
///
/// The host decides what is safe to include. Avoid credentials, message
/// bodies, contact data, and any other sensitive values.
typedef FeedbackLogsProvider = List<FeedbackLogEntry> Function();

/// Opens a host-provided picker for image and video attachments.
///
/// The SDK keeps platform selection outside its core so applications can use
/// their existing picker, permissions, and media policy.
typedef FeedbackAttachmentsProvider = Future<List<FeedbackAttachment>> Function();

/// The type of media the reporter wants to attach.
enum FeedbackAttachmentType {
  /// A still image selected from the device gallery.
  image,

  /// A video selected from the device gallery.
  video,
}

/// Opens a host-provided gallery picker for one media type.
///
/// New integrations should use this callback so the composer can provide
/// separate, predictable choices for photos and video. The legacy
/// [FeedbackAttachmentsProvider] stays supported for source compatibility.
typedef FeedbackAttachmentPicker = Future<List<FeedbackAttachment>> Function(FeedbackAttachmentType type);

/// Checks whether the current user may request a linked task for feedback.
///
/// Return `true` only after an application-controlled backend has checked both
/// the integration and the user's permission. Returning `false` hides the
/// optional task control from the default composer.
typedef FeedbackTaskCreationAvailabilityProvider = Future<bool> Function();

/// Controls which built-in gesture opens the feedback flow.
enum FeedbackTrigger {
  /// Opens feedback after a three-finger long press.
  threeFingerLongPress,

  /// Disables the built-in gesture; use [FeedbackCaptureController] instead.
  none,
}
