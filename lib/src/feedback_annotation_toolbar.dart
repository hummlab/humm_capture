import 'package:flutter/material.dart';

import 'feedback_models.dart';

/// Controls for selecting a marker color and changing annotation history.
class FeedbackAnnotationToolbar extends StatefulWidget {
  /// Creates annotation controls for the default composer.
  const FeedbackAnnotationToolbar({
    required this.colors,
    required this.selectedColor,
    required this.selectedKind,
    required this.canUndo,
    required this.onColorSelected,
    required this.onUndo,
    required this.onKindChanged,
    super.key,
  });

  /// Available ARGB marker colors.
  final List<int> colors;

  /// Currently selected marker color.
  final int selectedColor;

  /// Currently selected classification.
  final FeedbackReportKind selectedKind;

  /// Whether at least one annotation can be removed.
  final bool canUndo;

  /// Selects a marker color.
  final ValueChanged<int> onColorSelected;

  /// Removes the latest marker stroke.
  final VoidCallback onUndo;

  /// Changes the report classification.
  final ValueChanged<FeedbackReportKind> onKindChanged;

  @override
  State<FeedbackAnnotationToolbar> createState() => _FeedbackAnnotationToolbarState();
}

class _FeedbackAnnotationToolbarState extends State<FeedbackAnnotationToolbar> {
  final LayerLink _kindMenuLink = LayerLink();

  OverlayEntry? _kindMenuEntry;
  bool _isKindMenuOpen = false;

  void _toggleKindMenu() {
    if (_kindMenuEntry != null) {
      _closeKindMenu();
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }

    setState(() => _isKindMenuOpen = true);
    _kindMenuEntry = OverlayEntry(
      builder: (context) => Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _closeKindMenu),
          ),
          CompositedTransformFollower(
            link: _kindMenuLink,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            showWhenUnlinked: false,
            child: SizedBox(
              width: 184,
              child: _ReportKindMenu(value: widget.selectedKind, onSelected: _selectKind),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_kindMenuEntry!);
  }

  void _closeKindMenu() {
    _kindMenuEntry?.remove();
    _kindMenuEntry = null;
    if (mounted) {
      setState(() => _isKindMenuOpen = false);
    }
  }

  void _selectKind(FeedbackReportKind kind) {
    widget.onKindChanged(kind);
    _closeKindMenu();
  }

  @override
  void dispose() {
    _kindMenuEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                ...widget.colors.map(
                  (color) => _MarkerColorButton(
                    color: color,
                    isSelected: color == widget.selectedColor,
                    onPressed: () => widget.onColorSelected(color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: CompositedTransformTarget(
                    link: _kindMenuLink,
                    child: _ReportKindDropdownTrigger(
                      value: widget.selectedKind,
                      isOpen: _isKindMenuOpen,
                      onTap: _toggleKindMenu,
                    ),
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.canUndo ? widget.onUndo : null,
                  icon: const Icon(Icons.undo_rounded),
                  tooltip: 'Undo last highlight',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportKindDropdownTrigger extends StatelessWidget {
  const _ReportKindDropdownTrigger({required this.value, required this.isOpen, required this.onTap});

  final FeedbackReportKind value;
  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: <Widget>[
            Icon(value == FeedbackReportKind.bug ? Icons.bug_report_outlined : Icons.chat_bubble_outline, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 2),
            Icon(isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _ReportKindMenu extends StatelessWidget {
  const _ReportKindMenu({required this.value, required this.onSelected});

  final FeedbackReportKind value;
  final ValueChanged<FeedbackReportKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: FeedbackReportKind.values
            .map((kind) => _KindOption(kind: kind, isSelected: kind == value, onTap: () => onSelected(kind)))
            .toList(growable: false),
      ),
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({required this.kind, required this.isSelected, required this.onTap});

  final FeedbackReportKind kind;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: <Widget>[
              Icon(kind == FeedbackReportKind.bug ? Icons.bug_report_outlined : Icons.chat_bubble_outline, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(kind.label, style: Theme.of(context).textTheme.labelLarge)),
              if (isSelected) Icon(Icons.check_rounded, size: 16, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkerColorButton extends StatelessWidget {
  const _MarkerColorButton({required this.color, required this.isSelected, required this.onPressed});

  final int color;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 40, height: 44),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(color),
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: colorScheme.onSurface, width: 2) : null,
        ),
        child: const SizedBox.square(dimension: 20),
      ),
      tooltip: 'Choose highlight color',
    );
  }
}
