import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'console_theme.dart';

/// One navigation model for the desktop rail and the phone drawer.
class WorkspaceNavigation extends StatelessWidget {
  const WorkspaceNavigation({
    required this.selectedIndex,
    required this.canManageAccess,
    required this.expanded,
    required this.onSelected,
    super.key,
  });
  final int selectedIndex;
  final bool canManageAccess;
  final bool expanded;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: expanded ? 208 : 72,
    child: ColoredBox(
      color: ConsoleColors.canvas,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(expanded ? 20 : 16, 24, expanded ? 20 : 16, 32),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: ConsoleColors.accent, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.crop_free, color: Colors.white, size: 20),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 10),
                    const Text(
                      'Capture',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.6),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  for (final destination in [
                    (0, 'Inbox', Icons.inbox_outlined),
                    if (canManageAccess) ...[
                      (1, 'Jira', Icons.integration_instructions_outlined),
                      (2, 'Slack', Icons.notifications_outlined),
                      (3, 'Access', Icons.people_outline),
                    ],
                  ])
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (destination.$1 == 1) ...[
                          const SizedBox(height: 28),
                          if (expanded)
                            const Padding(
                              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                              child: Text('Workspace', style: TextStyle(fontSize: 12, color: ConsoleColors.muted)),
                            )
                          else
                            const Divider(height: 20),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              alignment: expanded ? Alignment.centerLeft : Alignment.center,
                              minimumSize: const Size(44, 48),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              foregroundColor: selectedIndex == destination.$1
                                  ? ConsoleColors.ink
                                  : ConsoleColors.muted,
                              backgroundColor: selectedIndex == destination.$1 ? ConsoleColors.selected : null,
                            ),
                            onPressed: () => onSelected(destination.$1),
                            child: expanded
                                ? Row(
                                    children: [
                                      Icon(destination.$3, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        destination.$2,
                                        style: TextStyle(
                                          fontWeight: selectedIndex == destination.$1
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  )
                                : Tooltip(
                                    message: destination.$2,
                                    child: Icon(destination.$3, semanticLabel: destination.$2, size: 20),
                                  ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: expanded
                  ? TextButton.icon(
                      onPressed: FirebaseAuth.instance.signOut,
                      icon: const Icon(Icons.logout_outlined, size: 20),
                      label: const Text('Sign out'),
                    )
                  : IconButton(
                      tooltip: 'Sign out',
                      onPressed: FirebaseAuth.instance.signOut,
                      icon: const Icon(Icons.logout_outlined),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
