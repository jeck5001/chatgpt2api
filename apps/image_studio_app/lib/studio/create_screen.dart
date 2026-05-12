import 'package:flutter/material.dart';

import '../shared/empty_state.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_onPromptChanged);
  }

  @override
  void dispose() {
    _promptController
      ..removeListener(_onPromptChanged)
      ..dispose();
    super.dispose();
  }

  void _onPromptChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasPrompt = _promptController.text.trim().isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _promptController,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Prompt',
                  hintText: 'Describe the image you want to create',
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: hasPrompt ? () {} : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate'),
              ),
              const Expanded(
                child: EmptyState(
                  title: 'No active results',
                  message: 'Generate an image to start a visual conversation.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
