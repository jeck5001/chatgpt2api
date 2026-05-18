# Stitch Image Studio Refresh Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a previewable first-pass Flutter refresh that pulls the strongest ideas from the Stitch mobile designs while staying close to the current Image Studio app structure.

**Architecture:** Keep the existing routes, controllers, and data flows intact. Limit the first pass to view-layer changes in the Flutter app, centered on the shell, studio, turn detail, library, and supporting shared styling so the branch is easy to run and compare.

**Tech Stack:** Flutter, Material 3, existing Kiln tokens/theme, current app widgets under `apps/image_studio_app/lib`

---

## File Map
- Modify: `apps/image_studio_app/lib/shared/adaptive_shell.dart` — mobile shell hierarchy, nav feel, tab ordering if needed.
- Modify: `apps/image_studio_app/lib/studio/create_screen.dart` — creation workspace structure and mobile-first layout emphasis.
- Modify: `apps/image_studio_app/lib/studio/composer_bar.dart` — tactile composer styling and chip hierarchy.
- Modify: `apps/image_studio_app/lib/studio/turn_card.dart` — artwork-first cards, action grouping, stronger status treatment.
- Modify: `apps/image_studio_app/lib/studio/turn_detail_screen.dart` — replace placeholder with real drill-down screen.
- Modify: `apps/image_studio_app/lib/library/library_screen.dart` — mobile gallery rhythm and search/filter hierarchy.
- Modify: `apps/image_studio_app/lib/settings/settings_screen.dart` — calmer grouped settings presentation if time allows.
- Modify: `apps/image_studio_app/lib/app/theme.dart` and/or `apps/image_studio_app/lib/app/tokens.dart` only if targeted token additions are needed.

## Preview Slice
- [ ] Update shell to feel closer to the Stitch mobile app while preserving current app structure.
- [ ] Refresh studio screen and cards so generated artwork dominates the flow.
- [ ] Replace turn detail placeholder with a real image-focused detail screen.
- [ ] Bring library closer to the new visual rhythm.
- [ ] Only polish settings enough that the tab does not feel visually out of place.
