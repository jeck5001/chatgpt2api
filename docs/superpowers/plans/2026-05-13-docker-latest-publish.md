# Docker Latest Publish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Automatically publish the Docker image as `latest` from `main`, while keeping versioned releases for `v*` tags.

**Architecture:** Update the existing Docker publish workflow instead of creating a second pipeline. Keep the current multi-arch Buildx flow, but widen the trigger so `main` pushes publish `latest` and tags continue publishing semver tags.

**Tech Stack:** GitHub Actions, Docker Buildx, GHCR, docker/metadata-action

---

### Task 1: Update the Docker publish trigger

**Files:**
- Modify: `.github/workflows/docker-publish.yml`

- [ ] **Step 1: Change the workflow triggers**

```yaml
on:
  push:
    branches:
      - main
    tags:
      - "v*"
  workflow_dispatch:
```

- [ ] **Step 2: Update metadata tagging**

```yaml
      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository_owner }}/${{ env.IMAGE_NAME }}
          tags: |
            type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/v') }}
            type=ref,event=tag
            type=sha
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
```

- [ ] **Step 3: Verify the YAML diff**

Run: `git diff --check`
Expected: no whitespace or syntax issues reported.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/docker-publish.yml docs/superpowers/plans/2026-05-13-docker-latest-publish.md
git commit -m "ci: publish docker latest from main"
```
