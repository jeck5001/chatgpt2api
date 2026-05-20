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

class StudioBatchRun {
  const StudioBatchRun({
    required this.id,
    required this.conversationId,
    required this.recipeId,
    required this.recipeName,
    required this.createdAt,
    required this.turnIds,
    required this.totalCount,
  });

  final String id;
  final String conversationId;
  final String recipeId;
  final String recipeName;
  final DateTime createdAt;
  final List<String> turnIds;
  final int totalCount;

  StudioBatchRun copyWith({List<String>? turnIds, int? totalCount}) {
    return StudioBatchRun(
      id: id,
      conversationId: conversationId,
      recipeId: recipeId,
      recipeName: recipeName,
      createdAt: createdAt,
      turnIds: turnIds ?? this.turnIds,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  StudioBatchProgress progressFor(List<StudioTurn> turns) {
    final byId = {for (final turn in turns) turn.id: turn};
    var running = 0;
    var success = 0;
    var failed = 0;
    for (final id in turnIds) {
      final turn = byId[id];
      if (turn == null) continue;
      switch (turn.status) {
        case StudioTurnStatus.queued:
        case StudioTurnStatus.running:
          running += 1;
        case StudioTurnStatus.success:
          success += 1;
        case StudioTurnStatus.error:
          failed += 1;
      }
    }
    return StudioBatchProgress(
      total: totalCount,
      running: running,
      success: success,
      failed: failed,
    );
  }
}

class StudioBatchProgress {
  const StudioBatchProgress({
    required this.total,
    required this.running,
    required this.success,
    required this.failed,
  });

  final int total;
  final int running;
  final int success;
  final int failed;

  int get completed => success;

  int get pending {
    final missing = total - running - success - failed;
    return missing < 0 ? 0 : missing;
  }

  bool get hasFailures => failed > 0;
}

class StudioAsset {
  const StudioAsset({
    required this.path,
    required this.name,
    required this.date,
    required this.sizeBytes,
    required this.createdAt,
    required this.url,
    required this.thumbnailUrl,
    this.tags = const [],
    this.width,
    this.height,
    this.prompt = '',
    this.revisedPrompt = '',
    this.model = '',
    this.projectId = '',
    this.projectName = '',
    this.conversationId = '',
    this.conversationTitle = '',
    this.turnId = '',
    this.mode = '',
    this.sizeLabel = '',
  });

  final String path;
  final String name;
  final String date;
  final int sizeBytes;
  final DateTime createdAt;
  final Uri url;
  final Uri thumbnailUrl;
  final List<String> tags;
  final int? width;
  final int? height;
  final String prompt;
  final String revisedPrompt;
  final String model;
  final String projectId;
  final String projectName;
  final String conversationId;
  final String conversationTitle;
  final String turnId;
  final String mode;
  final String sizeLabel;

  String get displayTitle {
    if (prompt.isNotEmpty) return prompt;
    if (revisedPrompt.isNotEmpty) return revisedPrompt;
    return name.isNotEmpty ? name : path;
  }

  String get searchText {
    return [
      path,
      name,
      date,
      prompt,
      revisedPrompt,
      model,
      projectName,
      conversationTitle,
      mode,
      sizeLabel,
      ...tags,
    ].where((value) => value.trim().isNotEmpty).join(' ').toLowerCase();
  }

  double get aspectRatio {
    final w = width;
    final h = height;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return 1;
    }
    return w / h;
  }

  StudioAsset copyWith({List<String>? tags}) {
    return StudioAsset(
      path: path,
      name: name,
      date: date,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      url: url,
      thumbnailUrl: thumbnailUrl,
      tags: tags ?? this.tags,
      width: width,
      height: height,
      prompt: prompt,
      revisedPrompt: revisedPrompt,
      model: model,
      projectId: projectId,
      projectName: projectName,
      conversationId: conversationId,
      conversationTitle: conversationTitle,
      turnId: turnId,
      mode: mode,
      sizeLabel: sizeLabel,
    );
  }

  factory StudioAsset.fromJson(Map<String, Object?> json) {
    return StudioAsset(
      path: (json['path'] ?? json['rel'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      sizeBytes: _intValue(json['size']),
      createdAt: _dateTimeValue(json['created_at']),
      url: Uri.parse((json['url'] ?? '').toString()),
      thumbnailUrl: Uri.parse(
        (json['thumbnail_url'] ?? json['url'] ?? '').toString(),
      ),
      tags: ((json['tags'] ?? <Object?>[]) as List)
          .map((tag) => tag.toString())
          .where((tag) => tag.trim().isNotEmpty)
          .toList(growable: false),
      width: json['width'] == null ? null : _intValue(json['width']),
      height: json['height'] == null ? null : _intValue(json['height']),
      prompt: (json['prompt'] ?? '').toString(),
      revisedPrompt: (json['revised_prompt'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      projectId: (json['project_id'] ?? '').toString(),
      projectName: (json['project_name'] ?? '').toString(),
      conversationId: (json['conversation_id'] ?? '').toString(),
      conversationTitle: (json['conversation_title'] ?? '').toString(),
      turnId: (json['turn_id'] ?? '').toString(),
      mode: (json['mode'] ?? '').toString(),
      sizeLabel: (json['size_label'] ?? '').toString(),
    );
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static DateTime _dateTimeValue(Object? value) {
    final raw = (value ?? '').toString().trim();
    if (raw.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.tryParse(raw) ??
        DateTime.tryParse(raw.replaceFirst(' ', 'T')) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class StudioRecipe {
  const StudioRecipe({
    required this.id,
    required this.name,
    required this.prompt,
    required this.model,
    required this.size,
    required this.sourceImagePath,
    required this.sourceTurnId,
    required this.projectId,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String prompt;
  final String model;
  final String? size;
  final String sourceImagePath;
  final String sourceTurnId;
  final String projectId;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName {
    if (name.trim().isNotEmpty) return name;
    return prompt.length > 24 ? '${prompt.substring(0, 24)}…' : prompt;
  }

  factory StudioRecipe.fromJson(Map<String, Object?> json) {
    return StudioRecipe(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      model: (json['model'] ?? 'gpt-image-2').toString(),
      size: (json['size'] ?? '').toString().trim().isEmpty
          ? null
          : json['size'].toString(),
      sourceImagePath: (json['source_image_path'] ?? '').toString(),
      sourceTurnId: (json['source_turn_id'] ?? '').toString(),
      projectId: (json['project_id'] ?? '').toString(),
      tags: ((json['tags'] ?? <Object?>[]) as List)
          .map((tag) => tag.toString())
          .where((tag) => tag.trim().isNotEmpty)
          .toList(growable: false),
      createdAt: StudioAsset._dateTimeValue(json['created_at']),
      updatedAt: StudioAsset._dateTimeValue(json['updated_at']),
    );
  }
}

class StudioStyleGuide {
  const StudioStyleGuide({
    required this.id,
    required this.name,
    required this.guide,
    required this.referenceImagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String guide;
  final String referenceImagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName {
    final cleanedName = name.trim();
    if (cleanedName.isNotEmpty) return cleanedName;
    return guide.length > 24 ? '${guide.substring(0, 24)}…' : guide;
  }

  factory StudioStyleGuide.fromJson(Map<String, Object?> json) {
    return StudioStyleGuide(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      guide: (json['guide'] ?? '').toString(),
      referenceImagePath: (json['reference_image_path'] ?? '').toString(),
      createdAt: StudioAsset._dateTimeValue(json['created_at']),
      updatedAt: StudioAsset._dateTimeValue(json['updated_at']),
    );
  }
}

class StudioFavorite {
  const StudioFavorite({
    required this.id,
    required this.imagePath,
    required this.sourceTurnId,
    required this.createdAt,
    this.prompt = '',
  });

  final String id;
  final String imagePath;
  final String sourceTurnId;
  final DateTime createdAt;
  final String prompt;

  factory StudioFavorite.fromJson(Map<String, Object?> json) {
    return StudioFavorite(
      id: json['id'].toString(),
      imagePath: json['image_path'].toString(),
      sourceTurnId: (json['source_turn_id'] ?? '').toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
      prompt: (json['prompt'] ?? '').toString(),
    );
  }
}

class StudioPromptTemplate {
  const StudioPromptTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.content,
    required this.builtin,
    required this.ownerId,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String category;
  final String content;
  final bool builtin;
  final String ownerId;
  final DateTime updatedAt;

  factory StudioPromptTemplate.fromJson(Map<String, Object?> json) {
    return StudioPromptTemplate(
      id: json['id'].toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      builtin: json['builtin'] == true,
      ownerId: (json['owner_id'] ?? '').toString(),
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
