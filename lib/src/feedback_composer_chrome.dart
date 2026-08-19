import 'package:flutter/material.dart';

/// Header used while the default feedback composer is visible.
class FeedbackComposerHeader extends StatelessWidget {
  /// Creates a composer header.
  const FeedbackComposerHeader({required this.onClose, required this.isEnabled, super.key});

  /// Closes the composer.
  final VoidCallback onClose;

  /// Whether the close action is available.
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.09), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
        child: Row(
          children: <Widget>[
            Expanded(child: Text('Add feedback', style: Theme.of(context).textTheme.titleSmall)),
            IconButton(
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              padding: EdgeInsets.zero,
              onPressed: isEnabled ? onClose : null,
              icon: const Icon(Icons.close),
              tooltip: 'Close feedback',
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains why a host-supplied screenshot cannot be annotated.
class FeedbackImageDecodeFailure extends StatelessWidget {
  /// Creates an image decode failure state.
  const FeedbackImageDecodeFailure({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.broken_image_outlined, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('This screenshot could not be opened.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Close feedback and try again with a valid image.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Animates controls that are hidden while the keyboard is open.
class FeedbackComposerVisibility extends StatelessWidget {
  /// Creates a visibility transition for composer controls.
  const FeedbackComposerVisibility({required this.isVisible, required this.child, super.key});

  /// Whether the child is currently visible and interactive.
  final bool isVisible;

  /// Control to animate.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        heightFactor: isVisible ? 1 : 0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          opacity: isVisible ? 1 : 0,
          child: IgnorePointer(ignoring: !isVisible, child: child),
        ),
      ),
    );
  }
}
