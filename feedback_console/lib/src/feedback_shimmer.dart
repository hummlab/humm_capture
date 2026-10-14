import 'package:flutter/material.dart';

import 'console_theme.dart';

/// A quiet placeholder. No moving sheen or continuous animation is needed.
class FeedbackShimmer extends StatelessWidget {
  const FeedbackShimmer({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: child);
}

class FeedbackThumbnailShimmer extends StatelessWidget {
  const FeedbackThumbnailShimmer({required this.width, required this.height, super.key});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => FeedbackShimmer(
    child: DecoratedBox(
      decoration: BoxDecoration(color: ConsoleColors.line, borderRadius: BorderRadius.circular(6)),
      child: SizedBox(width: width, height: height),
    ),
  );
}
