from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from services.storage.json_storage import JSONStorageBackend


class StudioStorageTests(unittest.TestCase):
    def test_json_storage_round_trips_studio_state(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            data_dir = Path(tmp_dir)
            storage = JSONStorageBackend(data_dir / "accounts.json", data_dir / "auth_keys.json")
            state = {
                "projects": [{"id": "project-1", "owner_id": "owner-1", "name": "Spring"}],
                "conversations": [{"id": "conversation-1", "project_id": "project-1"}],
                "turns": [{"id": "turn-1", "conversation_id": "conversation-1"}],
                "prompt_templates": [{"id": "template-1", "name": "Product"}],
                "favorites": [{"id": "favorite-1", "image_path": "2026/05/image.png"}],
            }

            storage.save_studio_state(state)
            reloaded = JSONStorageBackend(data_dir / "accounts.json", data_dir / "auth_keys.json")

            self.assertEqual(reloaded.load_studio_state(), state)


from services.studio_service import StudioService


OWNER = {"id": "owner-1", "name": "Owner", "role": "user"}
OTHER_OWNER = {"id": "owner-2", "name": "Other", "role": "user"}
ADMIN = {"id": "admin-1", "name": "Admin", "role": "admin"}


class StudioServiceTests(unittest.TestCase):
    def make_service(self, *, purge_files=None, forget_tasks=None, forget_logs=None):
        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir)
            storage = JSONStorageBackend(path / "accounts.json", path / "auth_keys.json", path / "studio.json")
            return (
                StudioService(
                    storage,
                    purge_files=purge_files,
                    forget_tasks=forget_tasks,
                    forget_logs=forget_logs,
                ),
                storage,
                path,
            )

    def test_user_project_conversation_turn_lifecycle(self):
        service, _storage, _path = self.make_service()

        project = service.create_project(OWNER, "Spring Campaign")
        conversation = service.create_conversation(OWNER, project["id"], "Hero images", "generate")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            mode="generate",
            prompt="orange product photo",
            model="gpt-image-2",
            size="1024x1024",
            reference_images=[],
        )

        self.assertEqual(service.list_projects(OWNER)[0]["name"], "Spring Campaign")
        self.assertEqual(service.list_conversations(OWNER, project["id"])[0]["id"], conversation["id"])
        self.assertEqual(service.list_turns(OWNER, conversation["id"])[0]["id"], turn["id"])

    def test_user_cannot_access_other_users_project(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Private")

        with self.assertRaises(ValueError) as ctx:
            service.create_conversation(OTHER_OWNER, project["id"], "Nope", "generate")

        self.assertIn("not found", str(ctx.exception).lower())

    def test_admin_can_list_all_projects(self):
        service, _storage, _path = self.make_service()
        service.create_project(OWNER, "Owner Project")
        service.create_project(OTHER_OWNER, "Other Project")

        names = [item["name"] for item in service.list_projects(ADMIN)]

        self.assertEqual(names, ["Other Project", "Owner Project"])

    def test_favorite_is_idempotent_by_owner_and_path(self):
        service, _storage, _path = self.make_service()

        first = service.add_favorite(OWNER, "2026/05/image.png", source_turn_id="turn-1")
        second = service.add_favorite(OWNER, "2026/05/image.png", source_turn_id="turn-1")

        self.assertEqual(first["id"], second["id"])
        self.assertEqual(len(service.list_favorites(OWNER)), 1)

    def test_list_favorites_includes_prompt_joined_from_source_turn(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        turn_with_path = service.create_turn(
            OWNER,
            conversation["id"],
            prompt="orange product photo",
            result_images=[{"path": "2026/05/orange.png"}],
        )

        service.add_favorite(
            OWNER,
            "2026/05/orange.png",
            source_turn_id=turn_with_path["id"],
        )
        service.add_favorite(OWNER, "2026/05/orphan.png")

        favorites = service.list_favorites(OWNER)

        prompt_map = {fav["image_path"]: fav.get("prompt", "") for fav in favorites}
        self.assertEqual(prompt_map["2026/05/orange.png"], "orange product photo")
        self.assertEqual(prompt_map["2026/05/orphan.png"], "")

    def test_recipe_lifecycle_is_user_scoped_and_keeps_generation_settings(self):
        service, _storage, _path = self.make_service()

        recipe = service.create_recipe(
            OWNER,
            name="Orange product recipe",
            prompt="orange product photo",
            model="gpt-image-2",
            size="1024x1792",
            source_image_path="2026/05/orange.png",
            source_turn_id="turn-1",
            project_id="project-1",
            tags=["商业", "海报", "商业"],
        )

        listed = service.list_recipes(OWNER)

        self.assertEqual(listed[0]["id"], recipe["id"])
        self.assertEqual(listed[0]["prompt"], "orange product photo")
        self.assertEqual(listed[0]["model"], "gpt-image-2")
        self.assertEqual(listed[0]["size"], "1024x1792")
        self.assertEqual(listed[0]["source_image_path"], "2026/05/orange.png")
        self.assertEqual(listed[0]["tags"], ["商业", "海报"])
        self.assertEqual(service.list_recipes(OTHER_OWNER), [])

        self.assertTrue(service.delete_recipe(OWNER, recipe["id"]))
        self.assertEqual(service.list_recipes(OWNER), [])

    def test_consistency_profile_lifecycle_is_user_scoped(self):
        service, _storage, _path = self.make_service()

        profile = service.create_consistency_profile(
            OWNER,
            name="Luna",
            kind="character",
            guidance="A silver-haired botanist with a teal jacket.",
            reference_image_path="/2026/05/luna.png",
            tags=["角色", "主角", "角色"],
        )

        self.assertEqual(profile["name"], "Luna")
        self.assertEqual(profile["kind"], "character")
        self.assertEqual(profile["guidance"], "A silver-haired botanist with a teal jacket.")
        self.assertEqual(profile["reference_image_path"], "2026/05/luna.png")
        self.assertEqual(profile["tags"], ["角色", "主角"])
        self.assertEqual(service.list_consistency_profiles(OWNER)[0]["id"], profile["id"])
        self.assertEqual(service.list_consistency_profiles(OTHER_OWNER), [])

        updated = service.update_consistency_profile(
            OWNER,
            profile["id"],
            {"name": "Luna Prime", "kind": "style"},
        )

        self.assertIsNotNone(updated)
        self.assertEqual(updated["name"], "Luna Prime")
        self.assertEqual(updated["kind"], "style")
        self.assertTrue(service.delete_consistency_profile(OWNER, profile["id"]))
        self.assertEqual(service.list_consistency_profiles(OWNER), [])

    def test_consistency_profile_rejects_invalid_kind_and_blank_guidance(self):
        service, _storage, _path = self.make_service()

        with self.assertRaisesRegex(ValueError, "profile guidance is required"):
            service.create_consistency_profile(
                OWNER,
                name="Blank",
                kind="character",
                guidance="   ",
            )

        with self.assertRaisesRegex(ValueError, "profile kind must be character or style"):
            service.create_consistency_profile(
                OWNER,
                name="Invalid",
                kind="mood",
                guidance="Keep a painterly look.",
            )

    def test_prompt_hub_lists_shared_recipes_without_owner_metadata(self):
        service, _storage, _path = self.make_service()
        private_recipe = service.create_recipe(
            OWNER,
            name="Private recipe",
            prompt="private prompt",
            model="gpt-image-2",
            size="1024x1024",
        )
        shared_recipe = service.create_recipe(
            OTHER_OWNER,
            name="Shared recipe",
            prompt="shared prompt",
            model="gpt-image-2",
            size="1024x1792",
        )
        service._state["recipes"][0]["shared"] = False
        service._state["recipes"][1]["shared"] = True

        hub = getattr(service, "list_prompt_hub")(OWNER)

        self.assertEqual([item["id"] for item in hub], [shared_recipe["id"]])
        self.assertNotIn("owner_id", hub[0])

    def test_clone_prompt_hub_recipe_creates_a_private_copy(self):
        service, _storage, _path = self.make_service()
        shared_recipe = service.create_recipe(
            OTHER_OWNER,
            name="Shared recipe",
            prompt="shared prompt",
            model="gpt-image-2",
            size="1024x1792",
            tags=["海报"],
        )
        service._state["recipes"][0]["shared"] = True

        cloned = getattr(service, "clone_recipe")(OWNER, shared_recipe["id"])

        self.assertEqual(cloned["prompt"], "shared prompt")
        self.assertEqual(cloned["model"], "gpt-image-2")
        self.assertEqual(cloned["size"], "1024x1792")
        self.assertFalse(cloned.get("shared", True))
        self.assertEqual(len(service.list_recipes(OWNER)), 1)
        self.assertEqual(service.list_recipes(OTHER_OWNER)[0]["id"], shared_recipe["id"])

    def test_image_asset_metadata_index_joins_turn_project_and_prompt_by_path(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring Campaign")
        conversation = service.create_conversation(OWNER, project["id"], "Hero images", "generate")
        service.create_turn(
            OWNER,
            conversation["id"],
            prompt="orange product photo",
            model="gpt-image-2",
            size="1024x1024",
            result_images=[
                {
                    "path": "2026/05/orange.png",
                    "url": "http://testserver/images/2026/05/orange.png",
                    "revised_prompt": "bright orange product photo",
                }
            ],
            status="success",
        )

        metadata = service.image_asset_metadata_index(OWNER)

        self.assertEqual(metadata["2026/05/orange.png"]["prompt"], "orange product photo")
        self.assertEqual(metadata["2026/05/orange.png"]["revised_prompt"], "bright orange product photo")
        self.assertEqual(metadata["2026/05/orange.png"]["model"], "gpt-image-2")
        self.assertEqual(metadata["2026/05/orange.png"]["project_id"], project["id"])
        self.assertEqual(metadata["2026/05/orange.png"]["project_name"], "Spring Campaign")
        self.assertEqual(metadata["2026/05/orange.png"]["conversation_title"], "Hero images")

    def test_add_favorite_returns_prompt_for_visible_turn(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            prompt="mint product photo",
            result_images=[{"path": "2026/05/mint.png"}],
        )

        favorite = service.add_favorite(
            OWNER,
            "2026/05/mint.png",
            source_turn_id=turn["id"],
        )

        self.assertEqual(favorite["prompt"], "mint product photo")

    def test_list_favorites_hides_prompt_from_other_users_turns(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        owner_turn = service.create_turn(
            OWNER,
            conversation["id"],
            prompt="owner's secret prompt",
            result_images=[{"path": "2026/05/secret.png"}],
        )
        # Another user favorites the same image path. They should not see
        # the prompt from the owner's private turn.
        service.add_favorite(
            OTHER_OWNER,
            "2026/05/secret.png",
            source_turn_id=owner_turn["id"],
        )

        favorites = service.list_favorites(OTHER_OWNER)

        self.assertEqual(favorites[0]["prompt"], "")

    def test_create_turn_copies_caller_reference_images(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero images", "generate")
        reference_images = [{"path": "refs/original.png"}]

        service.create_turn(
            OWNER,
            conversation["id"],
            prompt="orange product photo",
            reference_images=reference_images,
        )
        reference_images[0]["path"] = "refs/mutated.png"
        reference_images.append({"path": "refs/extra.png"})

        stored = service.list_turns(OWNER, conversation["id"])[0]

        self.assertEqual(stored["reference_images"], [{"path": "refs/original.png"}])

    def test_list_turns_returns_do_not_mutate_service_state(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero images", "generate")
        service.create_turn(
            OWNER,
            conversation["id"],
            prompt="orange product photo",
            reference_images=[{"path": "refs/original.png"}],
        )

        listed = service.list_turns(OWNER, conversation["id"])
        listed[0]["reference_images"][0]["path"] = "refs/mutated.png"
        listed[0]["reference_images"].append({"path": "refs/extra.png"})

        stored = service.list_turns(OWNER, conversation["id"])[0]

        self.assertEqual(stored["reference_images"], [{"path": "refs/original.png"}])

    def test_sync_turn_from_successful_task(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            mode="generate",
            prompt="cat",
            model="gpt-image-2",
            size="",
            reference_images=[],
        )

        synced = service.sync_turn_from_task(
            OWNER,
            turn["id"],
            {"id": "task-1", "status": "success", "data": [{"url": "http://testserver/images/2026/05/cat.png"}]},
        )

        self.assertEqual(synced["status"], "success")
        self.assertEqual(synced["result_images"][0]["url"], "http://testserver/images/2026/05/cat.png")
        self.assertEqual(synced["result_images"][0]["path"], "2026/05/cat.png")

    def test_retry_failed_turn_clears_error_and_uses_new_task_id(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            mode="generate",
            prompt="cat",
            model="gpt-image-2",
            size="",
            reference_images=[],
            status="error",
            error="failed",
        )

        retried = service.mark_turn_retrying(OWNER, turn["id"], "task-2")

        self.assertEqual(retried["status"], "queued")
        self.assertEqual(retried["client_task_id"], "task-2")
        self.assertEqual(retried["task_id"], "task-2")
        self.assertEqual(retried["error"], "")
        self.assertEqual(retried["result_images"], [])

    def test_create_queued_turn_reuses_client_task_id_in_conversation(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")

        first = service.create_queued_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            mode="generate",
            prompt="cat",
            model="gpt-image-2",
            size="",
            reference_images=[],
        )
        second = service.create_queued_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            mode="generate",
            prompt="cat again",
            model="gpt-image-2",
            size="1024x1024",
            reference_images=[],
        )

        self.assertEqual(second["id"], first["id"])
        self.assertEqual(second["prompt"], "cat")
        self.assertEqual(len(service.list_turns(OWNER, conversation["id"])), 1)

    def test_create_queued_turn_rejects_blank_client_task_id(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")

        with self.assertRaises(ValueError):
            service.create_queued_turn(
                OWNER,
                conversation["id"],
                client_task_id="   ",
                mode="generate",
                prompt="cat",
                model="gpt-image-2",
                size="",
                reference_images=[],
            )

        self.assertEqual(service.list_turns(OWNER, conversation["id"]), [])

    def test_create_queued_turn_rejects_client_task_id_used_in_other_conversation(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        first_conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        second_conversation = service.create_conversation(OWNER, project["id"], "Variant", "generate")
        service.create_queued_turn(
            OWNER,
            first_conversation["id"],
            client_task_id="task-1",
            mode="generate",
            prompt="cat",
            model="gpt-image-2",
            size="",
            reference_images=[],
        )

        with self.assertRaises(ValueError):
            service.create_queued_turn(
                OWNER,
                second_conversation["id"],
                client_task_id="task-1",
                mode="generate",
                prompt="dog",
                model="gpt-image-2",
                size="",
                reference_images=[],
            )

        self.assertEqual(service.list_turns(OWNER, second_conversation["id"]), [])

    def test_mark_turn_retrying_rejects_ineligible_turns(self):
        for status in ("success", "queued", "running"):
            with self.subTest(status=status):
                service, _storage, _path = self.make_service()
                project = service.create_project(OWNER, "Spring")
                conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
                turn = service.create_turn(
                    OWNER,
                    conversation["id"],
                    client_task_id="task-1",
                    task_id="task-1",
                    mode="generate",
                    prompt="cat",
                    status=status,
                    error="",
                )

                with self.assertRaises(ValueError):
                    service.mark_turn_retrying(OWNER, turn["id"], "task-2")

                stored = service.get_turn(OWNER, turn["id"])
                self.assertEqual(stored["status"], status)
                self.assertEqual(stored["task_id"], "task-1")

    def test_mark_turn_retrying_rejects_edit_turns(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "edit")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            mode="edit",
            prompt="cat",
            status="error",
            error="failed",
        )

        with self.assertRaises(ValueError):
            service.mark_turn_retrying(OWNER, turn["id"], "task-2")

        stored = service.get_turn(OWNER, turn["id"])
        self.assertEqual(stored["status"], "error")
        self.assertEqual(stored["task_id"], "task-1")
        self.assertEqual(stored["error"], "failed")

    def test_mark_turn_retrying_rejects_blank_client_task_id(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            mode="generate",
            prompt="cat",
            status="error",
            error="failed",
        )

        with self.assertRaises(ValueError):
            service.mark_turn_retrying(OWNER, turn["id"], "   ")

        stored = service.get_turn(OWNER, turn["id"])
        self.assertEqual(stored["status"], "error")
        self.assertEqual(stored["task_id"], "task-1")
        self.assertEqual(stored["error"], "failed")

    def test_mark_turn_retrying_rejects_client_task_id_used_by_another_turn(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            mode="generate",
            prompt="cat",
            status="success",
        )
        failed = service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-2",
            task_id="task-2",
            mode="generate",
            prompt="dog",
            status="error",
            error="failed",
        )

        with self.assertRaises(ValueError):
            service.mark_turn_retrying(OWNER, failed["id"], "task-1")

        stored = service.get_turn(OWNER, failed["id"])
        self.assertEqual(stored["status"], "error")
        self.assertEqual(stored["client_task_id"], "task-2")
        self.assertEqual(stored["task_id"], "task-2")
        self.assertEqual(stored["error"], "failed")

    def test_mark_turn_retrying_rejects_same_current_client_task_id(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            mode="generate",
            prompt="cat",
            status="error",
            error="failed",
        )

        with self.assertRaises(ValueError):
            service.mark_turn_retrying(OWNER, turn["id"], "task-1")

        stored = service.get_turn(OWNER, turn["id"])
        self.assertEqual(stored["status"], "error")
        self.assertEqual(stored["client_task_id"], "task-1")
        self.assertEqual(stored["task_id"], "task-1")
        self.assertEqual(stored["error"], "failed")

    def test_create_project_rolls_back_in_memory_state_on_save_failure(self):
        class FailingSaveStorage(JSONStorageBackend):
            def save_studio_state(self, state):
                raise RuntimeError("save failed")

        with tempfile.TemporaryDirectory() as tmp_dir:
            path = Path(tmp_dir)
            storage = FailingSaveStorage(path / "accounts.json", path / "auth_keys.json", path / "studio.json")
            service = StudioService(storage)

            with self.assertRaises(RuntimeError):
                service.create_project(OWNER, "Unsaved")

            self.assertEqual(service.list_projects(OWNER), [])

    def test_invalid_template_update_does_not_partially_mutate_template(self):
        service, _storage, _path = self.make_service()
        template = service.create_prompt_template(OWNER, "Original", "Original Category", "original content")

        with self.assertRaises(ValueError):
            service.update_prompt_template(
                OWNER,
                template["id"],
                {"name": "Mutated", "category": "Mutated Category", "content": "   "},
            )

        stored = [
            item
            for item in service.list_prompt_templates(OWNER)
            if item["id"] == template["id"]
        ][0]

        self.assertEqual(stored["name"], "Original")
        self.assertEqual(stored["category"], "Original Category")
        self.assertEqual(stored["content"], "original content")

    def test_delete_conversation_cascades_to_turns(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        kept_conversation = service.create_conversation(OWNER, project["id"], "Other", "generate")
        service.create_turn(OWNER, conversation["id"], prompt="cat", reference_images=[])
        service.create_turn(OWNER, conversation["id"], prompt="dog", reference_images=[])
        service.create_turn(OWNER, kept_conversation["id"], prompt="bird", reference_images=[])

        deleted = service.delete_conversation(OWNER, conversation["id"])

        self.assertTrue(deleted)
        self.assertEqual(
            [c["id"] for c in service.list_conversations(OWNER, project["id"])],
            [kept_conversation["id"]],
        )
        self.assertEqual(service.list_turns(OWNER, conversation["id"]), [])
        kept_prompts = [t["prompt"] for t in service.list_turns(OWNER, kept_conversation["id"])]
        self.assertEqual(kept_prompts, ["bird"])

    def test_delete_conversation_returns_false_for_other_user(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")

        self.assertFalse(service.delete_conversation(OTHER_OWNER, conversation["id"]))
        self.assertEqual(len(service.list_conversations(OWNER, project["id"])), 1)

    def test_delete_turn_removes_only_target(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        target = service.create_turn(OWNER, conversation["id"], prompt="cat", reference_images=[])
        kept = service.create_turn(OWNER, conversation["id"], prompt="dog", reference_images=[])

        self.assertTrue(service.delete_turn(OWNER, target["id"]))
        remaining = [t["id"] for t in service.list_turns(OWNER, conversation["id"])]
        self.assertEqual(remaining, [kept["id"]])

    def test_delete_turn_returns_false_for_other_user(self):
        service, _storage, _path = self.make_service()
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        turn = service.create_turn(OWNER, conversation["id"], prompt="cat", reference_images=[])

        self.assertFalse(service.delete_turn(OTHER_OWNER, turn["id"]))
        self.assertEqual(len(service.list_turns(OWNER, conversation["id"])), 1)

    def test_delete_conversation_does_not_purge_by_default(self):
        purged_files: list[list[str]] = []
        forgotten_tasks: list[tuple[dict, list[str]]] = []
        service, _storage, _path = self.make_service(
            purge_files=lambda paths: purged_files.append(list(paths)),
            forget_tasks=lambda identity, ids: forgotten_tasks.append((identity, list(ids))),
        )
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            prompt="cat",
            result_images=[{"path": "2026/05/cat.png"}],
        )

        self.assertTrue(service.delete_conversation(OWNER, conversation["id"]))
        self.assertEqual(purged_files, [])
        self.assertEqual(forgotten_tasks, [])

    def test_delete_conversation_purges_image_files_and_tasks_when_requested(self):
        purged_files: list[list[str]] = []
        forgotten_tasks: list[tuple[dict, list[str]]] = []
        forgotten_logs: list[list[str]] = []
        service, _storage, _path = self.make_service(
            purge_files=lambda paths: purged_files.append(list(paths)),
            forget_tasks=lambda identity, ids: forgotten_tasks.append((identity, list(ids))),
            forget_logs=lambda paths: forgotten_logs.append(list(paths)),
        )
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            prompt="cat",
            result_images=[{"path": "2026/05/cat.png"}, {"path": "2026/05/cat-2.png"}],
        )
        service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-2",
            task_id="task-2",
            prompt="dog",
            result_images=[{"path": "2026/05/dog.png"}],
        )

        self.assertTrue(
            service.delete_conversation(OWNER, conversation["id"], purge_images=True)
        )

        self.assertEqual(
            sorted(purged_files[0]),
            ["2026/05/cat-2.png", "2026/05/cat.png", "2026/05/dog.png"],
        )
        self.assertEqual(sorted(forgotten_tasks[0][1]), ["task-1", "task-2"])
        self.assertEqual(forgotten_tasks[0][0]["id"], OWNER["id"])
        self.assertEqual(
            sorted(forgotten_logs[0]),
            ["2026/05/cat-2.png", "2026/05/cat.png", "2026/05/dog.png"],
        )

    def test_delete_conversation_with_purge_swallows_purge_errors(self):
        def raise_purge(_paths):
            raise RuntimeError("disk full")

        def raise_forget(_identity, _ids):
            raise RuntimeError("task store offline")

        def raise_logs(_paths):
            raise RuntimeError("log store offline")

        service, _storage, _path = self.make_service(
            purge_files=raise_purge,
            forget_tasks=raise_forget,
            forget_logs=raise_logs,
        )
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        service.create_turn(
            OWNER,
            conversation["id"],
            task_id="task-1",
            prompt="cat",
            result_images=[{"path": "2026/05/cat.png"}],
        )

        self.assertTrue(
            service.delete_conversation(OWNER, conversation["id"], purge_images=True)
        )
        self.assertEqual(service.list_conversations(OWNER, project["id"]), [])

    def test_delete_turn_purges_image_files_and_task_when_requested(self):
        purged_files: list[list[str]] = []
        forgotten_tasks: list[tuple[dict, list[str]]] = []
        service, _storage, _path = self.make_service(
            purge_files=lambda paths: purged_files.append(list(paths)),
            forget_tasks=lambda identity, ids: forgotten_tasks.append((identity, list(ids))),
        )
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        target = service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-1",
            task_id="task-1",
            prompt="cat",
            result_images=[{"path": "2026/05/cat.png"}],
        )
        # An unrelated turn must not be touched.
        service.create_turn(
            OWNER,
            conversation["id"],
            client_task_id="task-2",
            task_id="task-2",
            prompt="dog",
            result_images=[{"path": "2026/05/dog.png"}],
        )

        self.assertTrue(service.delete_turn(OWNER, target["id"], purge_images=True))
        self.assertEqual(purged_files, [["2026/05/cat.png"]])
        self.assertEqual(forgotten_tasks[0][1], ["task-1"])

    def test_delete_turn_does_not_purge_by_default(self):
        purged_files: list[list[str]] = []
        forgotten_tasks: list[tuple[dict, list[str]]] = []
        service, _storage, _path = self.make_service(
            purge_files=lambda paths: purged_files.append(list(paths)),
            forget_tasks=lambda identity, ids: forgotten_tasks.append((identity, list(ids))),
        )
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            task_id="task-1",
            prompt="cat",
            result_images=[{"path": "2026/05/cat.png"}],
        )

        self.assertTrue(service.delete_turn(OWNER, turn["id"]))
        self.assertEqual(purged_files, [])
        self.assertEqual(forgotten_tasks, [])

    def test_delete_turn_with_purge_skips_callbacks_when_no_images(self):
        purged_files: list[list[str]] = []
        forgotten_tasks: list[tuple[dict, list[str]]] = []
        service, _storage, _path = self.make_service(
            purge_files=lambda paths: purged_files.append(list(paths)),
            forget_tasks=lambda identity, ids: forgotten_tasks.append((identity, list(ids))),
        )
        project = service.create_project(OWNER, "Spring")
        conversation = service.create_conversation(OWNER, project["id"], "Hero", "generate")
        turn = service.create_turn(
            OWNER,
            conversation["id"],
            prompt="cat",
            result_images=[],
        )

        self.assertTrue(service.delete_turn(OWNER, turn["id"], purge_images=True))
        self.assertEqual(purged_files, [])
        self.assertEqual(forgotten_tasks, [])
