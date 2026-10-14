import 'package:flutter/material.dart';

/// Shared surfaces for review tools and integration settings.
class ConsoleSection extends StatelessWidget {
  const ConsoleSection({required this.child, this.title, this.subtitle, super.key});
  final Widget child;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title case final title?) Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle case final subtitle?) ...[
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
        ],
      ],
    );
    if (title == null) return child;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth >= 700
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 220, child: heading),
                      const SizedBox(width: 40),
                      Expanded(child: child),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [heading, const SizedBox(height: 20), child],
                  ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class ConsoleSettingsPage extends StatelessWidget {
  const ConsoleSettingsPage({required this.title, required this.subtitle, required this.children, super.key});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox.expand(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(constraints.maxWidth < 600 ? 16 : 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.8),
                ),
                const SizedBox(height: 8),
                Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 28),
                const Divider(height: 1),
                const SizedBox(height: 28),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
