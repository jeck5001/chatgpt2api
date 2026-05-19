import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import '../shared/components/chip_bar.dart';
import '../shared/components/section_header.dart';
import '../shared/components/shimmer_placeholder.dart';
import '../shared/empty_state.dart';
import '../studio/studio_models.dart';

/// The Gallery — now backed by every server-side image asset, while keeping the
/// original favorites-only constructor surface for existing callers and tests.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    this.assets = const [],
    this.favorites = const [],
    this.baseUrl,
    this.onFavorite,
    this.onContinueEdit,
    this.onToggleFavoriteAsset,
    this.onContinueEditAsset,
    this.onGenerateVariant,
    this.onDownloadAsset,
    this.onShareAsset,
    this.onBatchDownload,
    this.onBatchTag,
    this.onBatchDelete,
    this.initialNewestFirst = true,
    this.onSortChanged,
  });

  final List<StudioAsset> assets;
  final List<StudioFavorite> favorites;
  final Uri? baseUrl;
  final ValueChanged<StudioFavorite>? onFavorite;
  final ValueChanged<StudioFavorite>? onContinueEdit;
  final ValueChanged<StudioAsset>? onToggleFavoriteAsset;
  final ValueChanged<StudioAsset>? onContinueEditAsset;
  final ValueChanged<StudioAsset>? onGenerateVariant;
  final ValueChanged<StudioAsset>? onDownloadAsset;
  final ValueChanged<StudioAsset>? onShareAsset;
  final ValueChanged<List<StudioAsset>>? onBatchDownload;
  final ValueChanged<List<StudioAsset>>? onBatchTag;
  final ValueChanged<List<StudioAsset>>? onBatchDelete;
  final bool initialNewestFirst;
  final ValueChanged<bool>? onSortChanged;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _activeFilter = 'all';
  late bool _newestFirst = widget.initialNewestFirst;
  late final TextEditingController _searchController;
  String _searchQuery = '';
  bool _batchMode = false;
  final Set<String> _selectedPaths = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialNewestFirst != widget.initialNewestFirst) {
      _newestFirst = widget.initialNewestFirst;
    }
    final paths = _allAssets.map((asset) => asset.path).toSet();
    _selectedPaths.removeWhere((path) => !paths.contains(path));
  }

  void _toggleNewestFirst() {
    final next = !_newestFirst;
    setState(() => _newestFirst = next);
    widget.onSortChanged?.call(next);
  }

  void _onSearchChanged(String value) {
    final next = value.trim();
    if (next == _searchQuery) return;
    setState(() => _searchQuery = next);
  }

  void _clearSearch() {
    if (_searchQuery.isEmpty && _searchController.text.isEmpty) return;
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  List<StudioAsset> get _allAssets {
    if (widget.assets.isNotEmpty) return widget.assets;
    return widget.favorites.map(_assetFromFavorite).toList(growable: false);
  }

  StudioAsset _assetFromFavorite(StudioFavorite favorite) {
    final uri = _resolveUri(favorite.imagePath);
    return StudioAsset(
      path: favorite.imagePath,
      name: _fileName(favorite.imagePath),
      date: _dateLabel(favorite.createdAt),
      sizeBytes: 0,
      createdAt: favorite.createdAt,
      url: uri,
      thumbnailUrl: uri,
      prompt: favorite.prompt,
      turnId: favorite.sourceTurnId,
    );
  }

  Set<String> get _favoritePaths {
    return widget.favorites.map((favorite) => favorite.imagePath).toSet();
  }

  Map<String, StudioFavorite> get _favoritesByPath {
    return {
      for (final favorite in widget.favorites) favorite.imagePath: favorite,
    };
  }

  List<StudioAsset> get _visibleAssets {
    final all = _allAssets;
    final favoritePaths = _favoritePaths;
    final now = DateTime.now();
    final recentCutoff = now.subtract(const Duration(days: 30));
    final needle = _searchQuery.toLowerCase();
    final filtered = all.where((asset) {
      final matchesFilter = switch (_activeFilter) {
        'favorites' => favoritePaths.contains(asset.path),
        'recent' => asset.createdAt.isAfter(recentCutoff),
        'tagged' => asset.tags.isNotEmpty,
        _ => true,
      };
      if (!matchesFilter) return false;
      if (needle.isEmpty) return true;
      return asset.searchText.contains(needle);
    }).toList();
    filtered.sort((a, b) {
      return _newestFirst
          ? b.createdAt.compareTo(a.createdAt)
          : a.createdAt.compareTo(b.createdAt);
    });
    return filtered;
  }

  List<StudioAsset> get _selectedAssets {
    final byPath = {for (final asset in _allAssets) asset.path: asset};
    return [
      for (final path in _selectedPaths)
        if (byPath[path] != null) byPath[path]!,
    ];
  }

  void _setFilter(String filter) {
    setState(() => _activeFilter = filter);
  }

  void _toggleBatchMode() {
    setState(() {
      _batchMode = !_batchMode;
      if (!_batchMode) _selectedPaths.clear();
    });
  }

  void _toggleSelected(String path) {
    setState(() {
      if (!_selectedPaths.add(path)) {
        _selectedPaths.remove(path);
      }
    });
  }

  void _runBatch(ValueChanged<List<StudioAsset>>? action, String fallback) {
    final selected = _selectedAssets;
    if (selected.isEmpty) return;
    if (action == null) {
      _toast(fallback);
      return;
    }
    action(selected);
  }

  void _toggleFavorite(StudioAsset asset) {
    final callback = widget.onToggleFavoriteAsset;
    if (callback != null) {
      callback(asset);
      return;
    }
    final favorite = _favoritesByPath[asset.path];
    if (favorite != null) {
      widget.onFavorite?.call(favorite);
    }
  }

  void _continueEdit(StudioAsset asset) {
    final callback = widget.onContinueEditAsset;
    if (callback != null) {
      callback(asset);
      return;
    }
    final favorite = _favoritesByPath[asset.path];
    if (favorite != null) {
      widget.onContinueEdit?.call(favorite);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _allAssets;
    final visible = _visibleAssets;
    final searching = _searchQuery.isNotEmpty || _activeFilter != 'all';
    final subtitle = searching
        ? '搜索 “$_searchQuery” · 命中 ${visible.length} / ${all.length}'
        : '${all.length} 张作品 · ${_favoritePaths.length} 个收藏';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader.large(
              kicker: '05 · ASSET LIBRARY',
              title: '作品库',
              subtitle: subtitle,
            ),
            const SizedBox(height: KilnSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KilnSpacing.md),
              child: _LibraryWorkbench(
                controller: _searchController,
                searching: _searchQuery.isNotEmpty,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
              ),
            ),
            const SizedBox(height: KilnSpacing.sm),
            KilnChipBar(
              items: [
                KilnChipData(
                  label: '全部',
                  active: _activeFilter == 'all',
                  onTap: () => _setFilter('all'),
                ),
                KilnChipData(
                  label: '收藏',
                  icon: Icons.favorite_outline,
                  active: _activeFilter == 'favorites',
                  onTap: () => _setFilter('favorites'),
                ),
                KilnChipData(
                  label: '最近',
                  icon: Icons.history_rounded,
                  active: _activeFilter == 'recent',
                  onTap: () => _setFilter('recent'),
                ),
                KilnChipData(
                  label: '已标记',
                  icon: Icons.local_offer_outlined,
                  active: _activeFilter == 'tagged',
                  onTap: () => _setFilter('tagged'),
                ),
                KilnChipData(
                  label: _newestFirst ? '最新 ▾' : '最早 ▾',
                  onTap: _toggleNewestFirst,
                ),
                KilnChipData(
                  label: _batchMode ? '取消选择' : '选择',
                  icon: _batchMode
                      ? Icons.close_rounded
                      : Icons.checklist_rounded,
                  active: _batchMode,
                  onTap: _toggleBatchMode,
                ),
              ],
            ),
            const SizedBox(height: KilnSpacing.sm),
            Expanded(
              child: visible.isEmpty
                  ? EmptyState(
                      title: '作品库',
                      accent: searching ? '没找到' : '空空如也',
                      message: searching
                          ? '换个关键词试试，或清空搜索看看所有作品。'
                          : '完成第一张作品，它就会出现在这里。',
                      icon: searching
                          ? Icons.search_off_rounded
                          : Icons.collections_outlined,
                    )
                  : _AssetMasonry(
                      items: visible,
                      favoritePaths: _favoritePaths,
                      batchMode: _batchMode,
                      selectedPaths: _selectedPaths,
                      onToggleSelected: _toggleSelected,
                      onFavorite: _toggleFavorite,
                      onContinueEdit: _continueEdit,
                      onGenerateVariant: widget.onGenerateVariant,
                      onDownload: widget.onDownloadAsset,
                      onShare: widget.onShareAsset,
                    ),
            ),
            if (_batchMode)
              _BatchBar(
                selectedCount: _selectedPaths.length,
                onDownload: () => _runBatch(widget.onBatchDownload, '批量下载即将上线'),
                onTag: () => _runBatch(widget.onBatchTag, '批量打标签即将上线'),
                onDelete: () => _runBatch(widget.onBatchDelete, '批量删除即将上线'),
                onCancel: _toggleBatchMode,
              ),
          ],
        ),
      ),
    );
  }

  Uri _resolveUri(String path) {
    final absolute = Uri.tryParse(path);
    if (absolute != null && absolute.hasScheme) {
      return absolute;
    }
    return (widget.baseUrl ?? Uri.parse('http://localhost:8000')).resolve(path);
  }

  String _fileName(String path) {
    final segment = path.split('/').last;
    return segment.isEmpty ? path : segment;
  }

  String _dateLabel(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LibraryWorkbench extends StatelessWidget {
  const _LibraryWorkbench({
    required this.controller,
    required this.searching,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool searching;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KilnSpacing.sm),
      decoration: BoxDecoration(
        color: KilnColors.ink900,
        borderRadius: BorderRadius.circular(KilnRadii.card),
        border: Border.all(color: KilnColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '统一管理全部生成图、收藏、标签和后续编辑动作。',
            style: KilnTypography.bodyS.copyWith(color: KilnColors.ink300),
          ),
          const SizedBox(height: KilnSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: KilnColors.ink800,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: KilnSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.search, size: 18, color: KilnColors.ink500),
                const SizedBox(width: KilnSpacing.xs),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: KilnTypography.ui(size: 14),
                    cursorColor: KilnColors.ember500,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: '搜索 prompt、项目、日期、模型、标签',
                      hintStyle: KilnTypography.ui(
                        size: 14,
                        color: KilnColors.ink500,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                if (searching)
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: KilnColors.ink500),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: '清除',
                    onPressed: onClear,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetMasonry extends StatelessWidget {
  const _AssetMasonry({
    required this.items,
    required this.favoritePaths,
    required this.batchMode,
    required this.selectedPaths,
    required this.onToggleSelected,
    required this.onFavorite,
    required this.onContinueEdit,
    this.onGenerateVariant,
    this.onDownload,
    this.onShare,
  });

  final List<StudioAsset> items;
  final Set<String> favoritePaths;
  final bool batchMode;
  final Set<String> selectedPaths;
  final ValueChanged<String> onToggleSelected;
  final ValueChanged<StudioAsset> onFavorite;
  final ValueChanged<StudioAsset> onContinueEdit;
  final ValueChanged<StudioAsset>? onGenerateVariant;
  final ValueChanged<StudioAsset>? onDownload;
  final ValueChanged<StudioAsset>? onShare;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 1100
            ? 4
            : width > 720
            ? 3
            : 2;
        return MasonryGridView.count(
          padding: const EdgeInsets.fromLTRB(
            KilnSpacing.sm + 2,
            KilnSpacing.sm + 2,
            KilnSpacing.sm + 2,
            KilnSpacing.xxxl,
          ),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final asset = items[index];
            return _GalleryTile(
              asset: asset,
              isFavorite: favoritePaths.contains(asset.path),
              isSelected: selectedPaths.contains(asset.path),
              batchMode: batchMode,
              aspectRatio: _ratioFor(asset, index),
              onToggleSelected: () => onToggleSelected(asset.path),
              onFavoriteToggle: () => onFavorite(asset),
              onContinueEdit: () => onContinueEdit(asset),
              onGenerateVariant: onGenerateVariant == null
                  ? null
                  : () => onGenerateVariant!(asset),
              onDownload: onDownload == null ? null : () => onDownload!(asset),
              onShare: onShare == null ? null : () => onShare!(asset),
            );
          },
        );
      },
    );
  }

  double _ratioFor(StudioAsset asset, int index) {
    if (asset.aspectRatio > 0 && asset.aspectRatio != 1) {
      return asset.aspectRatio;
    }
    final ratios = [0.75, 1.0, 1.25, 0.85, 1.1, 1.35, 0.92, 1.5];
    return ratios[(asset.path.hashCode ^ index).abs() % ratios.length];
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.asset,
    required this.isFavorite,
    required this.isSelected,
    required this.batchMode,
    required this.aspectRatio,
    required this.onToggleSelected,
    required this.onFavoriteToggle,
    required this.onContinueEdit,
    this.onGenerateVariant,
    this.onDownload,
    this.onShare,
  });

  final StudioAsset asset;
  final bool isFavorite;
  final bool isSelected;
  final bool batchMode;
  final double aspectRatio;
  final VoidCallback onToggleSelected;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onContinueEdit;
  final VoidCallback? onGenerateVariant;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final tag = 'studio-image:${asset.path}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Colors.black,
        child: InkWell(
          onTap: batchMode ? onToggleSelected : onContinueEdit,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: tag,
                  child: Image.network(
                    asset.thumbnailUrl.toString(),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return ShimmerPlaceholder(
                        aspectRatio: aspectRatio,
                        borderRadius: 0,
                      );
                    },
                    errorBuilder: (context, error, stack) => Container(
                      color: KilnColors.ink800,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(KilnSpacing.sm),
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: KilnColors.ink500,
                        size: 24,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(child: _TileCaption(asset: asset)),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: _FavoriteBadge(
                    active: isFavorite,
                    onTap: onFavoriteToggle,
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: batchMode
                        ? _SelectBadge(
                            key: const ValueKey('select'),
                            asset: asset,
                            selected: isSelected,
                            onTap: onToggleSelected,
                          )
                        : _ActionStrip(
                            key: const ValueKey('actions'),
                            onContinueEdit: onContinueEdit,
                            onGenerateVariant: onGenerateVariant,
                            onDownload: onDownload,
                            onShare: onShare,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TileCaption extends StatelessWidget {
  const _TileCaption({required this.asset});

  final StudioAsset asset;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (asset.projectName.isNotEmpty) asset.projectName,
      if (asset.model.isNotEmpty) asset.model,
      if (asset.tags.isNotEmpty) asset.tags.join(' · '),
    ].join(' / ');
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 44, 10, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xD9000000)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            asset.displayTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: KilnTypography.ui(
              size: 11,
              weight: FontWeight.w600,
              color: Colors.white,
              height: 1.35,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: KilnTypography.ui(
                size: 10,
                weight: FontWeight.w500,
                color: KilnColors.ink300,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionStrip extends StatelessWidget {
  const _ActionStrip({
    super.key,
    required this.onContinueEdit,
    this.onGenerateVariant,
    this.onDownload,
    this.onShare,
  });

  final VoidCallback onContinueEdit;
  final VoidCallback? onGenerateVariant;
  final VoidCallback? onDownload;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TileAction(
            tooltip: '继续编辑',
            icon: Icons.open_in_full_rounded,
            onPressed: onContinueEdit,
          ),
          _TileAction(
            tooltip: '生成变体',
            icon: Icons.auto_awesome_motion_outlined,
            onPressed: onGenerateVariant,
          ),
          _TileAction(
            tooltip: '下载',
            icon: Icons.download_outlined,
            onPressed: onDownload,
          ),
          _TileAction(
            tooltip: '分享',
            icon: Icons.ios_share_outlined,
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  const _TileAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 14),
      color: Colors.white,
      disabledColor: Colors.white.withValues(alpha: 0.38),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}

class _SelectBadge extends StatelessWidget {
  const _SelectBadge({
    super.key,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final StudioAsset asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '选择 ${asset.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: selected ? KilnColors.ember500 : Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? KilnColors.ember300 : Colors.white24,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            selected ? Icons.check_rounded : Icons.add_rounded,
            size: 16,
            color: selected ? KilnColors.ink950 : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: active ? '取消收藏' : '收藏',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            active ? Icons.favorite : Icons.favorite_outline,
            size: 14,
            color: active ? KilnColors.ember400 : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _BatchBar extends StatelessWidget {
  const _BatchBar({
    required this.selectedCount,
    required this.onDownload,
    required this.onTag,
    required this.onDelete,
    required this.onCancel,
  });

  final int selectedCount;
  final VoidCallback onDownload;
  final VoidCallback onTag;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final enabled = selectedCount > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        KilnSpacing.md,
        KilnSpacing.sm,
        KilnSpacing.md,
        KilnSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: KilnColors.ink950,
        border: Border(top: BorderSide(color: KilnColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '已选择 $selectedCount 张',
              style: KilnTypography.ui(
                size: 13,
                weight: FontWeight.w700,
                color: KilnColors.ink100,
              ),
            ),
          ),
          TextButton(
            onPressed: enabled ? onDownload : null,
            child: const Text('下载 zip'),
          ),
          TextButton(
            onPressed: enabled ? onTag : null,
            child: const Text('批量打标签'),
          ),
          TextButton(
            onPressed: enabled ? onDelete : null,
            child: const Text('批量删除'),
          ),
          TextButton(onPressed: onCancel, child: const Text('取消')),
        ],
      ),
    );
  }
}
