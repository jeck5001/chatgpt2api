import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../app/tokens.dart';
import '../shared/components/chip_bar.dart';
import '../shared/components/section_header.dart';
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
  });

  final List<StudioFavorite> favorites;
  final Uri? baseUrl;
  final ValueChanged<StudioFavorite>? onFavorite;
  final ValueChanged<StudioFavorite>? onContinueEdit;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _activeFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final all = widget.favorites;
    final visible = switch (_activeFilter) {
      'favorites' => all, // every item in the favorites list is favorited
      _ => all,
    };

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader.large(
              kicker: '05 · 图库',
              title: '图库',
              subtitle: '${all.length} 张作品 · ${_favoriteCount(all)} 个收藏',
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
                KilnChipData(label: '项目 ▾', onTap: () {}),
                KilnChipData(label: '模型 ▾', onTap: () {}),
                KilnChipData(label: '最新 ▾', onTap: () {}),
              ],
            ),
            const SizedBox(height: KilnSpacing.sm),
            Expanded(
              child: visible.isEmpty
                  ? const EmptyState(
                      title: '图库',
                      accent: '空空如也',
                      message: '完成第一张作品，它就会出现在这里。',
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
                Image.network(
                  imageUri.toString(),
                  fit: BoxFit.cover,
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
