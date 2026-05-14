import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import '../shared/empty_state.dart';
import 'composer_bar.dart';
import 'studio_controller.dart';
import 'studio_image_saver.dart';
import 'studio_models.dart';
import 'studio_repository.dart';
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
  final ImagePicker _imagePicker = ImagePicker();
  final List<XFile> _references = <XFile>[];

  late String _selectedModel;
  late String _selectedSize;

  @override
  void initState() {
    super.initState();
    _imageSaver = widget.imageSaver ?? StudioImageSaver();
    final prefs = widget.controller?.state.preferences;
    _selectedModel = _resolveModel(prefs?.defaultModel);
    _selectedSize = _resolveSize(prefs?.defaultSize);
    _promptController.addListener(_onPromptChanged);
  }

  String _resolveModel(String? candidate) {
    if (candidate != null && _kSupportedModels.contains(candidate)) {
      return candidate;
    }
    return _kSupportedModels.first;
  }

  String _resolveSize(String? candidate) {
    if (candidate != null && _kSupportedSizes.contains(candidate)) {
      return candidate;
    }
    return _kSupportedSizes.first;
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
      if (_references.isEmpty) {
        await controller.submitGeneration(
          conversationId: conversationId,
          prompt: prompt,
          model: _selectedModel,
          size: _selectedSize,
        );
      } else {
        final payload = await _loadReferenceImages();
        await controller.submitEdit(
          conversationId: conversationId,
          prompt: prompt,
          images: payload,
          model: _selectedModel,
          size: _selectedSize,
        );
        if (mounted) setState(_references.clear);
      }
      _promptController.clear();
    } catch (error) {
      if (!mounted) return;
      _showSnack('生成失败：$error');
    }
  }

  Future<List<StudioEditImage>> _loadReferenceImages() async {
    final out = <StudioEditImage>[];
    for (final file in _references) {
      final bytes = await file.readAsBytes();
      final filename = file.name.isNotEmpty ? file.name : 'reference.png';
      out.add(
        StudioEditImage(
          bytes: bytes,
          filename: filename,
          contentType: file.mimeType,
        ),
      );
    }
    return out;
  }

  Future<void> _pickReferenceImage() async {
    try {
      final picked = await _imagePicker.pickMultiImage(
        imageQuality: 90,
        limit: 4,
      );
      if (picked.isEmpty) return;
      setState(() {
        final remaining = 4 - _references.length;
        if (remaining <= 0) {
          _showSnack('最多 4 张参考图');
          return;
        }
        _references.addAll(picked.take(remaining));
      });
    } catch (error) {
      if (!mounted) return;
      _showSnack('选图失败：$error');
    }
  }

  void _removeReference(int index) {
    setState(() {
      if (index >= 0 && index < _references.length) {
        _references.removeAt(index);
      }
    });
  }

  void _retry(StudioTurn turn) {
    final controller = widget.controller;
    if (controller == null) return;
    if (turn.mode == StudioTurnMode.edit) {
      _showSnack('图生图任务暂不支持重试，请重新发起。');
      return;
    }
    unawaited(
      controller.retryTurn(turn).catchError((error) {
        if (!mounted) return;
        _showSnack('重试失败：$error');
      }),
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

  Future<void> _openTemplates() async {
    final controller = widget.controller;
    if (controller == null) return;
    final templates = controller.state.templates;
    final action = await showModalBottomSheet<_TemplateSheetAction>(
      context: context,
      backgroundColor: KilnColors.ink900,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _TemplateSheet(
          templates: templates,
          currentPrompt: _promptController.text,
          onDelete: (template) async {
            try {
              await controller.deletePromptTemplate(template.id);
            } catch (error) {
              if (mounted) _showSnack('删除失败：$error');
            }
          },
        );
      },
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _TemplateSheetApply(:final template):
        _promptController.text = template.content;
        _promptController.selection = TextSelection.fromPosition(
          TextPosition(offset: template.content.length),
        );
      case _TemplateSheetSaveCurrent():
        await _saveCurrentPromptAsTemplate();
    }
  }

  Future<void> _saveCurrentPromptAsTemplate() async {
    final controller = widget.controller;
    final content = _promptController.text.trim();
    if (controller == null) return;
    if (content.isEmpty) {
      _showSnack('请先在输入框写好 prompt');
      return;
    }
    final form = await _promptForTemplateMeta();
    if (form == null) return;
    try {
      await controller.savePromptTemplate(
        name: form.name,
        category: form.category,
        content: content,
      );
      if (mounted)
        _showSnack('已保存模板「${form.name.isEmpty ? '未命名' : form.name}」');
    } catch (error) {
      if (mounted) _showSnack('保存失败：$error');
    }
  }

  Future<_TemplateMeta?> _promptForTemplateMeta() async {
    final nameController = TextEditingController();
    final categoryController = TextEditingController();
    final result = await showDialog<_TemplateMeta>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('保存为模板'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(hintText: '名称（可留空）'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(hintText: '分类（可留空）'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _TemplateMeta(
                  name: nameController.text.trim(),
                  category: categoryController.text.trim(),
                ),
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    categoryController.dispose();
    return result;
  }

  String _formatElapsed(DateTime startedAt) {
    final delta = DateTime.now().difference(startedAt);
    if (delta.isNegative) return '0s';
    final seconds = delta.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    if (remaining == 0) return '${minutes}m';
    return '${minutes}m${remaining}s';
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
      initialFavorited: widget.controller?.isFavoriteImage(image) ?? false,
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
                          runningElapsed: turn.isRunning
                              ? _formatElapsed(turn.updatedAt)
                              : null,
                        );
                      },
                    ),
            ),
            if (_references.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  KilnSpacing.md,
                  0,
                  KilnSpacing.md,
                  KilnSpacing.xs,
                ),
                child: _ReferenceStrip(
                  files: _references,
                  onRemove: _removeReference,
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
                  hint: _references.isEmpty ? '描述你想要的画面…' : '描述要在参考图基础上做什么…',
                  params: [
                    ComposerChipData(
                      label: '模板',
                      onTap: widget.controller == null ? null : _openTemplates,
                    ),
                    ComposerChipData(
                      label: _selectedModel,
                      active: true,
                      onTap: _pickModel,
                    ),
                    ComposerChipData(
                      label: _selectedSize.replaceAll('x', '×'),
                      onTap: _pickSize,
                    ),
                    if (_references.isNotEmpty)
                      ComposerChipData(
                        label: '参考 ×${_references.length}',
                        active: true,
                        onTap: () => _showSnack('再点 + 可继续追加，长按缩略图可移除'),
                      ),
                  ],
                  onAddReference: _pickReferenceImage,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceStrip extends StatelessWidget {
  const _ReferenceStrip({required this.files, required this.onRemove});

  final List<XFile> files;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final file = files[index];
          return _ReferenceThumb(file: file, onRemove: () => onRemove(index));
        },
      ),
    );
  }
}

class _ReferenceThumb extends StatelessWidget {
  const _ReferenceThumb({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 80,
            height: 80,
            child: FutureBuilder<Uint8List>(
              future: file.readAsBytes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done ||
                    snapshot.data == null) {
                  return Container(
                    color: KilnColors.ink800,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: KilnColors.ink800,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                      color: KilnColors.ink500,
                      size: 18,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
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

class _TemplateMeta {
  const _TemplateMeta({required this.name, required this.category});
  final String name;
  final String category;
}

sealed class _TemplateSheetAction {
  const _TemplateSheetAction();
}

class _TemplateSheetApply extends _TemplateSheetAction {
  const _TemplateSheetApply(this.template);
  final StudioPromptTemplate template;
}

class _TemplateSheetSaveCurrent extends _TemplateSheetAction {
  const _TemplateSheetSaveCurrent();
}

class _TemplateSheet extends StatelessWidget {
  const _TemplateSheet({
    required this.templates,
    required this.currentPrompt,
    required this.onDelete,
  });

  final List<StudioPromptTemplate> templates;
  final String currentPrompt;
  final Future<void> Function(StudioPromptTemplate) onDelete;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<StudioPromptTemplate>>{};
    for (final t in templates) {
      final key = t.category.isEmpty ? '其他' : t.category;
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final categories = grouped.keys.toList()..sort();
    final hasCurrent = currentPrompt.trim().isNotEmpty;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
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
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Prompt 模板',
                      style: KilnTypography.display(
                        size: 16,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: hasCurrent
                        ? () => Navigator.of(
                            context,
                          ).pop(const _TemplateSheetSaveCurrent())
                        : null,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                    label: const Text('保存当前'),
                  ),
                ],
              ),
            ),
            const Divider(color: KilnColors.hairline, height: 1),
            if (templates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(KilnSpacing.xl),
                child: Text(
                  '还没有模板。把常用的 prompt 保存下来下次直接复用。',
                  textAlign: TextAlign.center,
                  style: KilnTypography.mono(
                    size: 12,
                    color: KilnColors.ink500,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: KilnSpacing.sm),
                  children: [
                    for (final category in categories) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          KilnSpacing.lg,
                          KilnSpacing.sm + 2,
                          KilnSpacing.lg,
                          KilnSpacing.xs,
                        ),
                        child: Text(
                          category,
                          style: KilnTypography.mono(
                            size: 10,
                            color: KilnColors.ink500,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      for (final t in grouped[category]!)
                        _TemplateRow(
                          template: t,
                          onTap: () =>
                              Navigator.of(context).pop(_TemplateSheetApply(t)),
                          onDelete: t.builtin ? null : () => onDelete(t),
                        ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.onTap,
    this.onDelete,
  });

  final StudioPromptTemplate template;
  final VoidCallback onTap;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        template.name.isEmpty ? '未命名模板' : template.name,
        style: KilnTypography.ui(size: 14, weight: FontWeight.w500),
      ),
      subtitle: Text(
        template.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: KilnTypography.mono(size: 11, color: KilnColors.ink400),
      ),
      trailing: template.builtin
          ? Text(
              '内置',
              style: KilnTypography.mono(
                size: 10,
                color: KilnColors.ink500,
                letterSpacing: 1.2,
              ),
            )
          : onDelete == null
          ? null
          : IconButton(
              tooltip: '删除',
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: KilnColors.ink500,
              ),
              onPressed: () async {
                await onDelete!();
              },
            ),
    );
  }
}
