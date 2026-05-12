import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

class TurnDetailScreen extends StatelessWidget {
  const TurnDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Turn detail',
      message: 'Prompt, status, result images, retry, and continue edit '
          'actions will appear here.',
    );
  }
}
