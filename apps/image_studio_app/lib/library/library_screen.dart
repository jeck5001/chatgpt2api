import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../app/tokens.dart';
import '../app/typography.dart';
import '../shared/components/chip_bar.dart';
import '../shared/components/section_header.dart';
import '../shared/components/shimmer_placeholder.dart';
import '../shared/empty_state.dart';
import '../studio/studio_models.dart';

/// The Gallery — every image you've ever made, browseable as a real-aspect
/// masonry grid.
///
/// Class name preserved (`LibraryScreen`) so router and existing imports
/// stay intact; the public surface (favorites / baseUrl / onFavorite /
/// onContinueEdit) is the same.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    this.favorites = const [],
    this.baseUrl,
    this.onFavorite,
    this.onContinueEdit,
    this.initialNewestFirst = true,
    this.onSortChanged,
  });

  final List<StudioFavorite> favorites;
  final Uri? baseUrl;
  final ValueChanged<StudioFavorite>? onFavorite;
  final ValueChanged<StudioFavorite>? onContinueEdit;
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

  bool _matches(StudioFavorite favorite, String needle) {
    if (needle.isEmpty) return true;
    return favorite.prompt.toLowerCase().contains(needle);
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.favorites;
    final needle = _searchQuery.toLowerCase();
    final filteredByChip = switch (_activeFilter) {
      'favorites' => all, // every item in the favorites list is favorited
      _ => all,
    };
    final visible =
        List<StudioFavorite>.of(filteredByChip.where((f) => _matches(f, needle)))
          ..sort((a, b) {
            return _newestFirst
                ? b.createdAt.compareTo(a.createdAt)
                : a.createdAt.compareTo(b.createdAt);
          });
    final searching = _searchQuery.isNotEmpty;
    final subtitle = searching
        ? '搜索 “$_searchQuery” · 命中 ${visible.length} / ${all.length}'
        : '${all.length} 张作品 · ${_favoriteCount(all)} 个收藏';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader.large(
              kicker: '05 · 图库',
              title: '图库',
              subtitle: subtitle,
            ),
            const SizedBox(height: KilnSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: KilnSpacing.sm + 2,
              ),
              child: _LibrarySearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
                hasQuery: searching,
              ),
            ),
            const SizedBox(height: KilnSpacing.sm),
            KilnChipBar(
              items: [
                KilnChipData(
                  label: '全部',
                  active: _activeFilter == 'all',
                  onTap: () => setState(() => _activeFilter = 'all'),
                ),
                KilnChipData(
                  label: '收藏',
                  icon: Icons.favorite_outline,
                  active: _activeFilter == 'favorites',
                  onTap: () => setState(() => _activeFilter = 'favorites'),
                ),
                KilnChipData(label: '项目 ▾', onTap: () => _toast('项目筛选即将上线')),
                KilnChipData(label: '模型 ▾', onTap: () => _toast('模型筛选即将上线')),
                KilnChipData(
                  label: _newestFirst ? '最新 ▾' : '最早 ▾',
                  onTap: _toggleNewestFirst,
                ),
              ],
            ),
            const SizedBox(height: KilnSpacing.sm),
            Expanded(
              child: visible.isEmpty
                  ? EmptyState(
                      title: '图库',
                      accent: searching ? '没找到' : '空空如也',
                      message: searching
                          ? '换个关键词试试，或清空搜索看看所有作品。'
                          : '完成第一张作品，它就会出现在这里。',
                    )
                  : _Masonry(
                      items: visible,
                      baseUrl: widget.baseUrl,
                      onFavorite: widget.onFavorite,
                      onTap: widget.onContinueEdit,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int _favoriteCount(List<StudioFavorite> items) => items.length;

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _LibrarySearchField extends StatelessWidget {
  const _LibrarySearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasQuery,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                hintText: '搜索 prompt',
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
          if (hasQuery)
            IconButton(
              icon: Icon(Icons.close, size: 16, color: KilnColors.ink500),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: '清除',
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}

class _Masonry extends StatelessWidget {
  const _Masonry({
    required this.items,
    this.baseUrl,
    this.onFavorite,
    this.onTap,
  });

  final List<StudioFavorite> items;
  final Uri? baseUrl;
  final ValueChanged<StudioFavorite>? onFavorite;
  final ValueChanged<StudioFavorite>? onTap;

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
            final fav = items[index];
            // Deterministic pseudo-random aspect ratio per item so the
            // masonry feels real even with placeholder data.
            final ratio = _ratioFor(fav.id, index);
            return _GalleryTile(
              favorite: fav,
              aspectRatio: ratio,
              imageUri: _resolveUri(fav.imagePath),
              onTap: onTap == null ? null : () => onTap!(fav),
              onFavoriteToggle: onFavorite == null
                  ? null
                  : () => onFavorite!(fav),
            );
          },
        );
      },
    );
  }

  Uri _resolveUri(String path) {
    final absolute = Uri.tryParse(path);
    if (absolute != null && absolute.hasScheme) {
      return absolute;
    }
    return (baseUrl ?? Uri.parse('http://localhost:8000')).resolve(path);
  }

  double _ratioFor(String id, int index) {
    final ratios = [0.75, 1.0, 1.25, 0.85, 1.1, 1.35, 0.92, 1.5];
    return ratios[(id.hashCode ^ index).abs() % ratios.length];
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.favorite,
    required this.aspectRatio,
    required this.imageUri,
    this.onTap,
    this.onFavoriteToggle,
  });

  final StudioFavorite favorite;
  final double aspectRatio;
  final Uri imageUri;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final tag = 'studio-image:${favorite.imagePath}';
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Colors.black,
        child: InkWell(
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: tag,
                  child: Image.network(
                    imageUri.toString(),
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
                if (favorite.prompt.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: _TileCaption(text: favorite.prompt),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: _FavoriteBadge(onTap: onFavoriteToggle),
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
  const _TileCaption({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0xB3000000)],
        ),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: KilnTypography.ui(
          size: 11,
          weight: FontWeight.w500,
          color: Colors.white,
          height: 1.35,
        ),
      ),
    );
  }
}

class _FavoriteBadge extends StatelessWidget {
  const _FavoriteBadge({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
        child: const Icon(Icons.favorite, size: 14, color: KilnColors.ember400),
      ),
    );
  }
}
