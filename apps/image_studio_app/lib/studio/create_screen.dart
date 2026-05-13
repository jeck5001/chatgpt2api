import 'package:flutter/material.dart';

import '../shared/empty_state.dart';
import 'studio_controller.dart';
import 'studio_models.dart';

class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key, this.controller, this.activeConversationId});

  final StudioController? controller;
  final String? activeConversationId;

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
    final canSubmit = hasPrompt && _activeConversationId != null;
    final turns = widget.controller?.state.turns ?? const <StudioTurn>[];
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
                onPressed: canSubmit ? _submit : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate'),
              ),
              Expanded(
                child: turns.isEmpty
                    ? const EmptyState(
                        title: 'No active results',
                        message:
                            'Generate an image to start a visual '
                            'conversation.',
                      )
                    : ListView.separated(
                        itemCount: turns.length,
                        separatorBuilder: (context, index) {
                          return const Divider(height: 1);
                        },
                        itemBuilder: (context, index) {
                          final turn = turns[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  turn.prompt,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(turn.status.name),
                                if (turn.error.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    turn.error,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ],
                                if (turn.resultImages.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 180,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: turn.resultImages.length,
                                      separatorBuilder: (context, imageIndex) {
                                        return const SizedBox(width: 12);
                                      },
                                      itemBuilder: (context, imageIndex) {
                                        final image =
                                            turn.resultImages[imageIndex];
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: 1,
                                            child: Image.network(
                                              image.url.toString(),
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Container(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    alignment: Alignment.center,
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    child: Text(
                                                      image.path.isNotEmpty
                                                          ? image.path
                                                          : image.url
                                                                .toString(),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final controller = widget.controller;
    final conversationId = _activeConversationId;
    if (controller == null || conversationId == null) {
      return;
    }
    await controller.submitGeneration(
      conversationId: conversationId,
      prompt: _promptController.text.trim(),
    );
    while (controller.hasRunningTurns) {
      await Future<void>.delayed(const Duration(seconds: 2));
      await controller.pollRunningTurnsOnce();
    }
    setState(() {});
  }

  String? get _activeConversationId {
    return widget.activeConversationId ??
        widget.controller?.state.activeConversation?.id;
  }
}
