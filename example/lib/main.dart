import 'package:flutter/material.dart';
import 'package:humm_capture/humm_capture.dart';

void main() {
  runApp(const FeedbackExampleApp());
}

class FeedbackExampleApp extends StatefulWidget {
  const FeedbackExampleApp({super.key});

  @override
  State<FeedbackExampleApp> createState() => _FeedbackExampleAppState();
}

class _FeedbackExampleAppState extends State<FeedbackExampleApp> {
  final FeedbackCaptureController _feedbackController =
      FeedbackCaptureController();
  String? _submittedMessage;
  late final FeedbackReporter _reporter = _ExampleFeedbackReporter(
    onDelivered: _onFeedbackDelivered,
  );

  void _onFeedbackDelivered(FeedbackReport report) {
    setState(() => _submittedMessage = report.message ?? 'Bez opisu');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5137F4)),
        useMaterial3: true,
      ),
      home: FeedbackCaptureBoundary(
        controller: _feedbackController,
        reporter: _reporter,
        contextProvider: () => FeedbackContext(
          appVersion: '1.0.0',
          buildNumber: '1',
          platform: FeedbackPlatform.unknown,
          screenName: 'example.home',
          locale: Localizations.localeOf(context).toLanguageTag(),
          metadata: const <String, String>{'environment': 'example'},
        ),
        child: _ExampleHome(
          submittedMessage: _submittedMessage,
          onOpenFeedback: _feedbackController.captureAppView,
        ),
      ),
    );
  }
}

class _ExampleFeedbackReporter implements FeedbackReporter {
  _ExampleFeedbackReporter({required this.onDelivered});

  final ValueChanged<FeedbackReport> onDelivered;

  @override
  Future<FeedbackSubmissionResult> submit(FeedbackReport report) async {
    onDelivered(report);
    return const FeedbackSubmissionSuccess(reference: 'example-feedback');
  }
}

class _ExampleHome extends StatelessWidget {
  const _ExampleHome({
    required this.submittedMessage,
    required this.onOpenFeedback,
  });

  final String? submittedMessage;
  final Future<void> Function() onOpenFeedback;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Humm Feedback example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Test capture',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Use a three-finger long press or the action below. The composer '
              'appears only after the app view has been captured.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onOpenFeedback,
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('Open feedback'),
            ),
            if (submittedMessage case final message?) ...<Widget>[
              const SizedBox(height: 32),
              Text(
                'Last report',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(message),
            ],
          ],
        ),
      ),
    );
  }
}
