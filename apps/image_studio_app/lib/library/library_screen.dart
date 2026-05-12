import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Library',
      message: 'Recent and favorite generated images will appear here.',
    );
  }
}
