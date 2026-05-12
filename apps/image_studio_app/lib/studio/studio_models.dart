enum StudioTurnStatus { queued, running, success, error }

enum StudioTurnMode { generate, edit }

class StudioProject {
  const StudioProject({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory StudioProject.fromJson(Map<String, Object?> json) {
    return StudioProject(
      id: json['id'].toString(),
      name: json['name'].toString(),
      ownerId: json['owner_id'].toString(),
      archived: json['archived'] == true,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class StudioConversation {
  const StudioConversation({
    required this.id,
    required this.projectId,
    required this.title,
    required this.mode,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String title;
  final StudioTurnMode mode;
  final DateTime updatedAt;

  factory StudioConversation.fromJson(Map<String, Object?> json) {
    return StudioConversation(
      id: json['id'].toString(),
      projectId: json['project_id'].toString(),
      title: json['title'].toString(),
      mode: json['mode'] == 'edit'
          ? StudioTurnMode.edit
          : StudioTurnMode.generate,
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class StudioResultImage {
  const StudioResultImage({required this.url, required this.path});

  final Uri url;
  final String path;

  factory StudioResultImage.fromJson(Map<String, Object?> json) {
    return StudioResultImage(
      url: Uri.parse(json['url'].toString()),
      path: (json['path'] ?? '').toString(),
    );
  }
}

class StudioTurn {
  const StudioTurn({
    required this.id,
    required this.conversationId,
    required this.clientTaskId,
    required this.taskId,
    required this.mode,
    required this.prompt,
    required this.model,
    required this.size,
    required this.resultImages,
    required this.status,
    required this.error,
    required this.updatedAt,
  });

  final String id;
  final String conversationId;
  final String clientTaskId;
  final String taskId;
  final StudioTurnMode mode;
  final String prompt;
  final String model;
  final String? size;
  final List<StudioResultImage> resultImages;
  final StudioTurnStatus status;
  final String error;
  final DateTime updatedAt;

  bool get isRunning {
    return status == StudioTurnStatus.queued ||
        status == StudioTurnStatus.running;
  }

  factory StudioTurn.fromJson(Map<String, Object?> json) {
    return StudioTurn(
      id: json['id'].toString(),
      conversationId: json['conversation_id'].toString(),
      clientTaskId: json['client_task_id'].toString(),
      taskId: json['task_id'].toString(),
      mode: json['mode'] == 'edit'
          ? StudioTurnMode.edit
          : StudioTurnMode.generate,
      prompt: json['prompt'].toString(),
      model: json['model'].toString(),
      size: json['size']?.toString(),
      resultImages: ((json['result_images'] ?? <Object?>[]) as List)
          .cast<Map<String, Object?>>()
          .map(StudioResultImage.fromJson)
          .toList(),
      status: switch (json['status']) {
        'running' => StudioTurnStatus.running,
        'success' => StudioTurnStatus.success,
        'error' => StudioTurnStatus.error,
        _ => StudioTurnStatus.queued,
      },
      error: (json['error'] ?? '').toString(),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }
}

class StudioFavorite {
  const StudioFavorite({
    required this.id,
    required this.imagePath,
    required this.sourceTurnId,
    required this.createdAt,
  });

  final String id;
  final String imagePath;
  final String sourceTurnId;
  final DateTime createdAt;

  factory StudioFavorite.fromJson(Map<String, Object?> json) {
    return StudioFavorite(
      id: json['id'].toString(),
      imagePath: json['image_path'].toString(),
      sourceTurnId: (json['source_turn_id'] ?? '').toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}
