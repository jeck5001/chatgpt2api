import 'package:flutter/material.dart';

class ImageResultCard extends StatelessWidget {
  const ImageResultCard({
    super.key,
    required this.imageUrl,
    required this.onFavorite,
    required this.onContinueEdit,
  });

  final Uri imageUrl;
  final VoidCallback onFavorite;
  final VoidCallback onContinueEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Image.network(
              imageUrl.toString(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Icon(Icons.broken_image_outlined));
              },
            ),
          ),
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: onFavorite,
                icon: const Icon(Icons.star_border),
              ),
              TextButton(
                onPressed: onContinueEdit,
                child: const Text('Continue edit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
