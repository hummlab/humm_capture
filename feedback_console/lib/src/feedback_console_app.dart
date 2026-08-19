import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'feedback_workspace.dart';
import 'firebase_console_config.dart';

const _canvas = Color(0xFFF7F6FA);
const _muted = Color(0xFF6E6878);
const _outline = Color(0xFFE8E3F0);
const _primary = Color(0xFF4D2FE8);

class FeedbackConsoleApp extends StatelessWidget {
  const FeedbackConsoleApp({required this.config, super.key});

  final FirebaseConsoleConfig config;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Feedback Console',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _primary, brightness: Brightness.light),
      scaffoldBackgroundColor: _canvas,
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _outline),
        ),
      ),
    ),
    home: config.isConfigured ? const _AuthenticationGate() : const _ConfigurationNeededPage(),
  );
}

class _ConfigurationNeededPage extends StatelessWidget {
  const _ConfigurationNeededPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Configure Feedback Console'),
            SizedBox(height: 8),
            Text('Provide FEEDBACK_FIREBASE_* Dart defines when running or building the console.'),
          ],
        ),
      ),
    ),
  );
}

class _AuthenticationGate extends StatelessWidget {
  const _AuthenticationGate();

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return snapshot.hasData ? const FeedbackWorkspace() : const _SignInPage();
    },
  );
}

class _SignInPage extends StatefulWidget {
  const _SignInPage();

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException {
      if (mounted) setState(() => _errorMessage = 'Could not sign in with these credentials.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Feedback Console', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'Sign in to review visual reports from connected applications.',
                style: TextStyle(color: _muted),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                onSubmitted: (_) => _signIn(),
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (_errorMessage case final message?) ...<Widget>[
                const SizedBox(height: 12),
                Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _signIn,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: Text(_isSubmitting ? 'Signing in…' : 'Sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
