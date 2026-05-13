# Image Result Complete Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn generated images into a complete mobile-ready flow with preview, save/share/download actions, and visible failure states.

**Architecture:** Keep the existing studio generation pipeline and add a focused result viewer layer on top of `CreateScreen`. The screen will render successful turns with tappable previews, open a dedicated full-screen viewer for a single image, and expose platform-appropriate actions without changing the backend contract.

**Tech Stack:** Flutter, `image_picker`-style image display patterns, `share_plus`-style sharing flow if already available or platform channel-free fallback, `url_launcher`/filesystem helpers only if needed

---

### Task 1: Add tappable result previews to the create screen

**Files:**
- Modify: `apps/image_studio_app/lib/studio/create_screen.dart`
- Test: `apps/image_studio_app/test/studio/create_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('tapping a result image opens the preview viewer', (tester) async {
  final controller = StudioController(FakeStudioRepository());
  controller.replaceTurns([
    StudioTurn(
      id: 'turn-success',
      conversationId: 'conversation-1',
      clientTaskId: 'task-success',
      taskId: 'task-success',
      mode: StudioTurnMode.generate,
      prompt: 'beautiful landscape',
      model: 'gpt-image-2',
      size: '1024x1024',
      resultImages: [
        StudioResultImage(
          url: Uri.parse('http://example.test/images/landscape.png'),
          path: '2026/05/landscape.png',
        ),
      ],
      status: StudioTurnStatus.success,
      error: '',
      updatedAt: DateTime.utc(2026, 5, 13),
    ),
  ]);

  await tester.pumpWidget(MaterialApp(home: CreateScreen(controller: controller)));
  await tester.tap(find.byType(Image));
  await tester.pumpAndSettle();

  expect(find.text('beautiful landscape'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/image_studio_app && /Users/jfwang/.cache/codex/flutter/bin/flutter test test/studio/create_screen_test.dart`
Expected: FAIL because no preview viewer exists yet.

- [ ] **Step 3: Write minimal implementation**

```dart
// Replace inline Image rendering with InkWell that opens a viewer.
// Add a small full-screen result viewer widget in the same file or a focused new file.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/image_studio_app && /Users/jfwang/.cache/codex/flutter/bin/flutter test test/studio/create_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/image_studio_app/lib/studio/create_screen.dart apps/image_studio_app/test/studio/create_screen_test.dart
git commit -m "feat: add tappable result previews"
```

### Task 2: Add full-screen image viewer actions

**Files:**
- Create: `apps/image_studio_app/lib/studio/studio_result_viewer.dart`
- Modify: `apps/image_studio_app/lib/studio/create_screen.dart`
- Test: `apps/image_studio_app/test/studio/studio_result_viewer_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('viewer shows save and share actions for a result image', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: StudioResultViewer(
        imageUrl: 'http://example.test/images/landscape.png',
        imagePath: '2026/05/landscape.png',
      ),
    ),
  );

  expect(find.text('Save'), findsOneWidget);
  expect(find.text('Share'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/image_studio_app && /Users/jfwang/.cache/codex/flutter/bin/flutter test test/studio/studio_result_viewer_test.dart`
Expected: FAIL because the viewer file does not exist yet.

- [ ] **Step 3: Write minimal implementation**

```dart
// Create a centered full-screen viewer with the image, path label, and buttons.
// Wire buttons to no-op placeholders first so the widget is structurally complete.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/image_studio_app && /Users/jfwang/.cache/codex/flutter/bin/flutter test test/studio/studio_result_viewer_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/image_studio_app/lib/studio/studio_result_viewer.dart apps/image_studio_app/lib/studio/create_screen.dart apps/image_studio_app/test/studio/studio_result_viewer_test.dart
git commit -m "feat: add studio result viewer"
```

### Task 3: Surface failure states and retry affordance

**Files:**
- Modify: `apps/image_studio_app/lib/studio/create_screen.dart`
- Test: `apps/image_studio_app/test/studio/create_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('failed turns show the backend error and retry button', (tester) async {
  final controller = StudioController(FakeStudioRepository());
  controller.replaceTurns([
    StudioTurn(
      id: 'turn-error',
      conversationId: 'conversation-1',
      clientTaskId: 'task-error',
      taskId: 'task-error',
      mode: StudioTurnMode.generate,
      prompt: 'broken image',
      model: 'gpt-image-2',
      size: '1024x1024',
      resultImages: const [],
      status: StudioTurnStatus.error,
      error: 'upstream request failed',
      updatedAt: DateTime.utc(2026, 5, 13),
    ),
  ]);

  await tester.pumpWidget(MaterialApp(home: CreateScreen(controller: controller)));

  expect(find.text('upstream request failed'), findsOneWidget);
  expect(find.text('Retry'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/image_studio_app && /Users/jfwang/.cache/codex/flutter/bin/flutter test test/studio/create_screen_test.dart`
Expected: FAIL because retry affordance is not rendered yet.

- [ ] **Step 3: Write minimal implementation**

```dart
// Render an error block per failed turn with a Retry button.
// The button can call the existing generation flow or remain disabled until the retry API is wired.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/image_studio_app && /Users/jfwang/.cache/codex/flutter/bin/flutter test test/studio/create_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/image_studio_app/lib/studio/create_screen.dart apps/image_studio_app/test/studio/create_screen_test.dart
git commit -m "feat: show failed studio turns clearly"
```
