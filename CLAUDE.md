# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

State Cycler is a Home Assistant custom integration that cycles through a list of entities (lights, switches, scenes, etc.), turning on one at a time. It has a Python backend (`custom_components/state_cycler/`) and a Vue 3 + TypeScript frontend (`frontend/`).

## Commands

### Setup
```bash
make setup        # Full setup (frontend + backend)
make setup-py     # Python only (uv sync)
make setup-ts     # TypeScript only (yarn install)
```

### Testing
```bash
make test                        # All tests
make test-py                     # Python tests (excludes Playwright by default)
make test-ts                     # Frontend tests (vitest)
make test-coverage               # All tests with coverage reports

# Single Python test / test file:
uv run pytest tests/test_core_adapters.py -q
uv run pytest tests/test_integration.py::test_name -q

# Run Playwright tests explicitly:
RUN_PLAYWRIGHT=1 make test-py
```

### Linting & Formatting
```bash
make lint         # All linters
make lint-py      # ruff check + format check
make lint-ts      # vue-tsc + eslint

make format       # Auto-format all code
make format-py    # ruff fix + format
make format-ts    # dprint + eslint --fix
```

### Build & Release
```bash
make build        # Build frontend (vite)
make commit       # Structured commit via scripts/commit.sh
make release      # Bump version, lint, build, push
```

## Architecture

### Core Pattern: Hub-and-Spoke

One authoritative **core entity** (`StateCyclerEntity` in `state_cycler.py`) owns all state, timers, and business logic. Lightweight **adapter entities** in the standard HA platforms mirror and forward actions to the core — they never write state directly.

```
StateCyclerEntity (state_cycler.<id>)   ← owns everything
    ├── select.state_cycler_<id>        ← dropdown of friendly names
    ├── switch.state_cycler_<id>        ← on/off toggle
    ├── button.state_cycler_<id>_next   ← next action
    ├── button.state_cycler_<id>_prev   ← prev action
    ├── sensor.state_cycler_<id>_raw    ← current entity_id
    └── sensor.state_cycler_<id>_friendly ← current friendly name
```

**Action flow:** User → Adapter → `core.async_handle_adapter_action()` → Core validates & applies → Core notifies adapters via HA dispatcher → Adapters update their HA state representation.

**Key files:**
- `state_cycler.py` — all core logic: cycling, timers, state snapshots, service handlers, event firing
- `__init__.py` — HA entry setup, platform forwarding, service registration
- `select.py / switch.py / button.py / sensor.py` — thin adapter platforms
- `config_flow.py` — Config UI (entity list, `include_off_state`, `timer_interval`)
- `const.py` — domain, attribute names, service names, event names

### State Model

The core entity's primary state is either `"off"` or the `entity_id` of the active entity. Index `-1` means off. The `include_off_state` config option inserts an explicit off step between wrap-arounds. `RestoreEntity` is used so state survives HA restarts.

### Frontend

A single custom Lovelace card (`<state-cycler-card>`) built with Vue 3 Composition API (`<script setup lang="ts">`). Entry point `main.ts` wraps the Vue component as a Web Component and registers it with the HA Lovelace card registry. Communicates with HA via the standard `hass` object injected by Lovelace.

Card config:
```yaml
type: custom:state-cycler-card
entity: state_cycler.my_cycler
title: Optional Title
```

### Testing Strategy

- `tests/test_core_adapters.py` — unit tests for core ↔ adapter interactions
- `tests/test_integration*.py` — full integration tests using `pytest-homeassistant-custom-component` (the `hass` fixture)
- `tests/test_playwright_example.py` — browser tests (Playwright), skipped by default, require `RUN_PLAYWRIGHT=1`
- All async tests run automatically via `asyncio_mode = "auto"` in `pyproject.toml`
- Coverage is always collected; reports go to `htmlcov/`

## ai/ Folder

The `ai/` folder contains AI development artifacts:
- `query.md` — original project specification and coding guidelines (early-return style, Vue `<script setup>`, Python 3.12+ async, `make commit` after every file change)
- `PROGRESS.md` — checklist of completed and pending tasks
- `errors.md` — log of errors encountered during AI development
- `references/` — reference HA integration examples used during development

## Key Conventions

- **Early-return pattern** preferred over deep nesting; use `continue`/`return`/`break` in loops.
- **Per-cycler async locks** in the core prevent race conditions on concurrent service calls.
- **State snapshots** (brightness, color, etc.) are captured before turning an entity off so it can be restored when cycled back.
- Playwright tests are marked `@pytest.mark.playwright` and excluded from normal `make test-py` runs.
- The `pytest-homeassistant-custom-component` version is pinned `<0.13.307` to stay on Python 3.12 support.
