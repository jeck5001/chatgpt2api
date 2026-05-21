import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'studio_models.dart';
import 'studio_preferences.dart';
import 'studio_repository.dart';

class StudioState {
  const StudioState({
    this.projects = const [],
    this.conversations = const [],
    this.activeProject,
    this.activeConversation,
    this.turns = const [],
    this.favorites = const [],
    this.libraryAssets = const [],
    this.recipes = const [],
    this.consistencyProfiles = const [],
    this.activeConsistencyProfileIds = const [],
    this.batchRuns = const [],
    this.templates = const [],
    this.hubRecipes = const [],
    this.preferences = const StudioPreferences(),
    this.promptDraft = '',
    this.submitting = false,
    this.errorMessage,
  });

  final List<StudioProject> projects;
  final List<StudioConversation> conversations;
  final StudioProject? activeProject;
  final StudioConversation? activeConversation;
  final List<StudioTurn> turns;
  final List<StudioFavorite> favorites;
  final List<StudioAsset> libraryAssets;
  final List<StudioRecipe> recipes;
  final List<StudioConsistencyProfile> consistencyProfiles;
  final List<String> activeConsistencyProfileIds;
  final List<StudioBatchRun> batchRuns;
  final List<StudioPromptTemplate> templates;
  final List<StudioRecipe> hubRecipes;
  final StudioPreferences preferences;
  final String promptDraft;
  final bool submitting;
  final String? errorMessage;

  StudioState copyWith({
    List<StudioProject>? projects,
    List<StudioConversation>? conversations,
    StudioProject? activeProject,
    StudioConversation? activeConversation,
    List<StudioTurn>? turns,
    List<StudioFavorite>? favorites,
    List<StudioAsset>? libraryAssets,
    List<StudioRecipe>? recipes,
    List<StudioConsistencyProfile>? consistencyProfiles,
    List<String>? activeConsistencyProfileIds,
    List<StudioBatchRun>? batchRuns,
    List<StudioPromptTemplate>? templates,
    List<StudioRecipe>? hubRecipes,
    StudioPreferences? preferences,
    String? promptDraft,
    bool? submitting,
    String? errorMessage,
    bool clearError = false,
  }) {
    return StudioState(
      projects: projects ?? this.projects,
      conversations: conversations ?? this.conversations,
      activeProject: activeProject ?? this.activeProject,
      activeConversation: activeConversation ?? this.activeConversation,
      turns: turns ?? this.turns,
      favorites: favorites ?? this.favorites,
      libraryAssets: libraryAssets ?? this.libraryAssets,
      recipes: recipes ?? this.recipes,
      consistencyProfiles: consistencyProfiles ?? this.consistencyProfiles,
      activeConsistencyProfileIds:
          activeConsistencyProfileIds ?? this.activeConsistencyProfileIds,
      batchRuns: batchRuns ?? this.batchRuns,
      templates: templates ?? this.templates,
      hubRecipes: hubRecipes ?? this.hubRecipes,
      preferences: preferences ?? this.preferences,
      promptDraft: promptDraft ?? this.promptDraft,
      submitting: submitting ?? this.submitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  List<StudioConsistencyProfile> get activeConsistencyProfiles {
    if (activeConsistencyProfileIds.isEmpty || consistencyProfiles.isEmpty) {
      return const [];
    }
    final byId = <String, StudioConsistencyProfile>{
      for (final profile in consistencyProfiles) profile.id: profile,
    };
    return [
      for (final id in activeConsistencyProfileIds)
        if (byId[id] != null) byId[id]!,
    ];
  }
}

class StudioController extends ChangeNotifier {
  StudioController(
    this._repository, {
    Duration? pollInterval,
    this.imageBaseUrl,
    StudioPreferencesStore? preferencesStore,
  }) : _pollInterval = pollInterval ?? const Duration(seconds: 2),
       _preferencesStore = preferencesStore;

  final StudioRepositoryContract _repository;
  final Duration _pollInterval;
  final Uri? imageBaseUrl;
  final StudioPreferencesStore? _preferencesStore;
  final Uuid _uuid = const Uuid();

  StudioState _state = const StudioState();
  StudioState get state => _state;

  Timer? _pollTimer;
  bool _polling = false;

  Future<void> retryTurn(StudioTurn turn) async {
    if (turn.mode != StudioTurnMode.generate) {
      throw StateError('only generation turns can be retried');
    }
    _state = _state.copyWith(clearError: true);
    try {
      final retried = await _repository.retryTurn(
        turnId: turn.id,
        clientTaskId: _uuid.v4(),
      );
      final replaced = _state.turns
          .map((t) => t.id == retried.id ? retried : t)
          .toList(growable: false);
      _state = _state.copyWith(turns: replaced);
      notifyListeners();
      _ensurePolling();
    } catch (error) {
      _state = _state.copyWith(errorMessage: error.toString());
      notifyListeners();
      rethrow;
    }
  }

  bool get hasRunningTurns {
    return _state.turns.any((turn) => turn.isRunning);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pollTimer = null;
    super.dispose();
  }

  void replaceTurns(List<StudioTurn> turns) {
    _state = _state.copyWith(turns: turns);
    notifyListeners();
  }

  void replaceRecipes(List<StudioRecipe> recipes) {
    _state = _state.copyWith(recipes: recipes);
    notifyListeners();
  }

  void replaceHubRecipes(List<StudioRecipe> recipes) {
    _state = _state.copyWith(hubRecipes: recipes);
    notifyListeners();
  }

  void replaceConsistencyProfiles(List<StudioConsistencyProfile> profiles) {
    _state = _state.copyWith(
      consistencyProfiles: profiles,
      activeConsistencyProfileIds: _retainActiveProfileIds(profiles),
    );
    notifyListeners();
  }

  List<String> _retainActiveProfileIds(
    List<StudioConsistencyProfile> profiles,
  ) {
    if (profiles.isEmpty || _state.activeConsistencyProfileIds.isEmpty) {
      return const [];
    }
    final availableIds = profiles.map((profile) => profile.id).toSet();
    return _state.activeConsistencyProfileIds
        .where(availableIds.contains)
        .toList(growable: false);
  }

  Future<void> loadWorkspace() async {
    StudioPreferences? loadedPreferences;
    if (_preferencesStore != null) {
      try {
        loadedPreferences = await _preferencesStore.read();
      } catch (_) {
        loadedPreferences = null;
      }
    }
    final projects = await _repository.fetchProjects();
    final activeProject = projects.isNotEmpty
        ? projects.first
        : await _repository.createProject('Untitled Project');
    final conversations = await _repository.fetchConversations(
      activeProject.id,
    );
    final activeConversation = conversations.isNotEmpty
        ? conversations.first
        : await _repository.createConversation(
            projectId: activeProject.id,
            title: 'New image session',
          );
    final turns = await _repository.fetchTurns(activeConversation.id);
    List<StudioFavorite> favorites;
    try {
      favorites = await _repository.fetchFavorites();
    } catch (_) {
      favorites = const [];
    }
    List<StudioAsset> libraryAssets;
    try {
      libraryAssets = await _repository.fetchLibraryAssets();
    } catch (_) {
      libraryAssets = const [];
    }
    List<StudioRecipe> recipes;
    try {
      recipes = await _repository.fetchRecipes();
    } catch (_) {
      recipes = const [];
    }
    List<StudioRecipe> hubRecipes;
    try {
      hubRecipes = await _repository.fetchPromptHubRecipes();
    } catch (_) {
      hubRecipes = const [];
    }
    List<StudioConsistencyProfile> consistencyProfiles;
    try {
      consistencyProfiles = await _repository.fetchConsistencyProfiles();
    } catch (_) {
      consistencyProfiles = const [];
    }
    List<StudioPromptTemplate> templates;
    try {
      templates = await _repository.fetchPromptTemplates();
    } catch (_) {
      templates = const [];
    }
    _state = _state.copyWith(
      projects: projects,
      conversations: conversations,
      activeProject: activeProject,
      activeConversation: activeConversation,
      turns: turns,
      favorites: favorites,
      libraryAssets: libraryAssets,
      recipes: recipes,
      consistencyProfiles: consistencyProfiles,
      activeConsistencyProfileIds: _retainActiveProfileIds(consistencyProfiles),
      hubRecipes: hubRecipes,
      templates: templates,
      preferences: loadedPreferences,
    );
    notifyListeners();
    _ensurePolling();
  }

  Future<void> updatePreferences(StudioPreferences preferences) async {
    _state = _state.copyWith(preferences: preferences);
    notifyListeners();
    final store = _preferencesStore;
    if (store == null) return;
    try {
      await store.write(preferences);
    } catch (_) {
      // Best-effort persistence; in-memory state is already updated.
    }
  }

  Future<void> selectConversation(String conversationId) async {
    final conversation = _state.conversations
        .where((item) => item.id == conversationId)
        .firstOrNull;
    if (conversation == null) {
      return;
    }
    final turns = await _repository.fetchTurns(conversation.id);
    _state = _state.copyWith(activeConversation: conversation, turns: turns);
    notifyListeners();
    _ensurePolling();
  }

  Future<void> selectProject(String projectId) async {
    final project = _state.projects
        .where((item) => item.id == projectId)
        .firstOrNull;
    if (project == null) {
      return;
    }
    final conversations = await _repository.fetchConversations(project.id);
    final activeConversation = conversations.isNotEmpty
        ? conversations.first
        : null;
    final turns = activeConversation == null
        ? const <StudioTurn>[]
        : await _repository.fetchTurns(activeConversation.id);
    _state = _state.copyWith(
      activeProject: project,
      conversations: conversations,
      activeConversation: activeConversation,
      turns: turns,
    );
    notifyListeners();
    _ensurePolling();
  }

  Future<StudioConversation> createNewConversation({
    required String title,
    StudioTurnMode mode = StudioTurnMode.generate,
  }) async {
    final project = _state.activeProject;
    if (project == null) {
      throw StateError('No active project to create a conversation under');
    }
    final conversation = await _repository.createConversation(
      projectId: project.id,
      title: title.isEmpty ? '新会话' : title,
      mode: switch (mode) {
        StudioTurnMode.edit => 'edit',
        StudioTurnMode.inpaint => 'inpaint',
        StudioTurnMode.generate => 'generate',
      },
    );
    _state = _state.copyWith(
      conversations: [conversation, ..._state.conversations],
      activeConversation: conversation,
      turns: const <StudioTurn>[],
    );
    notifyListeners();
    return conversation;
  }

  Future<StudioProject> createNewProject(String name) async {
    final project = await _repository.createProject(
      name.isEmpty ? '新项目' : name,
    );
    _state = _state.copyWith(
      projects: [project, ..._state.projects],
      activeProject: project,
      conversations: const <StudioConversation>[],
      activeConversation: null,
      turns: const <StudioTurn>[],
    );
    notifyListeners();
    return project;
  }

  Future<StudioProject> renameProject({
    required String projectId,
    required String name,
  }) async {
    final updated = await _repository.updateProject(
      projectId: projectId,
      name: name,
    );
    _replaceProject(updated);
    return updated;
  }

  Future<StudioProject> archiveProject({
    required String projectId,
    required bool archived,
  }) async {
    final updated = await _repository.updateProject(
      projectId: projectId,
      archived: archived,
    );
    _replaceProject(updated);
    return updated;
  }

  void _replaceProject(StudioProject updated) {
    final projects = _state.projects
        .map((p) => p.id == updated.id ? updated : p)
        .toList(growable: false);
    final activeProject = _state.activeProject?.id == updated.id
        ? updated
        : _state.activeProject;
    _state = _state.copyWith(projects: projects, activeProject: activeProject);
    notifyListeners();
  }

  Future<void> removeFavorite(StudioFavorite favorite) async {
    await _repository.deleteFavorite(favorite.id);
    _state = _state.copyWith(
      favorites: _state.favorites
          .where((fav) => fav.id != favorite.id)
          .toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> refreshLibraryAssets() async {
    final assets = await _repository.fetchLibraryAssets();
    _state = _state.copyWith(libraryAssets: assets);
    notifyListeners();
  }

  Future<void> deleteLibraryAssets(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return;
    final selected = imagePaths.toSet();
    await _repository.deleteImages(imagePaths);
    _state = _state.copyWith(
      libraryAssets: _state.libraryAssets
          .where((asset) => !selected.contains(asset.path))
          .toList(growable: false),
      favorites: _state.favorites
          .where((favorite) => !selected.contains(favorite.imagePath))
          .toList(growable: false),
    );
    notifyListeners();
  }

  Future<Uint8List> downloadLibraryAssets(List<String> imagePaths) {
    if (imagePaths.isEmpty) {
      return Future<Uint8List>.value(Uint8List(0));
    }
    return _repository.downloadImagesZip(imagePaths);
  }

  Future<void> tagLibraryAssets({
    required List<String> imagePaths,
    required List<String> tags,
  }) async {
    if (imagePaths.isEmpty) return;
    final updatedByPath = <String, List<String>>{};
    for (final path in imagePaths) {
      updatedByPath[path] = await _repository.updateImageTags(
        imagePath: path,
        tags: tags,
      );
    }
    _state = _state.copyWith(
      libraryAssets: _state.libraryAssets
          .map((asset) {
            final updatedTags = updatedByPath[asset.path];
            return updatedTags == null
                ? asset
                : asset.copyWith(tags: updatedTags);
          })
          .toList(growable: false),
    );
    notifyListeners();
  }

  Future<StudioRecipe> saveRecipeFromAsset(
    StudioAsset asset, {
    String name = '',
  }) async {
    final prompt = [asset.prompt, asset.revisedPrompt, asset.name]
        .map((value) => value.trim())
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (prompt.isEmpty) {
      throw StateError('这张图没有可复用的 prompt');
    }
    final fallbackName =
        [asset.projectName, asset.prompt, asset.revisedPrompt, asset.name]
            .map((value) => value.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => '未命名配方');
    final created = await _repository.createRecipe(
      name: name.trim().isNotEmpty ? name.trim() : fallbackName,
      prompt: prompt,
      model: asset.model.trim().isNotEmpty ? asset.model.trim() : 'gpt-image-2',
      size: asset.sizeLabel.trim().isEmpty ? null : asset.sizeLabel.trim(),
      sourceImagePath: asset.path,
      sourceTurnId: asset.turnId,
      projectId: asset.projectId,
      tags: asset.tags,
    );
    _state = _state.copyWith(
      recipes: [
        created,
        ..._state.recipes.where((recipe) => recipe.id != created.id),
      ],
    );
    notifyListeners();
    return created;
  }

  Future<void> deleteRecipe(String recipeId) async {
    await _repository.deleteRecipe(recipeId);
    _state = _state.copyWith(
      recipes: _state.recipes
          .where((recipe) => recipe.id != recipeId)
          .toList(growable: false),
      hubRecipes: _state.hubRecipes
          .where((recipe) => recipe.id != recipeId)
          .toList(growable: false),
    );
    notifyListeners();
  }

  Future<StudioRecipe> toggleRecipeSharing(StudioRecipe recipe) async {
    final updated = await _repository.updateRecipeSharing(
      recipeId: recipe.id,
      shared: !recipe.shared,
    );
    _upsertRecipe(updated);
    return updated;
  }

  Future<StudioRecipe> clonePromptHubRecipe(StudioRecipe recipe) async {
    final cloned = await _repository.clonePromptHubRecipe(recipe.id);
    _state = _state.copyWith(
      recipes: [
        cloned,
        ..._state.recipes.where((item) => item.id != cloned.id),
      ],
    );
    notifyListeners();
    return cloned;
  }

  Future<StudioConsistencyProfile> saveConsistencyProfile({
    required String name,
    required StudioConsistencyProfileKind kind,
    required String guidance,
    String referenceImagePath = '',
    List<String> tags = const [],
  }) async {
    final cleaned = guidance.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError('saveConsistencyProfile requires guidance');
    }
    final created = await _repository.createConsistencyProfile(
      name: name,
      kind: kind,
      guidance: cleaned,
      referenceImagePath: referenceImagePath,
      tags: tags,
    );
    _state = _state.copyWith(
      consistencyProfiles: <StudioConsistencyProfile>[
        created,
        ..._state.consistencyProfiles.where(
          (profile) => profile.id != created.id,
        ),
      ],
    );
    notifyListeners();
    return created;
  }

  Future<StudioConsistencyProfile> saveCharacterCard({
    required String name,
    required String identity,
    String lockedTraits = '',
    String avoidChanges = '',
    String referenceImagePath = '',
    List<String> tags = const [],
  }) {
    return saveConsistencyProfile(
      name: name,
      kind: StudioConsistencyProfileKind.character,
      guidance: _buildCharacterCardGuidance(
        identity: identity,
        lockedTraits: lockedTraits,
        avoidChanges: avoidChanges,
      ),
      referenceImagePath: referenceImagePath,
      tags: _uniqueTags(['角色', '角色卡', ...tags]),
    );
  }

  String _buildCharacterCardGuidance({
    required String identity,
    required String lockedTraits,
    required String avoidChanges,
  }) {
    final cleanedIdentity = identity.trim();
    if (cleanedIdentity.isEmpty) {
      throw ArgumentError('saveCharacterCard requires identity');
    }
    final cleanedTraits = lockedTraits.trim();
    final cleanedAvoid = avoidChanges.trim();
    return <String>[
      'Character identity lock',
      'Core identity:',
      cleanedIdentity,
      if (cleanedTraits.isNotEmpty) ...['Fixed traits:', cleanedTraits],
      'Do not change:',
      cleanedAvoid.isEmpty
          ? 'Do not change face, age, body proportions, hair, outfit identity, signature accessories, or core color palette unless explicitly requested.'
          : cleanedAvoid,
      'Continuity rule:',
      'Keep the same recognizable character identity across every generation. Only vary the scene, pose, expression, camera, lighting, or action requested by the user.',
    ].join('\n');
  }

  List<String> _uniqueTags(List<String> tags) {
    return [
      ...{
        for (final tag in tags.map((tag) => tag.trim()))
          if (tag.isNotEmpty) tag,
      },
    ];
  }

  Future<void> deleteConsistencyProfile(
    StudioConsistencyProfile profile,
  ) async {
    await _repository.deleteConsistencyProfile(profile.id);
    _state = _state.copyWith(
      consistencyProfiles: _state.consistencyProfiles
          .where((item) => item.id != profile.id)
          .toList(growable: false),
      activeConsistencyProfileIds: _state.activeConsistencyProfileIds
          .where((id) => id != profile.id)
          .toList(growable: false),
    );
    notifyListeners();
  }

  void toggleConsistencyProfile(StudioConsistencyProfile profile) {
    final ids = [..._state.activeConsistencyProfileIds];
    if (ids.contains(profile.id)) {
      ids.remove(profile.id);
    } else {
      ids.add(profile.id);
    }
    _state = _state.copyWith(
      activeConsistencyProfileIds: ids,
      clearError: true,
    );
    notifyListeners();
  }

  String applyConsistencyProfile(
    StudioConsistencyProfile profile, {
    required String currentPrompt,
  }) {
    final blocks = <String>[
      _consistencyPromptBlock(profile),
      if (currentPrompt.trim().isNotEmpty)
        'User prompt:\n${currentPrompt.trim()}',
    ];
    final prompt = blocks
        .where((block) => block.trim().isNotEmpty)
        .join('\n\n');
    _state = _state.copyWith(promptDraft: prompt, clearError: true);
    notifyListeners();
    return prompt;
  }

  String _applyActiveConsistencyProfiles(String prompt) {
    final activeProfiles = _state.activeConsistencyProfiles;
    if (activeProfiles.isEmpty) return prompt;
    final blocks = <String>[
      for (final profile in activeProfiles) _consistencyPromptBlock(profile),
      if (prompt.trim().isNotEmpty) 'User prompt:\n${prompt.trim()}',
    ];
    return blocks.where((block) => block.trim().isNotEmpty).join('\n\n');
  }

  String _consistencyPromptBlock(StudioConsistencyProfile profile) {
    return <String>[
      'Consistency profile: ${profile.displayName} (${profile.kind.wireName})',
      if (profile.kind == StudioConsistencyProfileKind.character)
        'Identity lock: preserve the same character across all generated images.',
      profile.guidance.trim(),
      if (profile.kind == StudioConsistencyProfileKind.character)
        'Do not alter fixed identity traits. Only change the scene, pose, expression, camera, lighting, outfit details, or action when explicitly requested.',
      if (profile.referenceImagePath.trim().isNotEmpty)
        'Reference image path: ${profile.referenceImagePath.trim()}',
    ].where((block) => block.trim().isNotEmpty).join('\n');
  }

  void _upsertRecipe(StudioRecipe updated) {
    final recipes = _state.recipes
        .map((recipe) => recipe.id == updated.id ? updated : recipe)
        .toList(growable: false);
    final hubRecipes = updated.shared
        ? [
            updated,
            ..._state.hubRecipes.where((recipe) => recipe.id != updated.id),
          ]
        : _state.hubRecipes
              .where((recipe) => recipe.id != updated.id)
              .toList(growable: false);
    _state = _state.copyWith(recipes: recipes, hubRecipes: hubRecipes);
    notifyListeners();
  }

  Future<List<StudioTurn>> submitRecipeBatch({
    required String conversationId,
    required StudioRecipe recipe,
    required List<String> inputs,
  }) async {
    final cleanedInputs = inputs
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (cleanedInputs.isEmpty) {
      throw ArgumentError('submitRecipeBatch requires at least one input');
    }
    final model = recipe.model.trim().isEmpty
        ? 'gpt-image-2'
        : recipe.model.trim();
    final size = (recipe.size ?? '').trim().isEmpty
        ? null
        : recipe.size!.trim();
    _state = _state.copyWith(
      promptDraft: recipe.prompt,
      submitting: true,
      clearError: true,
    );
    notifyListeners();
    final created = <StudioTurn>[];
    try {
      for (final input in cleanedInputs) {
        final turn = await _repository.createGenerationTurn(
          conversationId: conversationId,
          clientTaskId: _uuid.v4(),
          prompt: _applyActiveConsistencyProfiles(
            _expandRecipePrompt(recipe.prompt, input),
          ),
          model: model,
          size: size,
        );
        created.add(turn);
      }
      _state = _state.copyWith(
        turns: [...created.reversed, ..._state.turns],
        batchRuns: [
          _buildBatchRun(
            conversationId: conversationId,
            recipe: recipe,
            turns: created,
            totalCount: cleanedInputs.length,
          ),
          ..._state.batchRuns,
        ],
        promptDraft: '',
        submitting: false,
      );
      notifyListeners();
      for (final turn in created) {
        if (turn.status == StudioTurnStatus.success) {
          await _maybeAutoFavorite(turn);
        }
      }
      _ensurePolling();
      return created;
    } catch (error) {
      if (created.isNotEmpty) {
        _state = _state.copyWith(
          turns: [...created.reversed, ..._state.turns],
          batchRuns: [
            _buildBatchRun(
              conversationId: conversationId,
              recipe: recipe,
              turns: created,
              totalCount: created.length,
            ),
            ..._state.batchRuns,
          ],
          submitting: false,
          errorMessage: error.toString(),
        );
      } else {
        _state = _state.copyWith(
          submitting: false,
          errorMessage: error.toString(),
        );
      }
      notifyListeners();
      rethrow;
    }
  }

  StudioBatchRun _buildBatchRun({
    required String conversationId,
    required StudioRecipe recipe,
    required List<StudioTurn> turns,
    required int totalCount,
  }) {
    final name = recipe.name.trim().isEmpty ? '未命名配方' : recipe.name.trim();
    return StudioBatchRun(
      id: _uuid.v4(),
      conversationId: conversationId,
      recipeId: recipe.id,
      recipeName: name,
      createdAt: DateTime.now(),
      turnIds: turns.map((turn) => turn.id).toList(growable: false),
      totalCount: totalCount,
    );
  }

  Future<int> retryFailedBatch(String batchRunId) async {
    final batch = _state.batchRuns
        .where((run) => run.id == batchRunId)
        .firstOrNull;
    if (batch == null) return 0;
    final batchTurnIds = batch.turnIds.toSet();
    final failedTurns = _state.turns
        .where(
          (turn) =>
              batchTurnIds.contains(turn.id) &&
              turn.status == StudioTurnStatus.error &&
              turn.mode == StudioTurnMode.generate,
        )
        .toList(growable: false);
    for (final turn in failedTurns) {
      await retryTurn(turn);
    }
    return failedTurns.length;
  }

  String _expandRecipePrompt(String prompt, String input) {
    final base = prompt.trim();
    final value = input.trim();
    if (base.isEmpty) return value;
    var expanded = base;
    var replaced = false;
    for (final placeholder in const [
      '{{item}}',
      '{item}',
      '{{input}}',
      '{input}',
      '{{主题}}',
      '{主题}',
    ]) {
      if (expanded.contains(placeholder)) {
        expanded = expanded.replaceAll(placeholder, value);
        replaced = true;
      }
    }
    return replaced ? expanded : '$base\n主题：$value';
  }

  Future<void> toggleFavoriteAsset(StudioAsset asset) async {
    final existing = _state.favorites
        .where((favorite) => favorite.imagePath == asset.path)
        .firstOrNull;
    if (existing != null) {
      await removeFavorite(existing);
      return;
    }
    final favorite = await _repository.favoriteImage(
      imagePath: asset.path,
      sourceTurnId: asset.turnId,
    );
    _state = _state.copyWith(
      favorites: <StudioFavorite>[..._state.favorites, favorite],
    );
    notifyListeners();
  }

  Future<void> deleteConversation(
    String conversationId, {
    bool purge = false,
  }) async {
    await _repository.deleteConversation(conversationId, purge: purge);
    final remaining = _state.conversations
        .where((c) => c.id != conversationId)
        .toList(growable: false);
    final wasActive = _state.activeConversation?.id == conversationId;
    if (!wasActive) {
      _state = _state.copyWith(
        conversations: remaining,
        batchRuns: _state.batchRuns
            .where((run) => run.conversationId != conversationId)
            .toList(growable: false),
      );
      notifyListeners();
      return;
    }
    final nextActive = remaining.isNotEmpty ? remaining.first : null;
    final nextTurns = nextActive == null
        ? const <StudioTurn>[]
        : await _repository.fetchTurns(nextActive.id);
    _state = StudioState(
      projects: _state.projects,
      conversations: remaining,
      activeProject: _state.activeProject,
      activeConversation: nextActive,
      turns: nextTurns,
      favorites: _state.favorites,
      libraryAssets: _state.libraryAssets,
      recipes: _state.recipes,
      consistencyProfiles: _state.consistencyProfiles,
      activeConsistencyProfileIds: _state.activeConsistencyProfileIds,
      batchRuns: _state.batchRuns
          .where((run) => run.conversationId != conversationId)
          .toList(growable: false),
      templates: _state.templates,
      hubRecipes: _state.hubRecipes,
      preferences: _state.preferences,
      promptDraft: _state.promptDraft,
      submitting: _state.submitting,
      errorMessage: _state.errorMessage,
    );
    notifyListeners();
    _ensurePolling();
  }

  Future<void> deleteTurn(String turnId, {bool purge = false}) async {
    await _repository.deleteTurn(turnId, purge: purge);
    final batchRuns = _state.batchRuns
        .map((run) {
          if (!run.turnIds.contains(turnId)) return run;
          final turnIds = run.turnIds
              .where((id) => id != turnId)
              .toList(growable: false);
          return run.copyWith(turnIds: turnIds, totalCount: turnIds.length);
        })
        .where((run) => run.turnIds.isNotEmpty)
        .toList(growable: false);
    _state = _state.copyWith(
      turns: _state.turns
          .where((turn) => turn.id != turnId)
          .toList(growable: false),
      batchRuns: batchRuns,
    );
    notifyListeners();
  }

  Future<StudioPromptTemplate> savePromptTemplate({
    required String name,
    required String content,
    String category = '',
  }) async {
    final created = await _repository.createPromptTemplate(
      name: name,
      category: category,
      content: content,
    );
    _state = _state.copyWith(
      templates: <StudioPromptTemplate>[..._state.templates, created],
    );
    notifyListeners();
    return created;
  }

  Future<void> deletePromptTemplate(String templateId) async {
    await _repository.deletePromptTemplate(templateId);
    _state = _state.copyWith(
      templates: _state.templates
          .where((t) => t.id != templateId)
          .toList(growable: false),
    );
    notifyListeners();
  }

  Future<String> draftPromptFromImage({
    required List<StudioEditImage> images,
  }) async {
    if (images.isEmpty) {
      throw ArgumentError('draftPromptFromImage requires at least one image');
    }
    _state = _state.copyWith(clearError: true);
    notifyListeners();
    try {
      final draft = await _repository.draftPromptFromImage(images: images);
      _state = _state.copyWith(promptDraft: draft);
      notifyListeners();
      return draft;
    } catch (error) {
      _state = _state.copyWith(errorMessage: error.toString());
      notifyListeners();
      rethrow;
    }
  }

  Future<String> optimizePrompt(String prompt) async {
    final cleaned = prompt.trim();
    if (cleaned.isEmpty) {
      throw ArgumentError('optimizePrompt requires a prompt');
    }
    _state = _state.copyWith(promptDraft: cleaned, clearError: true);
    notifyListeners();
    try {
      final optimized = await _repository.optimizePrompt(cleaned);
      _state = _state.copyWith(promptDraft: optimized);
      notifyListeners();
      return optimized;
    } catch (error) {
      _state = _state.copyWith(errorMessage: error.toString());
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitGeneration({
    required String conversationId,
    required String prompt,
    String model = 'gpt-image-2',
    String? size = '1024x1024',
    int count = 1,
  }) async {
    final n = count < 1 ? 1 : count;
    _state = _state.copyWith(
      promptDraft: prompt,
      submitting: true,
      clearError: true,
    );
    notifyListeners();
    final created = <StudioTurn>[];
    try {
      final submittedPrompt = _applyActiveConsistencyProfiles(prompt);
      for (var i = 0; i < n; i++) {
        final turn = await _repository.createGenerationTurn(
          conversationId: conversationId,
          clientTaskId: _uuid.v4(),
          prompt: submittedPrompt,
          model: model,
          size: size,
        );
        created.add(turn);
      }
      _state = _state.copyWith(
        turns: [...created.reversed, ..._state.turns],
        promptDraft: '',
        submitting: false,
      );
      notifyListeners();
      for (final turn in created) {
        if (turn.status == StudioTurnStatus.success) {
          await _maybeAutoFavorite(turn);
        }
      }
      _ensurePolling();
    } catch (error) {
      // Keep any partial successes so the user can see what landed.
      if (created.isNotEmpty) {
        _state = _state.copyWith(
          turns: [...created.reversed, ..._state.turns],
          submitting: false,
          errorMessage: error.toString(),
        );
      } else {
        _state = _state.copyWith(
          submitting: false,
          errorMessage: error.toString(),
        );
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitEdit({
    required String conversationId,
    required String prompt,
    required List<StudioEditImage> images,
    String model = 'gpt-image-2',
    String? size,
  }) async {
    if (images.isEmpty) {
      throw ArgumentError('submitEdit requires at least one reference image');
    }
    _state = _state.copyWith(
      promptDraft: prompt,
      submitting: true,
      clearError: true,
    );
    notifyListeners();
    try {
      final submittedPrompt = _applyActiveConsistencyProfiles(prompt);
      final turn = await _repository.createEditTurn(
        conversationId: conversationId,
        clientTaskId: _uuid.v4(),
        prompt: submittedPrompt,
        model: model,
        size: size,
        images: images,
      );
      _state = _state.copyWith(
        turns: [turn, ..._state.turns],
        promptDraft: '',
        submitting: false,
      );
      notifyListeners();
      if (turn.status == StudioTurnStatus.success) {
        await _maybeAutoFavorite(turn);
      }
      _ensurePolling();
    } catch (error) {
      _state = _state.copyWith(
        submitting: false,
        errorMessage: error.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitInpaint({
    required String conversationId,
    required String prompt,
    required StudioEditImage image,
    required StudioEditImage mask,
    String model = 'gpt-image-2',
    String? size,
  }) async {
    _state = _state.copyWith(
      promptDraft: prompt,
      submitting: true,
      clearError: true,
    );
    notifyListeners();
    try {
      final submittedPrompt = _applyActiveConsistencyProfiles(prompt);
      final turn = await _repository.createInpaintTurn(
        conversationId: conversationId,
        clientTaskId: _uuid.v4(),
        prompt: submittedPrompt,
        model: model,
        size: size,
        image: image,
        mask: mask,
      );
      _state = _state.copyWith(
        turns: [turn, ..._state.turns],
        promptDraft: '',
        submitting: false,
      );
      notifyListeners();
      if (turn.status == StudioTurnStatus.success) {
        await _maybeAutoFavorite(turn);
      }
      _ensurePolling();
    } catch (error) {
      _state = _state.copyWith(
        submitting: false,
        errorMessage: error.toString(),
      );
      notifyListeners();
      rethrow;
    }
  }

  Future<void> pollRunningTurnsOnce() async {
    if (_polling) return;
    _polling = true;
    try {
      final source = _state.turns;
      final updated = <StudioTurn>[];
      final settled = <StudioTurn>[];
      var changed = false;
      for (final turn in source) {
        if (!turn.isRunning) {
          updated.add(turn);
          continue;
        }
        try {
          final synced = await _repository.syncTurn(turn.id);
          updated.add(synced);
          if (synced.status != turn.status ||
              synced.resultImages.length != turn.resultImages.length ||
              synced.error != turn.error) {
            changed = true;
          }
          if (turn.isRunning &&
              synced.status == StudioTurnStatus.success &&
              synced.resultImages.isNotEmpty) {
            settled.add(synced);
          }
        } catch (_) {
          // Per-turn error: keep the previous snapshot so the rest of
          // the list still gets polled. The next tick will retry.
          updated.add(turn);
        }
      }
      if (changed || updated.length != source.length) {
        _state = _state.copyWith(turns: updated);
        notifyListeners();
      }
      for (final turn in settled) {
        await _maybeAutoFavorite(turn);
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _maybeAutoFavorite(StudioTurn turn) async {
    if (!_state.preferences.autoFavorite) return;
    for (final image in turn.resultImages) {
      if (image.path.isEmpty) continue;
      if (_state.favorites.any((fav) => fav.imagePath == image.path)) {
        continue;
      }
      try {
        final fav = await _repository.favoriteImage(
          imagePath: image.path,
          sourceTurnId: turn.id,
        );
        _state = _state.copyWith(
          favorites: <StudioFavorite>[..._state.favorites, fav],
        );
        notifyListeners();
      } catch (_) {
        // Best-effort — auto-favorite must never block other work.
      }
    }
  }

  bool isFavoriteImage(StudioResultImage image) {
    if (image.path.isEmpty) return false;
    return _state.favorites.any((fav) => fav.imagePath == image.path);
  }

  Future<void> toggleFavoriteImage({
    required StudioResultImage image,
    String sourceTurnId = '',
  }) async {
    if (image.path.isEmpty) return;
    final existing = _state.favorites
        .where((fav) => fav.imagePath == image.path)
        .firstOrNull;
    if (existing != null) {
      await _repository.deleteFavorite(existing.id);
      _state = _state.copyWith(
        favorites: _state.favorites
            .where((fav) => fav.id != existing.id)
            .toList(growable: false),
      );
    } else {
      final fav = await _repository.favoriteImage(
        imagePath: image.path,
        sourceTurnId: sourceTurnId,
      );
      _state = _state.copyWith(
        favorites: <StudioFavorite>[..._state.favorites, fav],
      );
    }
    notifyListeners();
  }

  void _ensurePolling() {
    if (_pollTimer != null) return;
    if (!hasRunningTurns) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      try {
        await pollRunningTurnsOnce();
      } catch (_) {
        // Swallow transient poll errors — next tick will retry.
      }
      if (!hasRunningTurns) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    });
  }
}
