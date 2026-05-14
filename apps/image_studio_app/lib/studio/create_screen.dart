import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import '../shared/empty_state.dart';
import 'composer_bar.dart';
import 'studio_controller.dart';
import 'studio_image_saver.dart';
import 'studio_models.dart';
import 'studio_result_viewer.dart';
import 'turn_card.dart';

const List<String> _kSupportedModels = ['gpt-image-2', 'gpt-image-1'];
const List<String> _kSupportedSizes = ['1024x1024', '1024x1792', '1792x1024'];

/// Studio main page — a conversation timeline of turns plus a sticky
/// composer bar at the bottom.
///
/// File name preserved (`create_screen.dart`) so the router and tests
/// continue to import the same path.
class CreateScreen extends StatefulWidget {
  const CreateScreen({
    super.key,
    this.controller,
    this.activeConversationId,
    this.imageSaver,
  });

  final StudioController? controller;
  final String? activeConversationId;
  final StudioImageSaver? imageSaver;

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final _promptController = TextEditingController();
  late final StudioImageSaver _imageSaver;

  String _selectedModel = _kSupportedModels.first;
  String _selectedSize = _kSupportedSizes.first;

  @override
  void initState() {
    super.initState();
    _imageSaver = widget.imageSaver ?? StudioImageSaver();
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
    try {
      await controller.submitGeneration(
        conversationId: conversationId,
        prompt: prompt,
        model: _selectedModel,
        size: _selectedSize,
      );
      _promptController.clear();
    } catch (error) {
      if (!mounted) return;
      _showSnack('生成失败：$error');
    }
  }

  void _retry(StudioTurn turn) {
    final controller = widget.controller;
    final conversationId = _activeConversationId;
    if (controller == null || conversationId == null) return;
    unawaited(
      controller
          .submitGeneration(
            conversationId: conversationId,
            prompt: turn.prompt,
            model: turn.model,
            size: turn.size,
          )
          .catchError((_) {}),
    );
  }

  void _editPrompt(StudioTurn turn) {
    _promptController.text = turn.prompt;
    _promptController.selection = TextSelection.fromPosition(
      TextPosition(offset: turn.prompt.length),
    );
  }

  void _variation(StudioTurn turn) {
    final controller = widget.controller;
    final conversationId = _activeConversationId;
    if (controller == null || conversationId == null) return;
    unawaited(
      controller
          .submitGeneration(
            conversationId: conversationId,
            prompt: turn.prompt,
            model: turn.model,
            size: turn.size,
          )
          .catchError((_) {}),
    );
    _showSnack('已发起变体生成');
  }

  Future<void> _toggleFavorite(StudioTurn turn) async {
    final controller = widget.controller;
    if (controller == null || turn.resultImages.isEmpty) return;
    final image = turn.resultImages.first;
    try {
      await controller.toggleFavoriteImage(image: image, sourceTurnId: turn.id);
      if (!mounted) return;
      _showSnack(controller.isFavoriteImage(image) ? '已收藏' : '已取消收藏');
    } catch (error) {
      if (!mounted) return;
      _showSnack('收藏失败：$error');
    }
  }

  Future<void> _saveImage(StudioResultImage image) async {
    try {
      final file = await _imageSaver.saveImage(
        imageUrl: image.url,
        fileName: _fileNameFor(image),
      );
      if (!mounted) return;
      _showSnack('已保存到 ${file.path}');
    } catch (error) {
      if (!mounted) return;
      _showSnack('保存失败：$error');
    }
  }

  Future<void> _shareImage(StudioResultImage image) async {
    try {
      final file = await _imageSaver.saveImage(
        imageUrl: image.url,
        fileName: _fileNameFor(image),
      );
      await Share.shareXFiles([XFile(file.path)]);
    } catch (error) {
      if (!mounted) return;
      _showSnack('分享失败：$error');
    }
  }

  String _fileNameFor(StudioResultImage image) {
    if (image.url.pathSegments.isNotEmpty) {
      final last = image.url.pathSegments.last;
      if (last.isNotEmpty) return last;
    }
    if (image.path.isNotEmpty) {
      final parts = image.path.split('/');
      if (parts.isNotEmpty && parts.last.isNotEmpty) return parts.last;
    }
    return 'image.png';
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openImage(StudioTurn turn, StudioResultImage image) async {
    await showStudioResultViewer(
      context,
      image,
      promptText: turn.prompt,
      model: turn.model,
      size: turn.size,
      totalImages: turn.resultImages.length,
      imageIndex: turn.resultImages.indexOf(image),
      onFavorite: () => _toggleFavorite(turn),
      onVariation: () => _variation(turn),
      imageSaver: _imageSaver,
    );
  }

  Future<void> _pickModel() async {
    final picked = await _showOptionSheet(
      title: '选择模型',
      options: _kSupportedModels,
      current: _selectedModel,
    );
    if (picked != null && picked != _selectedModel) {
      setState(() => _selectedModel = picked);
    }
  }

  Future<void> _pickSize() async {
    final picked = await _showOptionSheet(
      title: '选择尺寸',
      options: _kSupportedSizes,
      current: _selectedSize,
    );
    if (picked != null && picked != _selectedSize) {
      setState(() => _selectedSize = picked);
    }
  }

  Future<String?> _showOptionSheet({
    required String title,
    required List<String> options,
    required String current,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: KilnColors.ink900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KilnSpacing.lg,
                  KilnSpacing.md,
                  KilnSpacing.lg,
                  KilnSpacing.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: KilnTypography.display(
                      size: 16,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              for (final option in options)
                ListTile(
                  title: Text(option, style: KilnTypography.ui(size: 14)),
                  trailing: option == current
                      ? const Icon(
                          Icons.check_rounded,
                          color: KilnColors.ember400,
                          size: 18,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(option),
                ),
              const SizedBox(height: KilnSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openConversationSwitcher() async {
    final controller = widget.controller;
    if (controller == null) return;
    final activeProject = controller.state.activeProject;
    final conversations = controller.state.conversations
        .where((c) => activeProject == null || c.projectId == activeProject.id)
        .toList();
    if (conversations.isEmpty) return;
    final activeId = controller.state.activeConversation?.id;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KilnColors.ink900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KilnSpacing.lg,
                  KilnSpacing.md,
                  KilnSpacing.lg,
                  KilnSpacing.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '切换会话',
                    style: KilnTypography.display(
                      size: 16,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conv = conversations[index];
                    return ListTile(
                      title: Text(
                        conv.title,
                        style: KilnTypography.ui(size: 14),
                      ),
                      trailing: conv.id == activeId
                          ? const Icon(
                              Icons.check_rounded,
                              color: KilnColors.ember400,
                              size: 18,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(conv.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: KilnSpacing.sm),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != activeId) {
      await controller.selectConversation(picked);
    }
  }

  Future<void> _createNewConversation() async {
    final controller = widget.controller;
    if (controller == null) return;
    final title = await _promptForTitle();
    if (title == null) return;
    try {
      await controller.createNewConversation(title: title);
      if (mounted) _showSnack('已创建新会话');
    } catch (error) {
      if (!mounted) return;
      _showSnack('创建会话失败：$error');
    }
  }

  Future<String?> _promptForTitle() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: KilnColors.ink900,
          title: Text(
            '新建会话',
            style: KilnTypography.display(size: 16, weight: FontWeight.w500),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '会话标题（可留空）'),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
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
              model: _selectedModel,
              onTapTitle: widget.controller == null
                  ? null
                  : _openConversationSwitcher,
              onTapAdd: widget.controller == null
                  ? null
                  : _createNewConversation,
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
                          onImageTap: (image, _) => _openImage(turn, image),
                          onRetry: () => _retry(turn),
                          onEditPrompt: () => _editPrompt(turn),
                          onFavorite: () => _toggleFavorite(turn),
                          onVariation: () => _variation(turn),
                          onEdit: () => _editPrompt(turn),
                          onSave: turn.resultImages.isEmpty
                              ? null
                              : () => _saveImage(turn.resultImages.first),
                          onShare: turn.resultImages.isEmpty
                              ? null
                              : () => _shareImage(turn.resultImages.first),
                          isFavoriteImage: widget.controller?.isFavoriteImage,
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
                      label: _selectedModel,
                      active: true,
                      onTap: _pickModel,
                    ),
                    ComposerChipData(
                      label: _selectedSize.replaceAll('x', '×'),
                      onTap: _pickSize,
                    ),
                  ],
                  onAddReference: () => _showSnack('参考图功能即将上线'),
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
  const _StudioTopBar({
    required this.sessionTitle,
    required this.model,
    this.onTapTitle,
    this.onTapAdd,
  });

  final String sessionTitle;
  final String model;
  final VoidCallback? onTapTitle;
  final VoidCallback? onTapAdd;

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
                child: InkWell(
                  onTap: onTapTitle,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
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
                onPressed: onTapAdd,
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
