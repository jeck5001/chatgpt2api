import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Settings',
      message: 'Server, session, cache, and sign-out controls will appear here.',
    );
  }
}
