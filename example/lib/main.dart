import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugPrintSynchronously, kReleaseMode, kProfileMode;
import 'package:humm_capture/humm_capture.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

late final FeedbackLogStore persistentLogs;
final _processSession = DateTime.now().toUtc().toIso8601String();
const _buildMode = kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

FeedbackLogEntry? _safeNativeLog(FeedbackLogEntry entry) =>
    entry.category == 'android.logcat/flutter' &&
        entry.message.contains('CAPTURE_ANDROID_RUNTIME_CHECK')
    ? entry
    : null;

Future<void> _persistStartupDeviceLogs() async {
  debugPrintSynchronously(
    'CAPTURE_ANDROID_RUNTIME_CHECK: process=$_processSession mode=$_buildMode started',
  );
  try {
    for (var attempt = 0; attempt < 3; attempt++) {
      final native = await collectAndroidFeedbackLogs(redact: _safeNativeLog);
      final startup = native.where(
        (entry) => entry.message.contains('process=$_processSession'),
      );
      if (startup.isNotEmpty) {
        for (final entry in startup) {
          await persistentLogs.add(entry);
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('Startup device log not captured.');
  } catch (_) {
    await persistentLogs.add(
      FeedbackLogEntry(
        timestamp: DateTime.now(),
        level: FeedbackLogLevel.warning,
        category: 'diagnostics',
        message: 'Startup native log unavailable; mode=$_buildMode',
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    ),
  );
  final directory = await getApplicationSupportDirectory();
  persistentLogs = await FeedbackLogStore.open(
    filePath: '${directory.path}/capture-diagnostics.json',
    redact: (entry) => entry,
  );
  await persistentLogs.add(
    FeedbackLogEntry(
      timestamp: DateTime.now(),
      category: 'lifecycle',
      message:
          'Workspace process started; process=$_processSession mode=$_buildMode',
    ),
  );
  await _persistStartupDeviceLogs();
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
  bool _attachmentsEnabled = true;
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _signInError;
  bool _signingIn = false;
  final _feedbackLogs = FeedbackLogBuffer();

  @override
  void initState() {
    super.initState();
    _feedbackLogs.add(
      FeedbackLogEntry(
        timestamp: DateTime.now(),
        category: 'lifecycle',
        message: 'Workspace started',
      ),
    );
  }

  static const _environmentName = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );
  static final FeedbackEnvironment _environment = FeedbackEnvironment.values
      .byName(_environmentName);
  final ImagePicker _picker = ImagePicker();

  Future<List<FeedbackAttachment>> _pickAttachment(
    FeedbackAttachmentType type,
  ) async {
    final file = switch (type) {
      FeedbackAttachmentType.image => await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      ),
      FeedbackAttachmentType.video => await _picker.pickVideo(
        source: ImageSource.gallery,
      ),
    };
    if (file == null) return [];
    if (await file.length() > 15 * 1024 * 1024) {
      throw StateError('Test attachments are limited to 15 MB per file.');
    }
    final extension = file.name.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      _ => throw StateError(
        'Choose PNG, JPEG, WebP, MP4 or MOV for this test.',
      ),
    };
    return [
      FeedbackAttachment(
        bytes: await file.readAsBytes(),
        fileName: file.name,
        mimeType: mimeType,
      ),
    ];
  }

  late final HttpFeedbackReporter _reporter = HttpFeedbackReporter(
    endpoint: Uri.parse(const String.fromEnvironment('FEEDBACK_ENDPOINT')),
    timeout: const Duration(seconds: 120),
    headersProvider: () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Sign in before submitting feedback.');
      return {'Authorization': 'Bearer ${await user.getIdToken()}'};
    },
  );

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _signInError = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      _password.clear();
      _feedbackLogs.add(
        FeedbackLogEntry(
          timestamp: DateTime.now(),
          category: 'auth',
          message: 'Sign-in succeeded',
        ),
      );
    } on FirebaseAuthException catch (error) {
      _feedbackLogs.add(
        FeedbackLogEntry(
          timestamp: DateTime.now(),
          level: FeedbackLogLevel.error,
          category: 'auth',
          message: 'Sign-in failed: ${error.code}',
        ),
      );
      if (mounted) {
        setState(() => _signInError = error.message ?? 'Sign in failed.');
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _reporter.close();
    super.dispose();
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
        attachmentsEnabled: _attachmentsEnabled,
        attachmentPicker: _pickAttachment,
        logsProvider: () async {
          debugPrintSynchronously(
            'CAPTURE_ANDROID_RUNTIME_CHECK: process=$_processSession mode=$_buildMode feedback requested on device',
          );
          final native = await collectAndroidFeedbackLogs(
            redact: _safeNativeLog,
          );
          if (native.isEmpty) {
            throw StateError('The Android runtime log was not captured.');
          }
          return [
            ...await persistentLogs.snapshot(),
            ..._feedbackLogs.snapshot(),
            ...native,
          ];
        },
        contextProvider: () => FeedbackContext(
          appVersion: '1.0.1',
          environment: _environment,
          buildNumber: '1',
          platform: FeedbackPlatform.android,
          screenName: 'example.home',
          locale: 'en',
        ),
        child: _ExampleHome(
          submittedMessage: _submittedMessage,
          onOpenFeedback: _feedbackController.captureAppView,
          attachmentsEnabled: _attachmentsEnabled,
          signInSection: FirebaseAuth.instance.currentUser != null
              ? const ListTile(
                  leading: Icon(Icons.verified_user_outlined),
                  title: Text('Signed in'),
                )
              : Column(
                  children: [
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    if (_signInError != null) Text(_signInError!),
                    FilledButton(
                      onPressed: _signingIn ? null : _signIn,
                      child: Text(_signingIn ? 'Signing in…' : 'Sign in'),
                    ),
                  ],
                ),
          environment: _environment,
          onAttachmentsChanged: (value) =>
              setState(() => _attachmentsEnabled = value),
        ),
      ),
    );
  }
}

class _ExampleHome extends StatelessWidget {
  const _ExampleHome({
    required this.submittedMessage,
    required this.onOpenFeedback,
    required this.attachmentsEnabled,
    required this.signInSection,
    required this.environment,
    required this.onAttachmentsChanged,
  });

  final String? submittedMessage;
  final Future<void> Function() onOpenFeedback;
  final bool attachmentsEnabled;
  final Widget signInSection;
  final FeedbackEnvironment environment;
  final ValueChanged<bool> onAttachmentsChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fieldnotes')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: <Widget>[
            Text(
              'Your workspace',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'A calm place to plan your day and keep your ideas together.',
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('Review the product brief'),
                      subtitle: Text('Product · 10:00'),
                    ),
                    const ListTile(
                      leading: Icon(Icons.edit_note),
                      title: Text('Collect ideas for the next release'),
                      subtitle: Text('Design · 14:00'),
                    ),
                    const ListTile(
                      leading: Icon(Icons.calendar_today_outlined),
                      title: Text('Team catch-up'),
                      subtitle: Text('Workspace · 16:00'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Build environment: ${environment.name}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Text(
              'Reports are delivered to your connected feedback workspace.',
            ),
            SwitchListTile(
              title: const Text('Enable media attachments'),
              value: attachmentsEnabled,
              onChanged: onAttachmentsChanged,
            ),
            signInSection,
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
