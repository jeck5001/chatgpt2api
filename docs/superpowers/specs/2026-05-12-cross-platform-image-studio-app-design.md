# Cross-Platform Image Studio App Design

Date: 2026-05-12

## Goal

Build a native-feeling cross-platform client for the existing chatgpt2api image studio. The app should target iOS, Android, macOS, Windows, and Linux from one codebase, and should be buildable through GitHub Actions where platform rules allow it.

The first version is an AI image workspace, not a full admin console. It connects to the existing FastAPI backend and uses the server-backed image studio APIs already being added to this project.

## Confirmed Direction

The chosen product and technical direction is:

- Use Flutter for the cross-platform client.
- Keep the existing FastAPI backend as the source of truth.
- Keep the existing Next.js panel for admin, account, logs, settings, register, and web fallback.
- First app scope is the AI image studio only.
- Support both username/password login and API key mode.
- Do not implement offline mode in v1.
- Use an adaptive workspace layout: desktop three-column, tablet two-column, mobile bottom-tab flow.

## Product Scope

### In Scope

- Native app shell for iOS, Android, macOS, Windows, and Linux.
- Server address setup and connection test.
- Login with existing account credentials.
- API key mode for personal/internal usage.
- Project list and project switching.
- Conversation list and turn history.
- Image generation from prompt.
- Image editing from reference images.
- Result polling and task status.
- Favorite and unfavorite images.
- Image library with favorites and recent results.
- Prompt template browsing and insertion.
- Basic account/quota/status display.
- Local draft preservation while online.
- GitHub Actions workflows for Android and desktop builds.
- GitHub Actions workflow definitions for iOS and macOS builds that require macOS runners and signing assets.

### Out of Scope

- Offline task queue.
- Full admin account management.
- Registration automation UI.
- Logs, settings, and account pool management.
- Public sharing pages.
- Payment or SaaS billing.
- Complex team permissions.
- App store release automation beyond build artifact generation.

## Target Platforms

### Mobile

- iOS 15+.
- Android 8+.
- Primary use: prompt, generate, review, favorite, continue edit, download/share image.
- Navigation: bottom tabs.

### Tablet

- iPad and Android tablets.
- Primary use: creation plus project/history side panel.
- Navigation: two-column layout with persistent project rail.

### Desktop

- macOS, Windows, and Linux.
- Primary use: full creative workspace.
- Navigation: three-column layout.

## UX Architecture

### Adaptive Layout Strategy

The app uses the same feature modules across platforms but changes navigation and layout by width:

- `compact`: mobile phones.
- `medium`: tablets and small desktop windows.
- `expanded`: desktop and wide tablet landscape.

### Compact Mobile Layout

Mobile uses bottom tabs:

- `Create`: prompt composer, references, active generation, and latest results.
- `Library`: recent images, favorites, and continue-edit actions.
- `Projects`: project and conversation switching.
- `Settings`: server address, auth mode, account status, and sign out.

The composer should remain touch-first. Primary actions must be reachable with one hand, and image results should open into a full-screen viewer.

### Medium Tablet Layout

Tablet uses two panes:

- Left pane: projects, conversations, and templates.
- Main pane: composer, active turns, results, and image viewer.

The inspector information from desktop is collapsed into sheets or side panels.

### Expanded Desktop Layout

Desktop uses three panes:

- Left pane: projects and conversations.
- Center pane: results, turn timeline, and prompt composer.
- Right pane: templates, references, quota, and runtime status.

Desktop should support keyboard shortcuts, drag-and-drop image references, and multi-image result comparison.

## Visual Direction

The app should feel like a focused creative tool rather than an admin dashboard.

- Image-first hierarchy.
- Warm dark workspace by default for creation screens.
- High-contrast controls for accessibility.
- Large touch targets on mobile.
- Native platform motion where practical.
- Subtle material depth instead of heavy card clutter.

The app does not need to mirror the existing web UI pixel-for-pixel. It should reuse the same product model and backend behavior while feeling native on each platform.

## Authentication

### Server Setup

On first launch the user enters:

- Backend base URL.
- Optional display name for the server.

The app validates the server by calling a lightweight authenticated or public health/config endpoint. If the current backend does not expose one, the implementation plan should add a minimal app bootstrap endpoint.

### Account Login

Account login uses the existing backend auth behavior. The app stores the returned bearer token securely:

- iOS/macOS: Keychain.
- Android: encrypted shared preferences or platform secure storage.
- Windows/Linux: platform secure storage through Flutter secure storage where available.

### API Key Mode

API key mode stores a bearer token or API key securely and uses it for requests directly. It is intended for single-user or internal deployments where a full login flow is unnecessary.

The app must label API key mode clearly so users understand that permissions come from the provided key.

## Core Screens

### Onboarding

Purpose: connect the app to a backend.

Content:

- Backend URL field.
- Connection test.
- Auth mode selector: account login or API key.
- Recent servers list after first successful setup.

### Login

Purpose: authenticate the user.

Content:

- Username/password login form.
- API key input when API key mode is selected.
- Server identity and connection status.
- Error messages for invalid server, invalid credentials, and network failure.

### Create

Purpose: generate and edit images.

Content:

- Active project and conversation affordance.
- Prompt composer.
- Model, size, and count controls.
- Reference image picker.
- Generate/edit action.
- Active task status.
- Latest result grid.
- Continue edit and favorite actions.

### Project And Conversation Browser

Purpose: orient work inside projects.

Content:

- Project list.
- Create project.
- Recent conversations.
- Conversation title and updated time.
- Empty state for first project.

### Turn Detail

Purpose: review a prompt/result set.

Content:

- Prompt text.
- Status and timestamps.
- Result images.
- Error and retry action.
- Continue edit from a selected image.

### Library

Purpose: browse and reuse generated assets.

Content:

- Recent images.
- Favorite filter.
- Download/share.
- Continue edit.

Search is out of scope for v1 unless the backend already exposes a stable image search API before implementation starts.

### Settings

Purpose: manage app connection and auth state.

Content:

- Current server URL.
- Auth mode.
- Signed-in identity.
- Quota/status summary.
- Sign out.
- Clear local drafts and cached thumbnails.

## API Dependencies

The app should use the same server APIs as the web image studio:

- `GET /api/projects`
- `POST /api/projects`
- `PATCH /api/projects/{project_id}`
- `GET /api/image-conversations?project_id=...`
- `POST /api/image-conversations`
- `PATCH /api/image-conversations/{conversation_id}`
- `DELETE /api/image-conversations/{conversation_id}`
- `GET /api/image-turns?conversation_id=...`
- `POST /api/image-turns/generations`
- `POST /api/image-turns/edits`
- `POST /api/image-turns/{turn_id}/retry`
- `POST /api/image-turns/{turn_id}/sync`
- `GET /api/prompt-templates`
- `GET /api/image-favorites`
- `POST /api/image-favorites`
- `DELETE /api/image-favorites/{favorite_id}`

The implementation plan should verify the final route names against the backend before generating the Flutter API client.

## Local Data

The app is online-only in v1, but it can keep small local state:

- Server profiles.
- Secure auth token or API key.
- Last active project and conversation IDs.
- Unsaved prompt draft.
- Local thumbnail cache.
- Basic user preferences such as theme and layout density.

The app must not create offline image tasks or silently queue generation requests.

## Error Handling

- Backend unreachable: show reconnect state and keep local draft.
- Unauthorized: return to login without deleting server profiles.
- No image quota: show a clear blocked state in Create and status panel.
- Task failure: show turn-level error and retry.
- Upload failure: preserve prompt and references locally until user leaves the screen.
- Missing image file: show broken thumbnail and disable continue edit for that image.
- API key rejected: keep the key field available for correction but do not log the key.

## Flutter Architecture

### Package Structure

Use a single Flutter app under a new app directory, for example `apps/image_studio_app`.

Recommended structure:

- `lib/app`: app bootstrap, router, theme, responsive shell.
- `lib/core`: configuration, secure storage, HTTP client, error model.
- `lib/auth`: server setup, login, token management.
- `lib/studio`: projects, conversations, turns, composer, polling.
- `lib/library`: favorites, image grid, download/share.
- `lib/settings`: server profiles, session, cache controls.
- `lib/shared`: reusable widgets and layout primitives.

### State Management

Use a predictable Flutter state stack:

- Riverpod for app state and dependency injection.
- Dio or package:http for HTTP.
- flutter_secure_storage for secrets.
- go_router for navigation.
- freezed/json_serializable for API models if code generation is acceptable.

The implementation plan can choose exact packages after checking current repo preferences and GitHub Actions constraints.

### Polling

Turn polling should live in the studio domain layer, not inside individual widgets.

Rules:

- Poll only visible or active running turns.
- Stop polling when no running turns remain.
- Back off after repeated network failures.
- Refresh quota/status after a task reaches a terminal state.

## Build And CI

GitHub Actions should support:

- Static analysis.
- Flutter unit/widget tests.
- Android APK artifact.
- Linux desktop artifact.
- Windows desktop artifact.
- macOS desktop artifact on macOS runner.
- iOS unsigned build or signed build when signing secrets are configured.

Signing and distribution are separate from v1 build validation.

Expected constraints:

- iOS and macOS builds require macOS runners.
- iOS release artifacts require Apple signing credentials.
- Windows builds require a Windows runner.
- Linux builds require Linux desktop dependencies.

## Testing Plan

### Unit Tests

- API client request construction.
- Auth mode selection and token storage behavior with mocked storage.
- Project/conversation/turn model parsing.
- Task polling state transitions.
- Prompt draft preservation.

### Widget Tests

- Mobile bottom tab shell.
- Tablet two-pane shell.
- Desktop three-pane shell.
- Composer validation.
- Error states.
- Image result card actions.

### Integration Smoke Tests

- Configure server.
- Login or API key auth.
- Load projects.
- Submit generation.
- Poll until success or error.
- Favorite a result.
- Continue edit from a result.

The integration tests can run against a mocked local backend first. Real backend smoke tests should be optional in CI.

## Acceptance Criteria

- A user can connect the app to a chatgpt2api backend.
- A user can authenticate with account credentials or API key mode.
- A user can create/select a project and open conversations.
- A user can submit a prompt and see generation status.
- A user can view results, favorite images, and continue editing from a result.
- The mobile app uses bottom tabs and feels touch-first.
- The tablet app uses a two-pane workspace.
- The desktop app uses a three-pane workspace.
- The app preserves prompt drafts during network failures.
- CI can build Android and desktop artifacts.
- iOS/macOS CI paths are documented and ready for signing secrets.

## Implementation Notes

- Do not duplicate backend business logic in Flutter.
- Keep the Next.js admin panel in place.
- Keep the Flutter client focused on creation and image library workflows.
- Add only minimal backend endpoints needed for app bootstrap if missing.
- Avoid offline queues until online behavior is stable.
- Treat generated image files as server-owned assets.
