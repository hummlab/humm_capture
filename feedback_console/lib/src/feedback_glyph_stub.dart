import 'package:flutter/widgets.dart';

enum FeedbackGlyphType { mark, inbox, people, search, chevronDown, signOut }

/// Lightweight text marks used by the standalone console.
///
/// The console needs to work in browsers where the Flutter web renderer does
/// not paint Material icon glyphs reliably. These short labels use the same
/// text-rendering path as the rest of the interface, so navigation never
/// degrades into empty controls.
class FeedbackGlyph extends StatelessWidget {
  const FeedbackGlyph(this.type, {this.size = 20, this.color, super.key});

  final FeedbackGlyphType type;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final glyph = switch (type) {
      FeedbackGlyphType.mark => 'F',
      FeedbackGlyphType.inbox => 'I',
      FeedbackGlyphType.people => 'A',
      FeedbackGlyphType.search => '',
      FeedbackGlyphType.chevronDown => 'v',
      FeedbackGlyphType.signOut => '↗',
    };

    if (glyph.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Text(
          glyph,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color ?? const Color(0xFF17151F),
            fontSize: type == FeedbackGlyphType.mark ? size * .58 : size * .68,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
