import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/core/api/api_client.dart';
import 'package:image_studio_app/studio/studio_repository.dart';

void main() {
  test(
    'fetchLibraryAssets reads /api/images and parses returned items',
    () async {
      final adapter = _QueueAdapter([
        _JsonResponse(<String, Object?>{
          'items': <Object?>[
            <String, Object?>{
              'path': '2026/05/19/orange.png',
              'name': 'orange.png',
              'date': '2026-05-19',
              'size': 4096,
              'created_at': '2026-05-19 09:30:00',
              'url': 'http://localhost:8000/images/2026/05/19/orange.png',
              'thumbnail_url':
                  'http://localhost:8000/image-thumbnails/2026/05/19/orange.png',
              'tags': <Object?>['海报'],
              'prompt': 'orange product photo',
              'model': 'gpt-image-2',
              'project_name': 'Spring Campaign',
            },
          ],
        }),
      ]);
      final repository = _repository(adapter);

      final assets = await repository.fetchLibraryAssets();

      expect(adapter.requests.single.path, '/api/images');
      expect(assets.single.path, '2026/05/19/orange.png');
      expect(assets.single.prompt, 'orange product photo');
    },
  );

  test(
    'updateImageTags posts the selected path and cleaned tag list',
    () async {
      final adapter = _QueueAdapter([
        _JsonResponse(<String, Object?>{
          'ok': true,
          'tags': <Object?>['海报', '收藏'],
        }),
      ]);
      final repository = _repository(adapter);

      final tags = await repository.updateImageTags(
        imagePath: '2026/05/19/orange.png',
        tags: const ['海报', '收藏'],
      );

      expect(adapter.requests.single.path, '/api/images/tags');
      expect(adapter.requests.single.body, <String, Object?>{
        'path': '2026/05/19/orange.png',
        'tags': <String>['海报', '收藏'],
      });
      expect(tags, ['海报', '收藏']);
    },
  );

  test('deleteImages posts the selected asset paths', () async {
    final adapter = _QueueAdapter([
      _JsonResponse(<String, Object?>{'removed': 2}),
    ]);
    final repository = _repository(adapter);

    await repository.deleteImages(const [
      '2026/05/19/orange.png',
      '2026/05/19/blue.png',
    ]);

    expect(adapter.requests.single.path, '/api/images/delete');
    expect(adapter.requests.single.body, <String, Object?>{
      'paths': <String>['2026/05/19/orange.png', '2026/05/19/blue.png'],
    });
  });

  test(
    'downloadImagesZip posts selected paths and returns zip bytes',
    () async {
      final adapter = _QueueAdapter([
        _BytesResponse(Uint8List.fromList(const [80, 75, 3, 4])),
      ]);
      final repository = _repository(adapter);

      final bytes = await repository.downloadImagesZip(const [
        '2026/05/19/orange.png',
      ]);

      expect(bytes, const [80, 75, 3, 4]);
      expect(adapter.requests.single.path, '/api/images/download');
      expect(adapter.requests.single.body, <String, Object?>{
        'paths': <String>['2026/05/19/orange.png'],
      });
    },
  );

  test('fetchRecipes reads reusable image recipes', () async {
    final adapter = _QueueAdapter([
      _JsonResponse(<String, Object?>{
        'items': <Object?>[
          <String, Object?>{
            'id': 'recipe-1',
            'name': 'Orange recipe',
            'prompt': 'orange product photo',
            'model': 'gpt-image-2',
            'size': '1024x1792',
            'source_image_path': '2026/05/19/orange.png',
            'tags': <Object?>['海报'],
            'created_at': '2026-05-19T09:30:00Z',
            'updated_at': '2026-05-19T09:30:00Z',
          },
        ],
      }),
    ]);
    final repository = _repository(adapter);

    final recipes = await repository.fetchRecipes();

    expect(adapter.requests.single.path, '/api/image-recipes');
    expect(recipes.single.name, 'Orange recipe');
    expect(recipes.single.sourceImagePath, '2026/05/19/orange.png');
  });

  test('createRecipe posts generation settings from an asset', () async {
    final adapter = _QueueAdapter([
      _JsonResponse(<String, Object?>{
        'item': <String, Object?>{
          'id': 'recipe-1',
          'name': 'Orange recipe',
          'prompt': 'orange product photo',
          'model': 'gpt-image-2',
          'size': '1024x1792',
          'source_image_path': '2026/05/19/orange.png',
          'tags': <Object?>['海报'],
          'created_at': '2026-05-19T09:30:00Z',
          'updated_at': '2026-05-19T09:30:00Z',
        },
      }),
    ]);
    final repository = _repository(adapter);

    final recipe = await repository.createRecipe(
      name: 'Orange recipe',
      prompt: 'orange product photo',
      model: 'gpt-image-2',
      size: '1024x1792',
      sourceImagePath: '2026/05/19/orange.png',
      sourceTurnId: 'turn-1',
      projectId: 'project-1',
      tags: const ['海报'],
    );

    expect(adapter.requests.single.path, '/api/image-recipes');
    expect(adapter.requests.single.body, <String, Object?>{
      'name': 'Orange recipe',
      'prompt': 'orange product photo',
      'model': 'gpt-image-2',
      'size': '1024x1792',
      'source_image_path': '2026/05/19/orange.png',
      'source_turn_id': 'turn-1',
      'project_id': 'project-1',
      'tags': <String>['海报'],
    });
    expect(recipe.id, 'recipe-1');
  });

  test('deleteRecipe deletes the selected recipe endpoint', () async {
    final adapter = _QueueAdapter([
      _JsonResponse(<String, Object?>{'ok': true}),
    ]);
    final repository = _repository(adapter);

    await repository.deleteRecipe('recipe-1');

    expect(adapter.requests.single.path, '/api/image-recipes/recipe-1');
  });
}

StudioRepository _repository(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = adapter;
  return StudioRepository(
    ApiClient(dio: dio, tokenProvider: () async => 'sk-test'),
  );
}

class _RecordedRequest {
  const _RecordedRequest({required this.path, required this.body});

  final String path;
  final Object? body;
}

abstract class _QueuedResponse {
  const _QueuedResponse();
}

class _JsonResponse extends _QueuedResponse {
  const _JsonResponse(this.body);

  final Map<String, Object?> body;
}

class _BytesResponse extends _QueuedResponse {
  const _BytesResponse(this.body);

  final Uint8List body;
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this._responses);

  final List<_QueuedResponse> _responses;
  final List<_RecordedRequest> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(_RecordedRequest(path: options.path, body: options.data));
    final response = _responses.removeAt(0);
    if (response is _BytesResponse) {
      return ResponseBody.fromBytes(
        response.body,
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/zip'],
        },
      );
    }
    response as _JsonResponse;
    return ResponseBody.fromString(
      jsonEncode(response.body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
