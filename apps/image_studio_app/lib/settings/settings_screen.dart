import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    this.onSignOut,
  });

  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(
          child: EmptyState(
            title: 'Settings',
            message: 'Server, session, cache, and sign-out controls will '
                'appear here.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton.tonalIcon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ),
      ],
    );
  }
}
