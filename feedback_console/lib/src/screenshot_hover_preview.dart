import 'dart:async';

import 'package:flutter/material.dart';

import 'console_theme.dart';

/// A thumbnail preview occupies the left gutter, never the report description.
/// Narrow layouts retain the normal click-to-open gallery interaction.
class ScreenshotHoverPreview extends StatefulWidget {
  const ScreenshotHoverPreview({required this.child, required this.preview, super.key});
  final Widget child;
  final Widget preview;
  @override
  State<ScreenshotHoverPreview> createState() => _ScreenshotHoverPreviewState();
}

class _ScreenshotHoverPreviewState extends State<ScreenshotHoverPreview> {
  final _controller = OverlayPortalController();
  final _anchor = GlobalKey();
  Timer? _delay;
  Rect? _position;

  void _show() {
    _delay?.cancel();
    _delay = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final box = _anchor.currentContext?.findRenderObject();
      final overlay = Overlay.of(context).context.findRenderObject();
      if (box is! RenderBox || overlay is! RenderBox) return;
      final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
      final available = origin.dx - 24;
      if (available < 120 || overlay.size.height < 340) return;
      final width = available.clamp(120.0, 300.0);
      final height = (width * 2.2).clamp(240.0, overlay.size.height - 24);
      _position = Rect.fromLTWH(
        origin.dx - width - 12,
        origin.dy.clamp(12.0, overlay.size.height - height - 12),
        width,
        height,
      );
      _controller.show();
    });
  }

  void _hide() {
    _delay?.cancel();
    _controller.hide();
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _controller,
    overlayChildBuilder: (_) => Positioned.fromRect(
      rect: _position!,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Material(
            color: ConsoleColors.surface,
            elevation: 6,
            shadowColor: ConsoleColors.ink.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: widget.preview,
          ),
        ),
      ),
    ),
    child: MouseRegion(
      key: _anchor,
      hitTestBehavior: HitTestBehavior.opaque,
      onEnter: (_) => _show(),
      onHover: (_) {
        if (!_controller.isShowing && !(_delay?.isActive ?? false)) _show();
      },
      onExit: (_) => _hide(),
      child: widget.child,
    ),
  );
}
