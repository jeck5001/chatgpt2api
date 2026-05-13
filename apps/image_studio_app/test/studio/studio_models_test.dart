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
}
