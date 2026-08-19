import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'feedback_annotation_canvas.dart';
import 'feedback_annotation_toolbar.dart';
import 'feedback_composer_attachments.dart';
import 'feedback_composer_chrome.dart';
import 'feedback_message_field.dart';
import 'feedback_models.dart';

/// The default feedback editor displayed over a captured image.
class FeedbackComposer extends StatefulWidget {
  /// Creates the default composer.
  const FeedbackComposer({
    required this.image,
    required this.onCancel,
    required this.onSubmit,
    this.context,
    this.attachmentPicker,
    this.attachmentsProvider,
    this.logsProvider,
    @Deprecated('Jira task creation is handled from the Feedback Console.') this.taskCreationAvailabilityProvider,
    super.key,
  });

  /// Image being annotated.
  final FeedbackImage image;

  /// Closes the composer without sending a report.
  final VoidCallback onCancel;

  /// Hands the completed report to the feedback boundary for delivery.
  final ValueChanged<FeedbackReport> onSubmit;

  /// Optional context captured at the start of the feedback flow.
  final FeedbackContext? context;

  /// Optional host-owned gallery picker separated by media type.
  final FeedbackAttachmentPicker? attachmentPicker;

  /// Optional legacy host-owned image and video picker.
  @Deprecated('Use attachmentPicker to distinguish photos and video.')
  final FeedbackAttachmentsProvider? attachmentsProvider;

  /// Optional host-owned diagnostic log snapshot provider.
  final FeedbackLogsProvider? logsProvider;

  /// Retained for source compatibility. Linked Jira tasks are created only
  /// from the Feedback Console.
  @Deprecated('Jira task creation is handled from the Feedback Console.')
  final FeedbackTaskCreationAvailabilityProvider? taskCreationAvailabilityProvider;

  @override
  State<FeedbackComposer> createState() => _FeedbackComposerState();
}

class _FeedbackComposerState extends State<FeedbackComposer> {
  // A marker should retain the underlying UI context, unlike a thin pen line.
  static const double _highlightStrokeWidth = 12;
  static const List<int> _markerColors = <int>[0x66F04438, 0x667A5AF8];

  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final List<FeedbackStroke> _strokes = <FeedbackStroke>[];
  final List<FeedbackAttachment> _attachments = <FeedbackAttachment>[];
  late final DateTime _createdAt;
  Size? _imageSize;
  bool _couldNotDecodeImage = false;
  int _selectedColor = _markerColors.first;
  int? _activePointer;
  bool _isSubmitting = false;
  bool _isKeyboardDismissing = false;
  bool _isAttachmentMenuOpen = false;
  bool _isManagingAttachments = false;
  FeedbackReportKind _selectedKind = FeedbackReportKind.feedback;

  @override
  void initState() {
    super.initState();
    _createdAt = DateTime.now();
    _messageFocusNode.addListener(_onMessageFocusChanged);
    _loadImageSize();
  }

  @override
  void dispose() {
    _messageFocusNode
      ..removeListener(_onMessageFocusChanged)
      ..dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _onMessageFocusChanged() {
    // iOS clears focus at the beginning of its keyboard-dismissal animation.
    // Restore surrounding controls at that point, rather than after the
    // keyboard's final inset update.
    final isDismissing = !_messageFocusNode.hasFocus;
    if (_isKeyboardDismissing == isDismissing) return;
    setState(() => _isKeyboardDismissing = isDismissing);
  }

  void _finishWriting() => _messageFocusNode.unfocus();

  Future<void> _loadImageSize() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.image.bytes);
      final Size size;
      try {
        final frame = await codec.getNextFrame();
        final image = frame.image;
        try {
          size = Size(image.width.toDouble(), image.height.toDouble());
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
      if (mounted) setState(() => _imageSize = size);
    } on Object {
      if (mounted) setState(() => _couldNotDecodeImage = true);
    }
  }

  void _startStroke(PointerDownEvent event, Size canvasSize) {
    if (_isSubmitting) return;
    _activePointer = event.pointer;
    setState(() {
      _strokes.add(
        FeedbackStroke(
          points: <Offset>[_normalize(event.localPosition, canvasSize)],
          color: _selectedColor,
          width: _highlightStrokeWidth / canvasSize.shortestSide,
        ),
      );
    });
  }

  void _continueStroke(PointerMoveEvent event, Size canvasSize) {
    if (_activePointer != event.pointer || _strokes.isEmpty) return;
    final latest = _strokes.removeLast();
    setState(() {
      _strokes.add(latest.copyWith(points: <Offset>[...latest.points, _normalize(event.localPosition, canvasSize)]));
    });
  }

  void _finishStroke(PointerEvent event) {
    if (_activePointer == event.pointer) _activePointer = null;
  }

  Offset _normalize(Offset position, Size size) {
    return Offset((position.dx / size.width).clamp(0, 1), (position.dy / size.height).clamp(0, 1));
  }

  void _undo() {
    if (_strokes.isEmpty || _isSubmitting) return;
    setState(_strokes.removeLast);
  }

  Future<void> _addAttachments(FeedbackAttachmentType type) async {
    final picker = widget.attachmentPicker;
    // ignore: deprecated_member_use_from_same_package
    final legacyProvider = widget.attachmentsProvider;
    if ((picker == null && legacyProvider == null) || _isSubmitting) return;
    setState(() => _isAttachmentMenuOpen = false);
    try {
      final picked = picker == null ? await legacyProvider!() : await picker(type);
      if (!mounted || picked.isEmpty) return;
      final totalCount = _attachments.length + picked.length;
      final totalBytes = <FeedbackAttachment>[
        ..._attachments,
        ...picked,
      ].fold<int>(0, (sum, attachment) => sum + attachment.bytes.length);
      if (totalCount > 4 || totalBytes > 10 * 1024 * 1024) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('Attach up to four files with a combined size of 10 MB.')));
        return;
      }
      setState(() => _attachments.addAll(picked));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Could not add media. Please try again.')));
    }
  }

  void _removeAttachment(FeedbackAttachment attachment) {
    if (_isSubmitting) return;
    setState(() => _attachments.remove(attachment));
  }

  void _manageAttachments() {
    if (_isSubmitting) return;
    setState(() {
      _isAttachmentMenuOpen = false;
      _isManagingAttachments = true;
    });
  }

  Future<void> _submit() async {
    final imageSize = _imageSize;
    if (imageSize == null) return;
    setState(() => _isSubmitting = true);
    try {
      final annotatedImage = await renderAnnotatedImage(image: widget.image, strokes: _strokes);
      if (!mounted) return;
      final message = _messageController.text.trim();
      widget.onSubmit(
        FeedbackReport(
          image: annotatedImage,
          createdAt: _createdAt,
          strokes: List<FeedbackStroke>.unmodifiable(_strokes),
          message: message.isEmpty ? null : message,
          context: widget.context,
          kind: _selectedKind,
          attachments: _attachments,
          logs: widget.logsProvider?.call() ?? const <FeedbackLogEntry>[],
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('Could not prepare feedback. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = _imageSize;
    final colorScheme = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final isKeyboardVisible = keyboardInset > 1;
    // Enter compact mode only once the keyboard begins opening. On dismissal,
    // restore all controls in parallel with the system keyboard animation.
    final isComposerCompact = isKeyboardVisible && !_isKeyboardDismissing;
    final canSubmit = !_isSubmitting && imageSize != null;
    return Positioned.fill(
      child: Material(
        color: colorScheme.surface,
        child: Padding(
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: SafeArea(
            // Keep SafeArea enabled throughout the keyboard transition.
            // MediaQuery interpolates its bottom padding with viewInsets;
            // toggling this boolean at zero inset caused a final layout jump.
            bottom: true,
            child: Builder(
              builder: (context) {
                final image = Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: imageSize == null
                      ? _couldNotDecodeImage
                            ? const FeedbackImageDecodeFailure()
                            : const Center(child: CircularProgressIndicator())
                      : FeedbackAnnotationCanvas(
                          image: widget.image,
                          imageSize: imageSize,
                          strokes: _strokes,
                          isEnabled: !_isSubmitting,
                          onPointerDown: _startStroke,
                          onPointerMove: _continueStroke,
                          onPointerFinished: _finishStroke,
                        ),
                );
                return Stack(
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        FeedbackComposerVisibility(
                          isVisible: !isComposerCompact,
                          child: FeedbackComposerHeader(onClose: widget.onCancel, isEnabled: !_isSubmitting),
                        ),
                        Expanded(child: image),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.09),
                                blurRadius: 10,
                                offset: const Offset(0, -3),
                              ),
                            ],
                          ),
                          child: AnimatedPadding(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            padding: EdgeInsets.fromLTRB(12, isComposerCompact ? 4 : 8, 12, isComposerCompact ? 8 : 12),
                            child: Column(
                              children: <Widget>[
                                FeedbackComposerVisibility(
                                  isVisible: !isComposerCompact,
                                  child: FeedbackAnnotationToolbar(
                                    colors: _markerColors,
                                    selectedColor: _selectedColor,
                                    selectedKind: _selectedKind,
                                    canUndo: _strokes.isNotEmpty && !_isSubmitting,
                                    onColorSelected: (color) => setState(() => _selectedColor = color),
                                    onUndo: _undo,
                                    onKindChanged: (kind) => setState(() => _selectedKind = kind),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  height: isComposerCompact ? 4 : 8,
                                ),
                                FeedbackMessageField(
                                  controller: _messageController,
                                  focusNode: _messageFocusNode,
                                  isEnabled: !_isSubmitting,
                                  onEditingComplete: _finishWriting,
                                  onHideKeyboard: isKeyboardVisible ? _finishWriting : null,
                                ),
                                FeedbackComposerVisibility(
                                  isVisible: !isComposerCompact,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: <Widget>[
                                        // ignore: deprecated_member_use_from_same_package
                                        if (widget.attachmentPicker != null || widget.attachmentsProvider != null)
                                          IconButton(
                                            tooltip: 'Media',
                                            onPressed: _isSubmitting
                                                ? null
                                                : () => setState(() => _isAttachmentMenuOpen = !_isAttachmentMenuOpen),
                                            icon: Badge(
                                              isLabelVisible: _attachments.isNotEmpty,
                                              label: Text('${_attachments.length}'),
                                              child: const Icon(Icons.attach_file_rounded),
                                            ),
                                          ),
                                        const Spacer(),
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            minimumSize: const Size(0, 44),
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: canSubmit ? _submit : null,
                                          icon: const Icon(Icons.send_rounded, size: 18),
                                          label: Text(_isSubmitting ? 'Preparing…' : 'Send feedback'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isAttachmentMenuOpen) ...<Widget>[
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(() => _isAttachmentMenuOpen = false),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 72,
                        child: FeedbackAttachmentActionMenu(
                          attachmentCount: _attachments.length,
                          onChoosePhotos: () => _addAttachments(FeedbackAttachmentType.image),
                          onChooseVideo: () => _addAttachments(FeedbackAttachmentType.video),
                          onManage: _manageAttachments,
                        ),
                      ),
                    ],
                    if (_isManagingAttachments)
                      Positioned.fill(
                        child: FeedbackAttachmentManager(
                          attachments: _attachments,
                          onClose: () => setState(() => _isManagingAttachments = false),
                          onRemove: _removeAttachment,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
