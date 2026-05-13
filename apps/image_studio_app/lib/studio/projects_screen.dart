import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Projects',
      message: 'Project and conversation switching will appear here.',
    );
  }
}
