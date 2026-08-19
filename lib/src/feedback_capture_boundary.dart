import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'feedback_capture_controller.dart';
import 'feedback_composer.dart';
import 'feedback_models.dart';

/// Wraps an application view and opens a feedback composer after capture.
class FeedbackCaptureBoundary extends StatefulWidget {
  /// Creates a feedback capture boundary.
  const FeedbackCaptureBoundary({
    required this.child,
    required this.reporter,
    this.controller,
    this.contextProvider,
    this.attachmentPicker,
    this.attachmentsProvider,
    this.logsProvider,
    @Deprecated('Jira task creation is handled from the Feedback Console.') this.taskCreationAvailabilityProvider,
    this.deliveryCallbacks,
    this.trigger = FeedbackTrigger.threeFingerLongPress,
    this.capturePixelRatio = 1.5,
    super.key,
  }) : assert(capturePixelRatio > 0);

  /// Content rendered into an in-app screenshot.
  final Widget child;

  /// Destination selected by the host application for completed reports.
  final FeedbackReporter reporter;

  /// Optional imperative API for custom triggers and system screenshots.
  final FeedbackCaptureController? controller;

  /// Optional provider for a support-context snapshot captured with feedback.
  final FeedbackContextProvider? contextProvider;

  /// Optional host-owned gallery picker separated by media type.
  final FeedbackAttachmentPicker? attachmentPicker;

  /// Optional host-owned picker for image and video attachments.
  final FeedbackAttachmentsProvider? attachmentsProvider;

  /// Optional source of explicitly selected diagnostic records.
  final FeedbackLogsProvider? logsProvider;

  /// Retained for source compatibility. Linked Jira tasks are created only
  /// from the Feedback Console.
  @Deprecated('Jira task creation is handled from the Feedback Console.')
  final FeedbackTaskCreationAvailabilityProvider? taskCreationAvailabilityProvider;

  /// Optional hooks for background delivery lifecycle events.
  ///
  /// When omitted, the boundary shows brief English [SnackBar] notices where
  /// a [ScaffoldMessenger] is available.
  final FeedbackDeliveryCallbacks? deliveryCallbacks;

  /// Built-in gesture used to begin capture.
  final FeedbackTrigger trigger;

  /// Pixel ratio used for the generated in-app image.
  final double capturePixelRatio;

  @override
  State<FeedbackCaptureBoundary> createState() => FeedbackCaptureBoundaryState();
}

/// Mutable state backing [FeedbackCaptureBoundary].
class FeedbackCaptureBoundaryState extends State<FeedbackCaptureBoundary> {
  final GlobalKey _captureKey = GlobalKey();
  final Set<int> _activePointers = <int>{};
  final ValueNotifier<_DefaultDeliveryNotice> _deliveryNotice = ValueNotifier(const _DefaultDeliveryNotice.sending());
  Timer? _triggerTimer;
  Timer? _deliveryNoticeDismissTimer;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _deliverySnackBar;
  FeedbackImage? _image;
  FeedbackContext? _feedbackContext;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);
  }

  @override
  void didUpdateWidget(covariant FeedbackCaptureBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
  }

  @override
  void dispose() {
    _triggerTimer?.cancel();
    _deliveryNoticeDismissTimer?.cancel();
    _deliveryNotice.dispose();
    widget.controller?.detach(this);
    super.dispose();
  }

  /// Captures the Flutter view and presents the composer.
  Future<void> captureAppView() async {
    if (_isCapturing || _image != null) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final image = await _captureImage();
      final feedbackContext = widget.contextProvider?.call();
      if (mounted) {
        setState(() {
          _image = image;
          _feedbackContext = feedbackContext;
        });
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('Could not capture feedback. Please try again.')));
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  /// Opens the composer with a screenshot captured outside Flutter.
  void addSystemScreenshot({required Uint8List bytes, String? fileName, required String mimeType}) {
    if (_image != null) {
      return;
    }

    final feedbackContext = widget.contextProvider?.call();
    setState(() {
      _image = FeedbackImage(
        bytes: bytes,
        source: FeedbackImageSource.systemScreenshot,
        fileName: fileName,
        mimeType: mimeType,
      );
      _feedbackContext = feedbackContext;
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (widget.trigger == FeedbackTrigger.threeFingerLongPress && _activePointers.length == 3) {
      _triggerTimer = Timer(const Duration(milliseconds: 800), captureAppView);
    }
  }

  void _onPointerFinished(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 3) {
      _triggerTimer?.cancel();
      _triggerTimer = null;
    }
  }

  Future<FeedbackImage> _captureImage() async {
    final boundary = _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: widget.capturePixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Could not encode the feedback screenshot.');
      }

      return FeedbackImage(
        bytes: bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        source: FeedbackImageSource.inApp,
      );
    } finally {
      image.dispose();
    }
  }

  void _closeComposer() {
    setState(() {
      _image = null;
      _feedbackContext = null;
    });
  }

  void _submitReport(FeedbackReport report) {
    _closeComposer();
    _notifyDeliveryStarted();
    unawaited(_deliverReport(report));
  }

  Future<void> _deliverReport(FeedbackReport report) async {
    FeedbackSubmissionResult result;
    try {
      result = await widget.reporter.submit(report);
    } on Object {
      result = const FeedbackSubmissionFailure(message: 'Feedback could not be sent. Please try again.');
    }
    if (!mounted) return;
    if (widget.deliveryCallbacks?.onCompleted case final callback?) {
      callback(result);
      return;
    }
    switch (result) {
      case FeedbackSubmissionSuccess(:final message):
        _showDefaultDeliveryNotice(_DefaultDeliveryNotice.success(message ?? 'Feedback sent.'));
      case FeedbackSubmissionFailure(:final message):
        _showDefaultDeliveryNotice(_DefaultDeliveryNotice.failure(message));
    }
  }

  void _notifyDeliveryStarted() {
    final callback = widget.deliveryCallbacks?.onStarted;
    if (callback != null) {
      callback();
      return;
    }
    _showDefaultDeliveryNotice(const _DefaultDeliveryNotice.sending());
  }

  void _showDefaultDeliveryNotice(_DefaultDeliveryNotice notice) {
    _deliveryNoticeDismissTimer?.cancel();
    _deliveryNotice.value = notice;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    if (_deliverySnackBar == null) {
      _deliverySnackBar = messenger.showSnackBar(
        SnackBar(
          duration: const Duration(days: 1),
          content: ValueListenableBuilder<_DefaultDeliveryNotice>(
            valueListenable: _deliveryNotice,
            builder: (_, current, _) => _DefaultDeliveryNoticeContent(notice: current),
          ),
        ),
      );
      _deliverySnackBar!.closed.whenComplete(() {
        if (mounted) {
          _deliverySnackBar = null;
        }
      });
    }
    if (notice.isTerminal) {
      _deliveryNoticeDismissTimer = Timer(const Duration(seconds: 3), () {
        _deliverySnackBar?.close();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerFinished,
      onPointerCancel: _onPointerFinished,
      child: Stack(
        children: <Widget>[
          RepaintBoundary(key: _captureKey, child: widget.child),
          if (_image case final image?)
            FeedbackComposer(
              image: image,
              onCancel: _closeComposer,
              onSubmit: _submitReport,
              context: _feedbackContext,
              attachmentPicker: widget.attachmentPicker,
              attachmentsProvider: widget.attachmentsProvider,
              logsProvider: widget.logsProvider,
            ),
        ],
      ),
    );
  }
}

enum _DefaultDeliveryNoticeKind { sending, success, failure }

final class _DefaultDeliveryNotice {
  const _DefaultDeliveryNotice.sending() : kind = _DefaultDeliveryNoticeKind.sending, message = 'Sending feedback…';

  const _DefaultDeliveryNotice.success(this.message) : kind = _DefaultDeliveryNoticeKind.success;

  const _DefaultDeliveryNotice.failure(this.message) : kind = _DefaultDeliveryNoticeKind.failure;

  final _DefaultDeliveryNoticeKind kind;
  final String message;

  bool get isTerminal => kind != _DefaultDeliveryNoticeKind.sending;
}

class _DefaultDeliveryNoticeContent extends StatelessWidget {
  const _DefaultDeliveryNoticeContent({required this.notice});

  final _DefaultDeliveryNotice notice;

  @override
  Widget build(BuildContext context) {
    final icon = switch (notice.kind) {
      _DefaultDeliveryNoticeKind.sending => const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
      _DefaultDeliveryNoticeKind.success => const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
      _DefaultDeliveryNoticeKind.failure => const Icon(Icons.error_outline_rounded, color: Colors.white),
    };
    return Row(
      children: <Widget>[
        icon,
        const SizedBox(width: 12),
        Expanded(child: Text(notice.message)),
      ],
    );
  }
}
