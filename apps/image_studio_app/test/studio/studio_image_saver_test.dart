import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/studio_image_saver.dart';

void main() {
  test('saves an image payload to the provided directory', () async {
    final tempDir = await Directory.systemTemp.createTemp('studio_image_saver');
    addTearDown(() => tempDir.delete(recursive: true));

    final saver = StudioImageSaver(
      outputDirectoryProvider: () async => tempDir,
      bytesLoader: (_) async => Uint8List.fromList([1, 2, 3, 4]),
    );

    final savedFile = await saver.saveImage(
      imageUrl: Uri.parse('http://example.test/images/landscape.png'),
      fileName: 'landscape.png',
    );

    expect(await savedFile.exists(), isTrue);
    expect(savedFile.path, contains('landscape.png'));
    expect(await savedFile.readAsBytes(), [1, 2, 3, 4]);
  });
}
