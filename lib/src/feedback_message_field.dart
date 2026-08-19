import 'package:flutter/material.dart';

/// Editable description field used by the default feedback composer.
class FeedbackMessageField extends StatelessWidget {
  /// Creates a message field for the current feedback report.
  const FeedbackMessageField({
    required this.controller,
    required this.focusNode,
    required this.isEnabled,
    required this.onEditingComplete,
    required this.onHideKeyboard,
    super.key,
  });

  /// Text controller owned by the composer.
  final TextEditingController controller;

  /// Focus node owned by the composer.
  final FocusNode focusNode;

  /// Whether feedback is currently editable.
  final bool isEnabled;

  /// Handles submission from the keyboard.
  final VoidCallback onEditingComplete;

  /// Hides the keyboard while writing, when available.
  final VoidCallback? onHideKeyboard;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: isEnabled,
        minLines: 1,
        maxLines: 2,
        textInputAction: TextInputAction.done,
        onEditingComplete: onEditingComplete,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
        cursorColor: colorScheme.primary,
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          hintText: 'Describe the issue or expected change…',
          suffixIcon: onHideKeyboard == null
              ? null
              : IconButton(
                  onPressed: onHideKeyboard,
                  icon: const Icon(Icons.keyboard_hide_rounded),
                  tooltip: 'Hide keyboard',
                ),
          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
