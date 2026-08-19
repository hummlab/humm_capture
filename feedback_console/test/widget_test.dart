import 'package:feedback_console/src/feedback_console_app.dart';
import 'package:feedback_console/src/firebase_console_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows setup guidance without Firebase configuration', (tester) async {
    await tester.pumpWidget(const FeedbackConsoleApp(config: FirebaseConsoleConfig.fromEnvironment()));

    expect(find.text('Configure Feedback Console'), findsOneWidget);
  });
}
