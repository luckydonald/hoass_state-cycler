# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Plugin Template** — a Home Assistant custom integration with a Python backend and a Vue.js Lovelace card frontend. Generated from [hoass_plugin-template](https://github.com/luckydonald/hoass_plugin-template) via `scripts/init.sh`.

## Commands

```bash
# Setup
make setup          # install Python (uv sync) + frontend deps
make setup-py       # Python only
make setup-ts       # frontend only (uses corepack + yarn)

# Tests
make test           # run all tests
make test-py        # uv run pytest tests/
make test-ts        # yarn test in frontend dir
make test-coverage  # pytest --cov + frontend coverage

# Lint / format
make lint           # lint Python + TypeScript
make format         # format Python (ruff --fix) + TypeScript (dprint + eslint --fix)

# Build
make build          # build frontend with yarn

# Single Python test
uv run pytest tests/test_sensor.py::TestClassName::test_method_name -v

# Release
make release        # lint → build → bump version → tag → push to origin mane

# Commit (see Commit workflow below)
make commit
make fix-commits    # rebase/rename the latest AI commit batch
```

If `make lint-ts` / `make format-ts` fail with "command not found", run `make setup-ts` first.

## Commit workflow

**Run `make commit` after every file change**, without asking for confirmation — it is auto-approved by the IDE. Run it once per file operation, immediately after the change, before any error checking.

The commit script produces structured messages:
- Changes to `ai/query.md` → `🤌 ai: updated query`
- Changes to `ai/errors.md` → `🐞 ai: updated errors`
- All other changes → `✨ ai: [{padded_step}] {message} ({substep}/{total_substeps})`
- Lock files → `🔏 Updated package versions for frontend/backend.`

`make fix-commits` (alias: `make commit-fix`) interactively rebases the latest batch of AI commits to replace "running…" with a real message and fill in the total substep count. Supports `--start-commit`, `--end-commit`, `--number-search`, `--number-override`, `--ignore-blocks`, `--dry-run`, `--interactive`, and `-m`.

## Architecture

### Python backend (`custom_components/plugin_template/`)

Standard HA integration layout:
- `__init__.py` — integration setup/teardown (`async_setup_entry`, `async_unload_entry`)
- `sensor.py` — sensor platform
- `services.py` — custom service registration
- `const.py` — domain constant and all string constants
- `models.py` — dataclass models shared across the integration
- `manifest.json` — HA integration metadata (domain, version, dependencies)

Python toolchain: **uv** for dependency management, **ruff** for lint+format, **mypy** for type checking.

### Vue frontend (`frontend/`)

A Lovelace custom card compiled with Vite:
- `src/main.ts` — two custom elements registered via `customElements.define`: `plugin-template-card` (the card) and `plugin-template-card-editor` (the editor). Both mount a Vue app into their shadow DOM.
- `src/PluginTemplateCard.vue` — main card component (`<script setup lang="ts">`)
- `src/types.ts` — TypeScript types for card config and HA interfaces
- `src/env.d.ts` — ambient types, including `HTMLElementTagNameMap` extensions for `ha-*` web components

ESLint uses Airbnb style as baseline. `dprint` handles formatting. The formatter must **never collapse multiline constructs back to a single line** — this is intentional to keep diffs minimal.

### Scripts

- `scripts/commit.sh` — structured commit helper
- `scripts/release.sh` — reads `scripts/init.json`; bumps version, lints, builds, tags, pushes
- `scripts/fix-commits.sh` — interactive rebase tool for renaming AI commit batches
- `scripts/update-from-template.sh` — rebase this plugin onto the template's `mane` branch (`make rebase-template`)
- `scripts/merge-from-template.sh` — same but merge instead of rebase (`make merge-template`)

### AI workflow files

- `ai/query.md` — the prompt/task description given to the AI (committed separately first)
- `ai/errors.md` — error log pasted back to the AI (committed separately second)
- `ai/references/` — external docs/schemas provided for reference

## Code style guidelines

- Python: early-return pattern, no large nested `if` blocks; full type annotations; prefer async.
- TypeScript/Vue: `<script setup lang="ts">` SFCs; use `ha-*` web components where available; import HA types from `homeassistant` package; snake_case allowed for property/type-property names (ESLint exception already configured).
- CSS variable names with `--` prefix are exempt from the `naming-convention` rule.
- `ha-*` elements are web components, not Vue components — do not use Vue slot syntax (`<template #slot>`) on them.

## Branch naming

The default branch is `mane` (not `main`).
