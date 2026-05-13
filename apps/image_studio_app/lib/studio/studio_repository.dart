import '../core/api/api_client.dart';
import 'studio_models.dart';

abstract interface class StudioRepositoryContract {
  Future<List<StudioProject>> fetchProjects();

  Future<StudioProject> createProject(String name);

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

  Future<StudioTurn> syncTurn(String turnId);

  Future<List<StudioFavorite>> fetchFavorites();

  Future<StudioFavorite> favoriteImage({
    required String imagePath,
    String sourceTurnId = '',
  });

  Future<void> deleteFavorite(String favoriteId);
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
  Future<StudioTurn> syncTurn(String turnId) async {
    final payload = await _client.postJson('/api/image-turns/$turnId/sync');
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

  List<Map<String, Object?>> _items(Map<String, Object?> payload) {
    return (payload['items']! as List).cast<Map<String, Object?>>();
  }
}
