import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

typedef OutputDirectoryProvider = Future<Directory> Function();
typedef ImageBytesLoader = Future<Uint8List> Function(Uri imageUrl);

class StudioImageSaver {
  StudioImageSaver({
    OutputDirectoryProvider? outputDirectoryProvider,
    ImageBytesLoader? bytesLoader,
  }) : _outputDirectoryProvider =
           outputDirectoryProvider ?? getApplicationDocumentsDirectory,
       _bytesLoader = bytesLoader ?? _defaultBytesLoader;

  final OutputDirectoryProvider _outputDirectoryProvider;
  final ImageBytesLoader _bytesLoader;

  Future<File> saveImage({
    required Uri imageUrl,
    required String fileName,
  }) async {
    final outputDirectory = await _outputDirectoryProvider();
    await outputDirectory.create(recursive: true);
    final bytes = await _bytesLoader(imageUrl);
    final targetFile = File('${outputDirectory.path}/$fileName');
    return targetFile.writeAsBytes(bytes, flush: true);
  }

  static Future<Uint8List> _defaultBytesLoader(Uri imageUrl) async {
    final response = await Dio().get<List<int>>(
      imageUrl.toString(),
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const <int>[]);
  }
}
