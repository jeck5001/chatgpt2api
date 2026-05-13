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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Preview'),
      ),
      body: Center(
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
