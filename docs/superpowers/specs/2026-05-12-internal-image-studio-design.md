# Internal Image Studio Design

Date: 2026-05-12

Figma concept: https://www.figma.com/design/RIlUsA550Y7nYmst260Ygr

## Goal

Turn the existing chatgpt2api web panel into an internal AI image creation app for one person or a small team. The first version should feel like a focused creative workspace instead of an admin console: projects and recent sessions on the left, prompt and generated outputs in the center, and references, templates, and basic runtime status on the right.

The implementation should reuse the current FastAPI backend, Next.js frontend, auth roles, image task APIs, image cache, image manager, account pool, logs, and storage abstraction.

## Confirmed Product Direction

The chosen direction is to refactor the existing web panel, not build a separate frontend and not only patch the current pages.

Admin pages stay mostly unchanged:

- `/accounts`
- `/settings`
- `/logs`
- `/register`

User-facing creation becomes the primary product surface:

- `/image` becomes the internal image studio.
- `/image-manager` remains the image library and gains small additions for favorites and reuse.
- Mobile support focuses on reviewing, favoriting, downloading, and continuing from results.

## Scope

### In Scope

- A three-column desktop studio for internal image creation.
- Server-backed projects, conversations, turns, prompt templates, and favorites.
- Reuse of existing image generation and image edit task endpoints.
- Project switching and recent session history.
- Prompt templates that can be inserted into the composer.
- Selecting a result image and continuing with it as an edit reference.
- Favoriting generated images and viewing favorites in the image manager.
- Basic runtime status in the studio, such as available quota, account availability, and recent failures.
- Mobile layout that supports result viewing, favorite, download, and continue editing.

### Out of Scope

- Payments, billing, and public SaaS operations.
- Multi-tenant workspace billing.
- Complex project sharing permissions.
- Public share pages.
- Full digital asset management.
- Advanced queue operations dashboard.
- Replacing the current account pool management flow.

## UX Structure

### Left Column: Projects and History

The left column orients the user.

- Shows the current project.
- Lists other projects.
- Lists recent conversations or turns.
- Provides a new project action.
- Supports archived projects later, but archive can be hidden from the first UI if time is tight.

### Center Column: Creation Workspace

The center column is the primary working surface.

- Prompt composer.
- Model, size, and count controls.
- Generate action.
- Result grid.
- Turn status and failure messages.
- Continue editing from a selected generated image.
- Retry failed turns.

### Right Column: Creative Context

The right column provides context without becoming a full admin page.

- Reference images for the current turn.
- Prompt template list.
- Basic quota and account availability status.
- Recent runtime warning summary.

### Image Manager

The image manager remains the asset library.

- Existing date and tag filtering stays.
- Add favorite filtering.
- Add favorite/unfavorite actions.
- Add "reuse to edit" from an image card.
- Keep batch download and delete behavior.

### Mobile

Mobile is a companion experience rather than the full desktop studio.

- View generated results.
- Favorite images.
- Download images.
- Continue editing from an image.
- Keep project and admin management secondary.

## Data Model

The new data should live in the existing storage abstraction so JSON, SQLite, PostgreSQL, and git storage can continue to be supported.

### Project

- `id`: stable string ID.
- `name`: project display name.
- `owner_id`: authenticated subject ID.
- `archived`: boolean.
- `created_at`: ISO timestamp.
- `updated_at`: ISO timestamp.

### Image Conversation

- `id`: stable string ID.
- `project_id`: parent project ID.
- `owner_id`: authenticated subject ID.
- `title`: display title, usually derived from the first prompt.
- `mode`: `generate` or `edit`.
- `created_at`: ISO timestamp.
- `updated_at`: ISO timestamp.

### Image Turn

- `id`: stable string ID.
- `conversation_id`: parent conversation ID.
- `owner_id`: authenticated subject ID.
- `client_task_id`: frontend task correlation ID.
- `task_id`: backend image task ID when submitted.
- `mode`: `generate` or `edit`.
- `prompt`: submitted prompt.
- `model`: model value.
- `size`: optional image size.
- `reference_images`: server image paths or uploaded reference descriptors.
- `result_images`: server image paths and URLs returned by the task.
- `status`: `queued`, `running`, `success`, or `error`.
- `error`: user-visible error message when failed.
- `created_at`: ISO timestamp.
- `updated_at`: ISO timestamp.

### Prompt Template

- `id`: stable string ID.
- `name`: template display name.
- `category`: grouping label.
- `content`: prompt text.
- `builtin`: boolean.
- `owner_id`: optional authenticated subject ID for user-created templates.
- `created_at`: ISO timestamp.
- `updated_at`: ISO timestamp.

### Image Favorite

- `id`: stable string ID.
- `owner_id`: authenticated subject ID.
- `image_path`: server-relative image path.
- `source_turn_id`: optional turn ID.
- `note`: optional short note.
- `created_at`: ISO timestamp.

## API Design

All new internal APIs require the existing bearer auth. Admin can access all studio data. User can only access their own project, conversation, turn, template, and favorite records.

### Projects

- `GET /api/projects`: list projects visible to the identity.
- `POST /api/projects`: create a project.
- `PATCH /api/projects/{project_id}`: rename or archive a project.

### Conversations

- `GET /api/image-conversations?project_id=...`: list conversations for a project.
- `POST /api/image-conversations`: create a conversation.
- `PATCH /api/image-conversations/{conversation_id}`: rename or move a conversation.
- `DELETE /api/image-conversations/{conversation_id}`: delete conversation metadata and turns, without deleting image files.

### Turns

- `GET /api/image-turns?conversation_id=...`: list turns for a conversation.
- `POST /api/image-turns/generations`: create a turn and submit a generation task.
- `POST /api/image-turns/edits`: create a turn and submit an edit task.
- `POST /api/image-turns/{turn_id}/retry`: resubmit a failed turn.
- `POST /api/image-turns/{turn_id}/sync`: sync the turn with its image task status.

The existing `/api/image-tasks/generations` and `/api/image-tasks/edits` remain available for backward compatibility. The new turn endpoints should wrap the same service logic so task submission remains centralized.

### Prompt Templates

- `GET /api/prompt-templates`: list builtin and user templates.
- `POST /api/prompt-templates`: create a user template.
- `PATCH /api/prompt-templates/{template_id}`: update a user template.
- `DELETE /api/prompt-templates/{template_id}`: delete a user template.

### Favorites

- `GET /api/image-favorites`: list favorites for the current identity.
- `POST /api/image-favorites`: favorite an image path.
- `DELETE /api/image-favorites/{favorite_id}`: remove a favorite.

The existing image manager API should include favorite state in image list responses when authenticated.

## Data Flow

### Generation

1. User selects or creates a project.
2. User creates or opens a conversation.
3. User submits a prompt from the studio.
4. Backend creates an `image_turn` with `queued` status.
5. Backend submits the existing image generation task.
6. Frontend polls turn or task status.
7. On success, backend records result image paths and marks the turn `success`.
8. On failure, backend records the error and marks the turn `error`.

### Continue Editing

1. User selects a generated result image.
2. Studio adds that image path to the reference list.
3. Composer switches to edit mode.
4. User submits a new prompt.
5. Backend creates an edit turn and submits the existing edit task.

### Favorites

1. User favorites a result image or image manager item.
2. Backend records the favorite by server-relative image path.
3. Image manager can filter to favorites and show favorite state.
4. Favoriting never copies or moves image files.

## Error Handling

- No available account or quota: show a clear empty state in the center workspace and expose quota/account status in the right column.
- Image task timeout: mark the turn as `error` and show retry.
- Sensitive word or AI review rejection: reuse the current filter path and display the error on the turn.
- Missing image file: show a broken asset state and disable continue editing for that image.
- API unavailable during editing: preserve local prompt draft and current project selection.
- Storage write failure: return a structured error and do not report the task as successfully persisted.

## Testing Plan

### Backend

- Storage round-trip tests for projects, conversations, turns, templates, and favorites.
- Permission tests for admin access and user isolation.
- Generation turn creation and task submission tests.
- Edit turn creation with reference image tests.
- Retry failed turn tests.
- Task sync tests for success, running, and error states.
- Regression tests for existing `/v1/images/generations`, `/v1/images/edits`, `/api/image-tasks`, account pool, and image manager behavior.

### Frontend

- Project creation and switching.
- Conversation listing and selection.
- Prompt submission and result polling.
- Edit flow from selected result image.
- Retry failed turn.
- Prompt template insertion.
- Favorite and unfavorite from studio and image manager.
- Mobile result review at 390px width.

## Acceptance Criteria

- A normal user can open `/image`, create a project, submit a prompt, see results, favorite a result, and continue editing from that result.
- A normal user cannot view or mutate another user's studio records.
- An admin can still use existing account, settings, logs, register, and image manager pages.
- Existing OpenAI-compatible API endpoints keep working.
- Existing image task endpoints keep working.
- Generated images remain visible in image manager.
- The UI preserves a prompt draft if an internal API request fails.
- The desktop studio follows the Figma concept's three-column layout.
- Mobile supports viewing, favorite, download, and continue editing.

## Implementation Notes

- Prefer small backend services with clear boundaries: project service, conversation service, template service, favorite service.
- Do not put all new behavior into existing page components.
- Keep task execution centralized in the current image task service or a thin wrapper around it.
- Avoid introducing a new database framework.
- Keep admin pages visually consistent with the current app until the studio flow is stable.
