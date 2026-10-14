import 'package:feedback_console/src/feedback_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('neutral placeholders settle without continuous animation', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: FeedbackThumbnailShimmer(width: 180, height: 20)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(ShaderMask), findsNothing);
    expect(tester.getSize(find.byType(FeedbackThumbnailShimmer)), const Size(180, 20));
  });
}
