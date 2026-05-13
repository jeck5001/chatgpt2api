import 'package:flutter/material.dart';

import '../shared/empty_state.dart';
import '../shared/image_result_card.dart';
import '../studio/studio_models.dart';

class LibraryScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (favorites.isEmpty) {
      return const EmptyState(
        title: 'Library',
        message: 'Recent and favorite generated images will appear here.',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        return ImageResultCard(
          imageUrl: _imageUri(favorite.imagePath),
          onFavorite: () => onFavorite?.call(favorite),
          onContinueEdit: () => onContinueEdit?.call(favorite),
        );
      },
    );
  }

  Uri _imageUri(String path) {
    final absolute = Uri.tryParse(path);
    if (absolute != null && absolute.hasScheme) {
      return absolute;
    }
    return (baseUrl ?? Uri.parse('http://localhost:8000')).resolve(path);
  }
}
