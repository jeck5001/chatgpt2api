import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import 'studio_models.dart';

class StudioEditImage {
  const StudioEditImage({
    required this.bytes,
    required this.filename,
    this.contentType,
  });

  final Uint8List bytes;
  final String filename;
  final String? contentType;
}

abstract interface class StudioRepositoryContract {
  Future<List<StudioProject>> fetchProjects();

  Future<StudioProject> createProject(String name);

  Future<StudioProject> updateProject({
    required String projectId,
    String? name,
    bool? archived,
  });

  Future<List<StudioConversation>> fetchConversations(String projectId);

  Future<StudioConversation> createConversation({
    required String projectId,
    required String title,
    String mode = 'generate',
  });

  Future<List<StudioTurn>> fetchTurns(String conversationId);

  Future<StudioTurn> createGenerationTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
  });

  Future<StudioTurn> createEditTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
    required List<StudioEditImage> images,
  });

  Future<StudioTurn> retryTurn({
    required String turnId,
    required String clientTaskId,
  });

  Future<StudioTurn> syncTurn(String turnId);

  Future<List<StudioFavorite>> fetchFavorites();

  Future<StudioFavorite> favoriteImage({
    required String imagePath,
    String sourceTurnId = '',
  });

  Future<void> deleteFavorite(String favoriteId);

  Future<List<StudioPromptTemplate>> fetchPromptTemplates();

  Future<StudioPromptTemplate> createPromptTemplate({
    required String name,
    required String category,
    required String content,
  });

  Future<void> deletePromptTemplate(String templateId);
}

class StudioRepository implements StudioRepositoryContract {
  const StudioRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<StudioProject>> fetchProjects() async {
    final payload = await _client.getJson('/api/projects');
    return _items(payload).map(StudioProject.fromJson).toList();
  }

  @override
  Future<StudioProject> createProject(String name) async {
    final payload = await _client.postJson(
      '/api/projects',
      body: <String, Object?>{'name': name},
    );
    return StudioProject.fromJson(payload['item']! as Map<String, Object?>);
  }

  @override
  Future<StudioProject> updateProject({
    required String projectId,
    String? name,
    bool? archived,
  }) async {
    final body = <String, Object?>{
      if (name != null) 'name': name,
      if (archived != null) 'archived': archived,
    };
    final payload = await _client.patchJson(
      '/api/projects/$projectId',
      body: body,
    );
    return StudioProject.fromJson(payload['item']! as Map<String, Object?>);
  }

  @override
  Future<List<StudioConversation>> fetchConversations(String projectId) async {
    final payload = await _client.getJson(
      '/api/image-conversations',
      query: <String, Object?>{'project_id': projectId},
    );
    return _items(payload).map(StudioConversation.fromJson).toList();
  }

  @override
  Future<StudioConversation> createConversation({
    required String projectId,
    required String title,
    String mode = 'generate',
  }) async {
    final payload = await _client.postJson(
      '/api/image-conversations',
      body: <String, Object?>{
        'project_id': projectId,
        'title': title,
        'mode': mode,
      },
    );
    return StudioConversation.fromJson(
      payload['item']! as Map<String, Object?>,
    );
  }

  @override
  Future<List<StudioTurn>> fetchTurns(String conversationId) async {
    final payload = await _client.getJson(
      '/api/image-turns',
      query: <String, Object?>{'conversation_id': conversationId},
    );
    return _items(payload).map(StudioTurn.fromJson).toList();
  }

  @override
  Future<StudioTurn> createGenerationTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
  }) async {
    final payload = await _client.postJson(
      '/api/image-turns/generations',
      body: <String, Object?>{
        'conversation_id': conversationId,
        'client_task_id': clientTaskId,
        'prompt': prompt,
        'model': model,
        'size': ?size,
      },
    );
    return StudioTurn.fromJson(payload['item']! as Map<String, Object?>);
  }

  @override
  Future<StudioTurn> createEditTurn({
    required String conversationId,
    required String clientTaskId,
    required String prompt,
    required String model,
    String? size,
    required List<StudioEditImage> images,
  }) async {
    if (images.isEmpty) {
      throw ArgumentError('createEditTurn requires at least one image');
    }
    final formMap = <String, Object?>{
      'conversation_id': conversationId,
      'client_task_id': clientTaskId,
      'prompt': prompt,
      'model': model,
      if (size != null && size.isNotEmpty) 'size': size,
      'image': [
        for (final image in images)
          MultipartFile.fromBytes(image.bytes, filename: image.filename),
      ],
    };
    final payload = await _client.postMultipart(
      '/api/image-turns/edits',
      formData: FormData.fromMap(formMap, ListFormat.multiCompatible),
    );
    return StudioTurn.fromJson(payload['item']! as Map<String, Object?>);
  }

  @override
  Future<StudioTurn> syncTurn(String turnId) async {
    final payload = await _client.postJson('/api/image-turns/$turnId/sync');
    return StudioTurn.fromJson(payload['item']! as Map<String, Object?>);
  }

  @override
  Future<StudioTurn> retryTurn({
    required String turnId,
    required String clientTaskId,
  }) async {
    final payload = await _client.postJson(
      '/api/image-turns/$turnId/retry',
      body: <String, Object?>{'client_task_id': clientTaskId},
    );
    return StudioTurn.fromJson(payload['item']! as Map<String, Object?>);
  }

  @override
  Future<List<StudioFavorite>> fetchFavorites() async {
    final payload = await _client.getJson('/api/image-favorites');
    return _items(payload).map(StudioFavorite.fromJson).toList();
  }

  @override
  Future<StudioFavorite> favoriteImage({
    required String imagePath,
    String sourceTurnId = '',
  }) async {
    final payload = await _client.postJson(
      '/api/image-favorites',
      body: <String, Object?>{
        'image_path': imagePath,
        'source_turn_id': sourceTurnId,
      },
    );
    return StudioFavorite.fromJson(payload['item']! as Map<String, Object?>);
  }

  @override
  Future<void> deleteFavorite(String favoriteId) async {
    await _client.deleteJson('/api/image-favorites/$favoriteId');
  }

  @override
  Future<List<StudioPromptTemplate>> fetchPromptTemplates() async {
    final payload = await _client.getJson('/api/prompt-templates');
    return _items(payload).map(StudioPromptTemplate.fromJson).toList();
  }

  @override
  Future<StudioPromptTemplate> createPromptTemplate({
    required String name,
    required String category,
    required String content,
  }) async {
    final payload = await _client.postJson(
      '/api/prompt-templates',
      body: <String, Object?>{
        'name': name,
        'category': category,
        'content': content,
      },
    );
    return StudioPromptTemplate.fromJson(
      payload['item']! as Map<String, Object?>,
    );
  }

  @override
  Future<void> deletePromptTemplate(String templateId) async {
    await _client.deleteJson('/api/prompt-templates/$templateId');
  }

  List<Map<String, Object?>> _items(Map<String, Object?> payload) {
    return (payload['items']! as List).cast<Map<String, Object?>>();
  }
}
