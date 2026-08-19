import 'package:firebase_core/firebase_core.dart';

/// Firebase Web settings supplied by the deployment environment.
///
/// These values identify a Firebase project; they are not a replacement for
/// Firebase Authentication, Firestore rules or App Check.
final class FirebaseConsoleConfig {
  const FirebaseConsoleConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.authDomain,
    required this.storageBucket,
    required this.functionsBaseUrl,
    this.measurementId,
  });

  const FirebaseConsoleConfig.fromEnvironment()
    : apiKey = const String.fromEnvironment('FEEDBACK_FIREBASE_API_KEY'),
      appId = const String.fromEnvironment('FEEDBACK_FIREBASE_APP_ID'),
      messagingSenderId = const String.fromEnvironment('FEEDBACK_FIREBASE_MESSAGING_SENDER_ID'),
      projectId = const String.fromEnvironment('FEEDBACK_FIREBASE_PROJECT_ID'),
      authDomain = const String.fromEnvironment('FEEDBACK_FIREBASE_AUTH_DOMAIN'),
      storageBucket = const String.fromEnvironment('FEEDBACK_FIREBASE_STORAGE_BUCKET'),
      functionsBaseUrl = const String.fromEnvironment('FEEDBACK_FUNCTIONS_BASE_URL'),
      measurementId = const String.fromEnvironment('FEEDBACK_FIREBASE_MEASUREMENT_ID');

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String authDomain;
  final String storageBucket;
  final String functionsBaseUrl;
  final String? measurementId;

  bool get isConfigured => <String>[
    apiKey,
    appId,
    messagingSenderId,
    projectId,
    authDomain,
    storageBucket,
  ].every((value) => value.isNotEmpty);

  bool get hasFunctionsBaseUrl =>
      functionsBaseUrl.trim().isNotEmpty &&
      (functionsBaseUrl.startsWith('https://') ||
          functionsBaseUrl.startsWith('http://localhost') ||
          functionsBaseUrl.startsWith('http://127.0.0.1'));

  FirebaseOptions toFirebaseOptions() => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain,
    storageBucket: storageBucket,
    measurementId: measurementId?.isEmpty ?? true ? null : measurementId,
  );
}
