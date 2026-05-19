import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin/logs_controller.dart';
import '../admin/logs_repository.dart';
import '../admin/logs_screen.dart';
import '../app/accent.dart';
import '../app/theme.dart';
import '../auth/auth_models.dart';
import '../core/api/api_client.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';
import '../shared/adaptive_shell.dart';
import '../shared/components/name_prompt_dialog.dart';
import '../shared/components/purge_confirm_dialog.dart';
import 'create_screen.dart';
import 'projects_screen.dart';
import 'studio_controller.dart';
import 'studio_image_saver.dart';
import 'studio_models.dart';
import 'studio_result_viewer.dart';

class StudioSessionScreen extends StatefulWidget {
  const StudioSessionScreen({
    super.key,
    required this.controller,
    this.session,
    this.onSignOut,
    this.imageSaver,
    this.urlLauncher,
    this.fileSharer,
    this.githubUrl = 'https://github.com/jeck5001/chatgpt2api',
    this.feedbackUrl = 'https://github.com/jeck5001/chatgpt2api/issues/new',
  });

  final StudioController controller;
  final AuthSession? session;
  final Future<void> Function()? onSignOut;
  final StudioImageSaver? imageSaver;
  final Future<bool> Function(Uri uri)? urlLauncher;
  final Future<void> Function(List<XFile> files)? fileSharer;
  final String githubUrl;
  final String feedbackUrl;

  @override
  State<StudioSessionScreen> createState() => _StudioSessionScreenState();
}

class _StudioSessionScreenState extends State<StudioSessionScreen> {
  late final Future<void> _loadFuture;
  late final StudioImageSaver _imageSaver;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _imageSaver = widget.imageSaver ?? StudioImageSaver();
    _loadFuture = widget.controller.loadWorkspace();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<String?> _promptForName({
    required String title,
    String hint = '',
    String confirmLabel = '创建',
  }) {
    return showNamePromptDialog(
      context,
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
    );
  }

  Future<void> _createProject() async {
    final name = await _promptForName(title: '新建项目', hint: '项目名称（可留空）');
    if (name == null) return;
    try {
      await widget.controller.createNewProject(name);
    } catch (error) {
      _toast('创建项目失败：$error');
    }
  }

  Future<void> _renameProject(StudioProject project) async {
    final name = await _promptForName(
      title: '重命名项目',
      hint: project.name,
      confirmLabel: '保存',
    );
    if (name == null || name.isEmpty || name == project.name) return;
    try {
      await widget.controller.renameProject(projectId: project.id, name: name);
      _toast('已重命名为 $name');
    } catch (error) {
      _toast('重命名失败：$error');
    }
  }

  Future<void> _archiveProject(StudioProject project) async {
    final next = !project.archived;
    try {
      await widget.controller.archiveProject(
        projectId: project.id,
        archived: next,
      );
      _toast(next ? '已归档' : '已取消归档');
    } catch (error) {
      _toast('操作失败：$error');
    }
  }

  Future<void> _deleteConversation(StudioConversation conversation) async {
    final purge = await showPurgeConfirmDialog(
      context,
      title: '删除会话',
      message: '将永久删除会话「${conversation.title}」及其全部生成记录。',
    );
    if (purge == null) return;
    try {
      await widget.controller.deleteConversation(conversation.id, purge: purge);
      _toast(purge ? '已删除（含服务器图片）' : '已删除');
    } catch (error) {
      _toast('删除失败：$error');
    }
  }

  Future<void> _toggleFavorite(StudioFavorite favorite) async {
    try {
      await widget.controller.removeFavorite(favorite);
      _toast('已取消收藏');
    } catch (error) {
      _toast('操作失败：$error');
    }
  }

  void _openFavoriteInViewer(StudioFavorite favorite) {
    final uri = _resolveFavoriteUri(favorite);
    showStudioResultViewer(
      context,
      StudioResultImage(url: uri, path: favorite.imagePath),
    );
  }

  void _openAssetInViewer(StudioAsset asset) {
    showStudioResultViewer(
      context,
      StudioResultImage(url: _resolveAssetUri(asset), path: asset.path),
      promptText: asset.prompt.isNotEmpty ? asset.prompt : asset.revisedPrompt,
      model: asset.model.isNotEmpty ? asset.model : null,
      size: asset.sizeLabel.isNotEmpty ? asset.sizeLabel : null,
      initialFavorited: widget.controller.state.favorites.any(
        (favorite) => favorite.imagePath == asset.path,
      ),
      imageSaver: _imageSaver,
      onFavorite: () => _toggleFavoriteAsset(asset),
      onVariation: () => _generateVariantFromAsset(asset),
    );
  }

  Uri _resolveAssetUri(StudioAsset asset) {
    if (asset.url.hasScheme) {
      return asset.url;
    }
    final base =
        widget.controller.imageBaseUrl ?? Uri.parse('http://localhost:8000');
    return base.resolve(asset.path);
  }

  Uri _resolveFavoriteUri(StudioFavorite favorite) {
    final absolute = Uri.tryParse(favorite.imagePath);
    if (absolute != null && absolute.hasScheme) {
      return absolute;
    }
    final base =
        widget.controller.imageBaseUrl ?? Uri.parse('http://localhost:8000');
    return base.resolve(favorite.imagePath);
  }

  Future<void> _toggleFavoriteAsset(StudioAsset asset) async {
    try {
      await widget.controller.toggleFavoriteAsset(asset);
      final favorited = widget.controller.state.favorites.any(
        (favorite) => favorite.imagePath == asset.path,
      );
      _toast(favorited ? '已收藏' : '已取消收藏');
    } catch (error) {
      _toast('收藏失败：$error');
    }
  }

  Future<void> _generateVariantFromAsset(StudioAsset asset) async {
    final conversationId = widget.controller.state.activeConversation?.id;
    if (conversationId == null) {
      _toast('请先创建一个会话');
      return;
    }
    final prompt = asset.prompt.isNotEmpty
        ? asset.prompt
        : asset.revisedPrompt.isNotEmpty
        ? asset.revisedPrompt
        : asset.name;
    if (prompt.trim().isEmpty) {
      _toast('这张图没有可复用的 prompt');
      return;
    }
    setState(() => _selectedIndex = 1);
    try {
      await widget.controller.submitGeneration(
        conversationId: conversationId,
        prompt: prompt,
        model: asset.model.isNotEmpty ? asset.model : 'gpt-image-2',
        size: asset.sizeLabel.isNotEmpty ? asset.sizeLabel : null,
      );
      _toast('已发起变体生成');
    } catch (error) {
      _toast('生成变体失败：$error');
    }
  }

  Future<void> _downloadAsset(StudioAsset asset) async {
    try {
      final file = await _imageSaver.saveImage(
        imageUrl: _resolveAssetUri(asset),
        fileName: _assetFileName(asset),
      );
      _toast('已保存到 ${file.path}');
    } catch (error) {
      _toast('下载失败：$error');
    }
  }

  Future<void> _shareAsset(StudioAsset asset) async {
    try {
      final file = await _imageSaver.saveImage(
        imageUrl: _resolveAssetUri(asset),
        fileName: _assetFileName(asset),
      );
      final sharer = widget.fileSharer ?? _shareFiles;
      await sharer([XFile(file.path)]);
      _toast('已分享 ${asset.name}');
    } catch (error) {
      _toast('分享失败：$error');
    }
  }

  Future<void> _downloadAssetZip(List<StudioAsset> assets) async {
    if (assets.isEmpty) return;
    try {
      final bytes = await widget.controller.downloadLibraryAssets(
        assets.map((asset) => asset.path).toList(growable: false),
      );
      final file = await _imageSaver.saveBytes(
        bytes: bytes,
        fileName: _assetZipFileName(),
      );
      final sharer = widget.fileSharer ?? _shareFiles;
      await sharer([XFile(file.path)]);
      _toast('已导出 ${assets.length} 张为 zip');
    } catch (error) {
      _toast('导出 zip 失败：$error');
    }
  }

  Future<void> _tagAssets(List<StudioAsset> assets) async {
    if (assets.isEmpty) return;
    final tag = await _promptForName(
      title: '批量打标签',
      hint: '输入标签名',
      confirmLabel: '保存',
    );
    if (tag == null || tag.trim().isEmpty) return;
    try {
      await widget.controller.tagLibraryAssets(
        imagePaths: assets.map((asset) => asset.path).toList(growable: false),
        tags: [tag.trim()],
      );
      _toast('已为 ${assets.length} 张图片打标签');
    } catch (error) {
      _toast('打标签失败：$error');
    }
  }

  Future<void> _deleteAssets(List<StudioAsset> assets) async {
    if (assets.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('将永久删除选中的 ${assets.length} 张服务器图片，继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.controller.deleteLibraryAssets(
        assets.map((asset) => asset.path).toList(growable: false),
      );
      _toast('已删除 ${assets.length} 张图片');
    } catch (error) {
      _toast('删除失败：$error');
    }
  }

  Future<void> _exportFavorites() async {
    final favorites = widget.controller.state.favorites;
    if (favorites.isEmpty) {
      _toast('收藏夹是空的');
      return;
    }
    final saved = <XFile>[];
    var failed = 0;
    for (final favorite in favorites) {
      try {
        final uri = _resolveFavoriteUri(favorite);
        final file = await _imageSaver.saveImage(
          imageUrl: uri,
          fileName: _favoriteFileName(favorite),
        );
        saved.add(XFile(file.path));
      } catch (_) {
        failed += 1;
      }
    }
    if (saved.isEmpty) {
      _toast('导出失败');
      return;
    }
    final sharer = widget.fileSharer ?? _shareFiles;
    try {
      await sharer(saved);
    } catch (_) {
      // Best-effort sharing; the files are already on disk.
    }
    final suffix = failed > 0 ? '，$failed 张失败' : '';
    _toast('已导出 ${saved.length} 张$suffix');
  }

  String _favoriteFileName(StudioFavorite favorite) {
    final segment = favorite.imagePath.split('/').last;
    if (segment.isNotEmpty && segment.contains('.')) {
      return segment;
    }
    return 'favorite-${favorite.id}.png';
  }

  String _assetFileName(StudioAsset asset) {
    if (asset.name.isNotEmpty && asset.name.contains('.')) {
      return asset.name;
    }
    final segment = asset.path.split('/').last;
    if (segment.isNotEmpty && segment.contains('.')) {
      return segment;
    }
    return 'asset-${asset.path.hashCode}.png';
  }

  String _assetZipFileName() {
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    return 'image-library-$stamp.zip';
  }

  Future<void> _shareFiles(List<XFile> files) async {
    await Share.shareXFiles(files);
  }

  Future<void> _openGithub() async {
    await _launch(Uri.parse(widget.githubUrl));
  }

  Future<void> _openFeedback() async {
    await _launch(Uri.parse(widget.feedbackUrl));
  }

  Future<void> _openServerLogs(AuthSession session) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final repository = SystemLogsRepository(
      ApiClient(
        dio: Dio(BaseOptions(baseUrl: session.baseUrl.toString())),
        tokenProvider: () async => session.token,
      ),
    );
    final controller = SystemLogsController(repository);
    try {
      await navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => LogsScreen(controller: controller),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _launch(Uri uri) async {
    final launcher = widget.urlLauncher ?? _defaultLaunch;
    final ok = await launcher(uri);
    if (!ok) {
      _toast('无法打开链接');
    }
  }

  Future<bool> _defaultLaunch(Uri uri) {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load studio workspace: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        final state = widget.controller.state;
        final palette = KilnAccentPalette.forAccent(
          KilnAccent.fromName(state.preferences.accent),
        );
        return KilnThemeScope(
          palette: palette,
          child: Theme(
            data: buildImageStudioTheme(palette: palette),
            child: AdaptiveShell(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              create: CreateScreen(controller: widget.controller),
              library: LibraryScreen(
                assets: state.libraryAssets,
                favorites: state.favorites,
                baseUrl: widget.controller.imageBaseUrl,
                onFavorite: _toggleFavorite,
                onContinueEdit: _openFavoriteInViewer,
                onToggleFavoriteAsset: _toggleFavoriteAsset,
                onContinueEditAsset: _openAssetInViewer,
                onGenerateVariant: _generateVariantFromAsset,
                onDownloadAsset: _downloadAsset,
                onShareAsset: _shareAsset,
                onBatchDownload: _downloadAssetZip,
                onBatchTag: _tagAssets,
                onBatchDelete: _deleteAssets,
                initialNewestFirst: state.preferences.libraryNewestFirst,
                onSortChanged: (newestFirst) {
                  widget.controller.updatePreferences(
                    state.preferences.copyWith(libraryNewestFirst: newestFirst),
                  );
                },
              ),
              projects: ProjectsScreen(
                projects: state.projects,
                conversations: state.conversations,
                activeProjectId: state.activeProject?.id,
                activeConversationId: state.activeConversation?.id,
                onProjectSelected: (projectId) async {
                  await widget.controller.selectProject(projectId);
                },
                onConversationSelected: (conversationId) async {
                  await widget.controller.selectConversation(conversationId);
                },
                onCreateProject: _createProject,
                onRenameProject: _renameProject,
                onArchiveProject: _archiveProject,
                onDeleteConversation: _deleteConversation,
              ),
              settings: SettingsScreen(
                preferences: state.preferences,
                onPreferencesChanged: widget.controller.updatePreferences,
                onSignOut: widget.onSignOut,
                onExportFavorites: _exportFavorites,
                onTapGithub: _openGithub,
                onTapFeedback: _openFeedback,
                userName: widget.session?.identity.name,
                serverUrl: widget.session?.baseUrl.authority,
                keyActive: widget.session != null,
                isAdmin: widget.session?.identity.role == AuthRole.admin,
                onOpenServerLogs: widget.session == null
                    ? null
                    : () => _openServerLogs(widget.session!),
              ),
            ),
          ),
        );
      },
    );
  }
}
