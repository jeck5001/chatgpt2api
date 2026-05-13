import 'package:flutter/material.dart';

import 'studio_image_saver.dart';
import 'studio_models.dart';

typedef SaveImageAction =
    Future<String> Function(
      StudioImageSaver imageSaver,
      Uri imageUrl,
      String fileName,
    );

typedef ShareImageAction =
    Future<String> Function(
      StudioImageSaver imageSaver,
      Uri imageUrl,
      String fileName,
    );

class StudioResultViewer extends StatelessWidget {
  StudioResultViewer({
    super.key,
    required this.imageUrl,
    required this.imagePath,
    StudioImageSaver? imageSaver,
    SaveImageAction? onSaveImage,
    ShareImageAction? onShareImage,
  }) : imageSaver = imageSaver ?? StudioImageSaver(),
       onSaveImage = onSaveImage ?? _defaultSaveImage,
       onShareImage = onShareImage ?? _defaultShareImage;

  final String imageUrl;
  final String imagePath;
  final StudioImageSaver imageSaver;
  final SaveImageAction onSaveImage;
  final ShareImageAction onShareImage;

  static Future<String> _defaultSaveImage(
    StudioImageSaver imageSaver,
    Uri imageUrl,
    String fileName,
  ) async {
    final file = await imageSaver.saveImage(
      imageUrl: imageUrl,
      fileName: fileName,
    );
    return file.path;
  }

  static Future<String> _defaultShareImage(
    StudioImageSaver imageSaver,
    Uri imageUrl,
    String fileName,
  ) async {
    final file = await imageSaver.saveImage(
      imageUrl: imageUrl,
      fileName: fileName,
    );
    return file.path;
  }

  Future<void> _save(BuildContext context) async {
    final uri = Uri.parse(imageUrl);
    final savedPath = await onSaveImage(
      imageSaver,
      uri,
      uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image.png',
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved to $savedPath')));
  }

  Future<void> _share(BuildContext context) async {
    final uri = Uri.parse(imageUrl);
    final sharedPath = await onShareImage(
      imageSaver,
      uri,
      uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'image.png',
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Shared $sharedPath')));
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
                    onPressed: () => _save(context),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _share(context),
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
