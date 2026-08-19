import 'package:flutter/material.dart';

const _base = Color(0xFFEAE7F0);
const _highlight = Color(0xFFF8F7FA);

/// A lightweight loading placeholder used while private report media loads.
class FeedbackShimmer extends StatefulWidget {
  const FeedbackShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<FeedbackShimmer> createState() => _FeedbackShimmerState();
}

class _FeedbackShimmerState extends State<FeedbackShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment(-1.2 + 2.4 * _controller.value, 0),
        end: Alignment(-0.2 + 2.4 * _controller.value, 0),
        colors: const <Color>[_base, _highlight, _base],
      ).createShader(bounds),
      child: child,
    ),
  );
}

class FeedbackThumbnailShimmer extends StatelessWidget {
  const FeedbackThumbnailShimmer({required this.width, required this.height, super.key});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => FeedbackShimmer(
    child: DecoratedBox(
      decoration: BoxDecoration(color: _base, borderRadius: BorderRadius.circular(10)),
      child: SizedBox(width: width, height: height),
    ),
  );
}
