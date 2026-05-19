import 'package:flutter_test/flutter_test.dart';
import 'package:image_studio_app/studio/studio_models.dart';

void main() {
  test('parses project response', () {
    final project = StudioProject.fromJson(<String, Object?>{
      'id': 'project-1',
      'name': 'Campaign',
      'owner_id': 'admin',
      'archived': false,
      'created_at': '2026-05-12T00:00:00Z',
      'updated_at': '2026-05-12T00:00:00Z',
    });

    expect(project.id, 'project-1');
    expect(project.name, 'Campaign');
    expect(project.archived, isFalse);
  });

  test('parses successful turn with result images', () {
    final turn = StudioTurn.fromJson(<String, Object?>{
      'id': 'turn-1',
      'conversation_id': 'conversation-1',
      'owner_id': 'admin',
      'client_task_id': 'task-1',
      'task_id': 'task-1',
      'mode': 'generate',
      'prompt': 'cat',
      'model': 'gpt-image-2',
      'size': '1024x1024',
      'reference_images': <Object?>[],
      'result_images': <Object?>[
        <String, Object?>{
          'url': 'http://localhost:8000/images/cat.png',
          'path': '2026/05/cat.png',
        },
      ],
      'status': 'success',
      'error': '',
      'created_at': '2026-05-12T00:00:00Z',
      'updated_at': '2026-05-12T00:00:00Z',
    });

    expect(turn.status, StudioTurnStatus.success);
    expect(
      turn.resultImages.single.url.toString(),
      'http://localhost:8000/images/cat.png',
    );
  });

  test('parses library asset response with searchable studio metadata', () {
    final asset = StudioAsset.fromJson(<String, Object?>{
      'path': '2026/05/19/orange.png',
      'name': 'orange.png',
      'date': '2026-05-19',
      'size': 4096,
      'created_at': '2026-05-19 09:30:00',
      'url': 'http://localhost:8000/images/2026/05/19/orange.png',
      'thumbnail_url':
          'http://localhost:8000/image-thumbnails/2026/05/19/orange.png',
      'width': 1024,
      'height': 1792,
      'tags': <Object?>['海报', '已修图'],
      'prompt': 'orange product photo',
      'revised_prompt': 'studio orange product photo',
      'model': 'gpt-image-2',
      'project_id': 'project-1',
      'project_name': 'Spring Campaign',
      'conversation_id': 'conversation-1',
      'conversation_title': 'Hero images',
      'turn_id': 'turn-1',
      'mode': 'generate',
      'size_label': '1024x1792',
    });

    expect(asset.path, '2026/05/19/orange.png');
    expect(asset.createdAt, DateTime(2026, 5, 19, 9, 30));
    expect(asset.width, 1024);
    expect(asset.height, 1792);
    expect(asset.tags, ['海报', '已修图']);
    expect(asset.prompt, 'orange product photo');
    expect(asset.projectName, 'Spring Campaign');
    expect(asset.searchText, contains('gpt-image-2'));
    expect(asset.searchText, contains('海报'));
  });

  test('parses recipe response with reusable generation settings', () {
    final recipe = StudioRecipe.fromJson(<String, Object?>{
      'id': 'recipe-1',
      'name': 'Orange recipe',
      'prompt': 'orange product photo',
      'model': 'gpt-image-2',
      'size': '1024x1792',
      'source_image_path': '2026/05/orange.png',
      'source_turn_id': 'turn-1',
      'project_id': 'project-1',
      'tags': <Object?>['商业', '海报'],
      'created_at': '2026-05-19T09:30:00Z',
      'updated_at': '2026-05-19T09:35:00Z',
    });

    expect(recipe.id, 'recipe-1');
    expect(recipe.name, 'Orange recipe');
    expect(recipe.prompt, 'orange product photo');
    expect(recipe.model, 'gpt-image-2');
    expect(recipe.size, '1024x1792');
    expect(recipe.sourceImagePath, '2026/05/orange.png');
    expect(recipe.tags, ['商业', '海报']);
    expect(recipe.updatedAt, DateTime.parse('2026-05-19T09:35:00Z'));
  });
}
