import 'package:flutter/material.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import '../shared/empty_state.dart';
import 'composer_bar.dart';
import 'studio_controller.dart';
import 'studio_models.dart';
import 'studio_result_viewer.dart';
import 'turn_card.dart';

/// Studio main page — a conversation timeline of turns plus a sticky
/// composer bar at the bottom.
///
/// File name preserved (`create_screen.dart`) so the router and tests
/// continue to import the same path.
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
    if (mounted) setState(() {});
  }

  String? get _activeConversationId {
    return widget.activeConversationId ??
        widget.controller?.state.activeConversation?.id;
  }

  String get _activeSessionTitle {
    return widget.controller?.state.activeConversation?.title ?? '未命名会话';
  }

  Future<void> _submit() async {
    final controller = widget.controller;
    final conversationId = _activeConversationId;
    if (controller == null || conversationId == null) {
      return;
    }
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    await controller.submitGeneration(
      conversationId: conversationId,
      prompt: prompt,
    );
    _promptController.clear();
    while (controller.hasRunningTurns) {
      await Future<void>.delayed(const Duration(seconds: 2));
      await controller.pollRunningTurnsOnce();
    }
    if (mounted) setState(() {});
  }

  void _retry(StudioTurn turn) {
    final controller = widget.controller;
    final conversationId = _activeConversationId;
    if (controller == null || conversationId == null) return;
    controller
        .submitGeneration(
          conversationId: conversationId,
          prompt: turn.prompt,
          model: turn.model,
          size: turn.size,
        )
        .catchError((_) {});
  }

  void _editPrompt(StudioTurn turn) {
    _promptController.text = turn.prompt;
    _promptController.selection = TextSelection.fromPosition(
      TextPosition(offset: turn.prompt.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPrompt = _promptController.text.trim().isNotEmpty;
    final canSubmit = hasPrompt && _activeConversationId != null;
    final turns = widget.controller?.state.turns ?? const <StudioTurn>[];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _StudioTopBar(
              sessionTitle: _activeSessionTitle,
              model: turns.isNotEmpty ? turns.first.model : 'gpt-image-2',
            ),
            Expanded(
              child: turns.isEmpty
                  ? const _EmptyStudio()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        KilnSpacing.md,
                        KilnSpacing.md,
                        KilnSpacing.md,
                        140,
                      ),
                      itemCount: turns.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: KilnSpacing.md),
                      itemBuilder: (context, index) {
                        final turn = turns[index];
                        return TurnCard(
                          turn: turn,
                          onImageTap: (image, _) =>
                              showStudioResultViewer(context, image),
                          onRetry: () => _retry(turn),
                          onEditPrompt: () => _editPrompt(turn),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KilnSpacing.md,
                0,
                KilnSpacing.md,
                KilnSpacing.lg,
              ),
              child: SafeArea(
                top: false,
                child: ComposerBar(
                  controller: _promptController,
                  canSubmit: canSubmit,
                  submitting: widget.controller?.state.submitting ?? false,
                  onSubmit: _submit,
                  params: [
                    ComposerChipData(
                      label: 'gpt-image-2',
                      active: true,
                      onTap: () {},
                    ),
                    ComposerChipData(label: '1024×1024', onTap: () {}),
                    ComposerChipData(label: '×1 张', onTap: () {}),
                    ComposerChipData(label: '无风格', onTap: () {}),
                  ],
                  onAddReference: () {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioTopBar extends StatelessWidget {
  const _StudioTopBar({required this.sessionTitle, required this.model});

  final String sessionTitle;
  final String model;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        KilnSpacing.lg,
        KilnSpacing.sm,
        KilnSpacing.sm,
        KilnSpacing.sm + 2,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: KilnColors.hairline, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showChip = constraints.maxWidth > 260;
          return Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        sessionTitle,
                        style: KilnTypography.display(
                          size: 17,
                          weight: FontWeight.w500,
                          height: 1.3,
                          letterSpacing: -0.1,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: KilnColors.ink400,
                    ),
                  ],
                ),
              ),
              if (showChip) ...[
                const SizedBox(width: KilnSpacing.xs),
                Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(
                    horizontal: KilnSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: KilnColors.ink800,
                    borderRadius: BorderRadius.circular(KilnRadii.chip),
                    border: Border.all(
                      color: KilnColors.hairlineStrong,
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(model, style: KilnTypography.chipMono),
                ),
              ],
              const SizedBox(width: KilnSpacing.xs),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                tooltip: '新会话',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyStudio extends StatelessWidget {
  const _EmptyStudio();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 160),
      child: EmptyState(
        title: '今天想',
        accent: '画点什么？',
        message: '从一句 prompt 开始。每张图都会留在这段对话里。',
      ),
    );
  }
}
