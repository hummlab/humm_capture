import 'dart:async';

import 'package:flutter/material.dart';

import 'feedback_report.dart';

/// Opens a linked report only after the authorized report stream has loaded.
class FeedbackReportDeepLink extends StatefulWidget {
  const FeedbackReportDeepLink({required this.reports, required this.onOpen, required this.child, this.uri, super.key});

  final Stream<List<FeedbackReport>> reports;
  final ValueChanged<FeedbackReport> onOpen;
  final Widget child;

  /// Defaults to the browser URL. Injectable for deterministic link tests.
  final Uri? uri;

  @override
  State<FeedbackReportDeepLink> createState() => _FeedbackReportDeepLinkState();
}

class _FeedbackReportDeepLinkState extends State<FeedbackReportDeepLink> {
  StreamSubscription<List<FeedbackReport>>? _subscription;
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    final id = (widget.uri ?? Uri.base).queryParameters['feedback'];
    if (id == null || id.isEmpty) return;
    _subscription = widget.reports.listen(
      (reports) {
        if (_handled) return;
        _handled = true;
        final matches = reports.where((report) => report.id == id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (matches.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report is unavailable.')));
          } else {
            widget.onOpen(matches.first);
          }
        });
      },
      onError: (Object _, StackTrace __) {
        // The inbox renders the stream's permission/error state.
        _handled = true;
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
