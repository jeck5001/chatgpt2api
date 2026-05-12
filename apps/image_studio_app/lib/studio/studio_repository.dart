import '../core/api/api_client.dart';
import 'studio_models.dart';

class StudioRepository {
  const StudioRepository(this._client);

  final ApiClient _client;

  Future<List<StudioProject>> fetchProjects() async {
    final payload = await _client.getJson('/api/projects');
    return _items(payload).map(StudioProject.fromJson).toList();
  }

  Future<StudioProject> createProject(String name) async {
    final payload = await _client.postJson(
      '/api/projects',
      body: <String, Object?>{'name': name},
    );
    return StudioProject.fromJson(payload['item']! as Map<String, Object?>);
  }

  Future<List<StudioConversation>> fetchConversations(String projectId) async {
    final payload = await _client.getJson(
      '/api/image-conversations',
      query: <String, Object?>{'project_id': projectId},
    );
    return _items(payload).map(StudioConversation.fromJson).toList();
  }

  Future<List<StudioTurn>> fetchTurns(String conversationId) async {
    final payload = await _client.getJson(
      '/api/image-turns',
      query: <String, Object?>{'conversation_id': conversationId},
    );
    return _items(payload).map(StudioTurn.fromJson).toList();
  }

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

  Future<StudioTurn> syncTurn(String turnId) async {
    final payload = await _client.postJson('/api/image-turns/$turnId/sync');
    return StudioTurn.fromJson(payload['item']! as Map<String, Object?>);
  }

  List<Map<String, Object?>> _items(Map<String, Object?> payload) {
    return (payload['items']! as List).cast<Map<String, Object?>>();
  }
}
