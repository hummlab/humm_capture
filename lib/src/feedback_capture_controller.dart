import 'dart:typed_data';

import 'feedback_capture_boundary.dart';

/// Opens feedback capture from an application-defined action.
final class FeedbackCaptureController {
  FeedbackCaptureBoundaryState? _state;

  /// Attaches the currently mounted feedback boundary.
  @pragma('vm:prefer-inline')
  void attach(FeedbackCaptureBoundaryState state) {
    _state = state;
  }

  /// Detaches a feedback boundary that is no longer mounted.
  @pragma('vm:prefer-inline')
  void detach(FeedbackCaptureBoundaryState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }

  /// Captures the wrapped Flutter view and opens the feedback composer.
  Future<void> captureAppView() {
    final state = _state;
    if (state == null) {
      throw StateError('FeedbackCaptureBoundary is not mounted.');
    }
    return state.captureAppView();
  }

  /// Opens the composer with a device screenshot supplied by the host app.
  void addSystemScreenshot({required Uint8List bytes, String? fileName, String mimeType = 'image/png'}) {
    final state = _state;
    if (state == null) {
      throw StateError('FeedbackCaptureBoundary is not mounted.');
    }
    state.addSystemScreenshot(bytes: bytes, fileName: fileName, mimeType: mimeType);
  }
}
