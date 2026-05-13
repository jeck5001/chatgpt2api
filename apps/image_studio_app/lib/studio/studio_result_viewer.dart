import 'package:flutter/material.dart';

import 'studio_models.dart';

class StudioResultViewer extends StatelessWidget {
  const StudioResultViewer({
    super.key,
    required this.imageUrl,
    required this.imagePath,
  });

  final String imageUrl;
  final String imagePath;

  void _showPlaceholder(BuildContext context, String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label is coming next')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Preview'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        imagePath,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPlaceholder(context, 'Save'),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showPlaceholder(context, 'Share'),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showStudioResultViewer(
  BuildContext context,
  StudioResultImage image,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => StudioResultViewer(
        imageUrl: image.url.toString(),
        imagePath: image.path,
      ),
      fullscreenDialog: true,
    ),
  );
}
