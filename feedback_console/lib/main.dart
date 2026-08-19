import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/feedback_console_app.dart';
import 'src/firebase_console_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter Web did not register the Material icon font from FontManifest for
  // this standalone build. Register it explicitly before the first frame.
  await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();

  const config = FirebaseConsoleConfig.fromEnvironment();
  if (config.isConfigured) {
    await Firebase.initializeApp(options: config.toFirebaseOptions());
  }

  runApp(FeedbackConsoleApp(config: config));
}
