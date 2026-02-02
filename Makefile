# Is this a frontend or backend project, or both?
# Set explicit (e.g. by `make lint FRONTEND=1 BACKEND=1`), or detect the
# presence of the directories. FRONTEND_DIR picks the concrete frontend folder.

# Prefer frontend/ then frontend_vue/
FRONTEND_DIR :=
ifneq ($(wildcard frontend),)
FRONTEND_DIR := frontend
else ifneq ($(wildcard frontend_vue),)
FRONTEND_DIR := frontend_vue
endif

# FRONTEND is 1 if we found a frontend dir
FRONTEND ?= $(if $(FRONTEND_DIR),1,0)
BACKEND  ?= $(if $(wildcard custom_components),1,0)

.PHONY: release lint format build setup setup-py setup-ts setup-backend setup-frontend help commit init fix-commits commit-fix rebase-template template-rebase merge-template template-merge check-slots

# If user runs: make commit-fix --start-commit <hash> ... or make fix-commits --start-commit <hash> ...
# then MAKECMDGOALS contains: <goal> --start-commit <hash> ...
# Capture those extra words and expose them as $(EXTRA_ARGS), and
# create no-op targets for them so make doesn't try to build them.
ifeq ($(or $(filter commit-fix,$(MAKECMDGOALS)),$(filter fix-commits,$(MAKECMDGOALS))),)
EXTRA_ARGS :=
else
  # Determine which of the two goals was invoked as first word
  first_goal=$(firstword $(MAKECMDGOALS))
  ifeq ($(first_goal),commit-fix)
    EXTRA_ARGS := $(filter-out commit-fix,$(MAKECMDGOALS))
  else ifeq ($(first_goal),fix-commits)
    EXTRA_ARGS := $(filter-out fix-commits,$(MAKECMDGOALS))
  else
    EXTRA_ARGS :=
  endif
  # define no-op targets for each extra arg to avoid 'No rule to make target' errors
  $(eval $(EXTRA_ARGS): ; @:)
endif

# Support named variable style invocation, e.g.:
#   make commit-fix START_COMMIT=abc END_COMMIT=def IGNORE_BLOCKS=1
# Map these to CLI args passed to the script in addition to EXTRA_ARGS/ARGS.
VAR_ARGS :=
ifneq ($(strip $(START_COMMIT)),)
VAR_ARGS += --start-commit $(START_COMMIT)
endif
ifneq ($(strip $(END_COMMIT)),)
VAR_ARGS += --end-commit $(END_COMMIT)
endif
ifneq ($(strip $(IGNORE_BLOCKS)),)
# any non-empty value enables the flag
VAR_ARGS += --ignore-blocks
endif
ifneq ($(strip $(NUMBER_SEARCH)),)
# expect comma-separated list: 10,11,23
VAR_ARGS += --number-search $(NUMBER_SEARCH)
endif
ifneq ($(strip $(NUMBER_OVERRIDE)),)
VAR_ARGS += --number-override $(NUMBER_OVERRIDE)
endif

help:
	@echo "State Cycler - Development Commands"
	@echo ""
	@echo "Usage: make <target> [FRONTEND=1] [BACKEND=1]"
	@echo ""
	@echo "Targets:"
	@echo "  init           - Initialize/update plugin from template (runs scripts/init.sh)"
	@echo "  setup          - Set up the full development environment (frontend + backend)"
	@echo "  setup-ts       - Set up frontend development environment (TypeScript)"
	@echo "  setup-py       - Set up backend  development environment (Python)"
	@echo "  test           - Run all tests (frontend + backend)"
	@echo "  test-ts        - Run frontend tests"
	@echo "  test-py        - Run backend tests"
	@echo "  test-coverage  - Run tests with coverage report"
	@echo "  lint           - Run all linters (frontend + backend)"
	@echo "  lint-ts        - Lint/type‑check TypeScript only"
	@echo "  lint-py        - Lint/format Python only"
	@echo "  format         - Format all code (frontend + backend)"
	@echo "  format-ts      - Format TypeScript only"
	@echo "  format-py      - Format Python only"
	@echo "  build          - Build what needs to be build"
	@echo "  build-ts       - Build frontend"
	@echo "  commit         - Commit changes with structured messages"
	@echo "  fix-commits    - Fix AI commit messages (update totals and edit messages)"
	@echo "  commit-fix     - Alias for 'fix-commits' above"
	@echo "  release        - Bump version, lint, build, and push release"
	@echo "  rebase-template- Update plugin from template repository"
	@echo "  template-rebase- Alias for 'rebase-template' above"
	@echo "  merge-template    - Merge template's mane branch into current branch"
	@echo "  template-merge-   Alias for 'merge-template' above"
	@echo "  help           - Show this help message"
	@echo ""
	@echo "Examples for 'commit-fix' (three supported styles):"
	@echo "  1) Portable (recommended) - pass all flags via ARGS string:"
	@echo "       make commit-fix ARGS=\"--start-commit abc123 --end-commit def456 --ignore-blocks\""
	@echo "  2) Named variables - convenient and portable:"
	@echo "       make commit-fix START_COMMIT=abc123 END_COMMIT=def456 IGNORE_BLOCKS=1 NUMBER_SEARCH=10,11,23 NUMBER_OVERRIDE=10"
	@echo "  3) Less-portable - pass dash-args as goals (may be treated as make options on some systems):"
	@echo "       make commit-fix --start-commit abc123 --ignore-blocks"
	@echo ""

init:
	@chmod +x scripts/init.sh
	@./scripts/init.sh

fix-commits:
	@chmod +x scripts/fix-commits-wrapper.sh || true
	@chmod +x scripts/fix-commits.sh || true
	@./scripts/fix-commits-wrapper.sh $(EXTRA_ARGS) $(VAR_ARGS) $(ARGS)

commit-fix: fix-commits

setup: setup-py setup-ts

# Backend setup (Python)
setup-py:
ifeq ($(BACKEND),1)
	@echo "Setting up Python development environment..."
	uv sync
else
	@echo "No Python sources detected – skipping backend setup."
endif

# Frontend setup (TypeScript) - prefer yarn over npm
setup-ts:
ifeq ($(FRONTEND),1)
	@echo "Setting up frontend development environment..."
	@chmod +x scripts/setup_frontend.sh || true
	@./scripts/setup_frontend.sh "$(FRONTEND_DIR)"
else
	@echo "No frontend sources detected – skipping frontend setup."
endif

# Backwards compatible aliases for older naming
setup-backend: setup-py
setup-frontend: setup-ts

test: test-py test-ts

test-py:
ifeq ($(BACKEND),1)
	@echo "Running Python tests..."
	uv run pytest tests/
else
	@echo "No Python sources detected – skipping backend tests."
endif

test-ts:
ifeq ($(FRONTEND),1)
	@echo "Running frontend tests..."
	@if [ -n "$(FRONTEND_DIR)" ]; then \
		cd $(FRONTEND_DIR) && if [ -f package.json ]; then \
			if command -v npm >/dev/null 2>&1; then npm run test; elif command -v yarn >/dev/null 2>&1; then yarn test; else echo "No npm/yarn found"; fi; \
		fi; \
	fi
else
	@echo "No frontend sources detected – skipping frontend tests."
endif

test-coverage: test-coverage-py test-coverage-ts

test-coverage-py:
ifeq ($(BACKEND),1)
	@echo "Running Python tests with coverage..."
	uv run pytest tests/ --cov --cov-report=html --cov-report=term
	@echo "Python coverage report generated in htmlcov/"
else
	@echo "No Python sources detected – skipping backend coverage."
endif

test-coverage-ts:
ifeq ($(FRONTEND),1)
	@echo "Running frontend tests with coverage..."
	cd frontend && yarn test:coverage
	@echo "Frontend coverage report generated in frontend/coverage/"
else
	@echo "No frontend sources detected – skipping frontend coverage."
endif

lint: lint-py lint-ts

lint-py:
ifeq ($(BACKEND),1)
	@echo "Linting Python..."
	uv run ruff check custom_components/
	uv run ruff format --check custom_components/
else
	@echo "No Python sources detected – skipping backend lint."
endif

lint-ts:
ifeq ($(FRONTEND),1)
	@echo "Type checking / linting frontend..."
	@chmod +x scripts/ensure_node.sh || true
	@./scripts/ensure_node.sh || true
	@chmod +x scripts/frontend_lint.sh
	@./scripts/frontend_lint.sh "$(FRONTEND_DIR)"
else
	@echo "No frontend sources detected – skipping TypeScript lint."
endif

format: format-py format-ts

format-py:
ifeq ($(BACKEND),1)
	@echo "Formatting Python..."
	uv run ruff check --fix custom_components/ || true
	uv run ruff format custom_components/
	uv run ruff check --fix custom_components/
else
	@echo "No Python sources detected – skipping backend format."
endif

format-ts:
ifeq ($(FRONTEND),1)
	@echo "Formatting TypeScript..."
	@chmod +x scripts/ensure_node.sh || true
	@./scripts/ensure_node.sh || true
	@chmod +x scripts/frontend_format.sh
	@./scripts/frontend_format.sh "$(FRONTEND_DIR)"
else
	@echo "No frontend sources detected – skipping TypeScript format."
endif

build: build-frontend

build-frontend:
ifeq ($(FRONTEND),1)
	@echo "Building frontend..."
	@if [ -n "$(FRONTEND_DIR)" ]; then \
		cd $(FRONTEND_DIR) && if [ -f package.json ]; then \
			if command -v npm >/dev/null 2>&1; then npm install --silent && npm run build; elif command -v yarn >/dev/null 2>&1; then yarn install --silent && yarn build; else echo "No npm/yarn found"; fi; \
		fi; \
	fi
else
	@echo "No frontend sources detected – skipping build."
endif

commit:
	@chmod +x scripts/commit.sh
	@./scripts/commit.sh

commit-format:
	@chmod +x scripts/commit-format.sh
	@./scripts/commit-format.sh

release:
	@chmod +x scripts/ensure_node.sh || true
	@./scripts/ensure_node.sh || true
	@chmod +x scripts/release.sh
	@./scripts/release.sh

rebase-template:
	@chmod +x scripts/update-from-template.sh
	@./scripts/update-from-template.sh

template-rebase: rebase-template

merge-template:
	@chmod +x scripts/merge-from-template.sh
	@./scripts/merge-from-template.sh

template-merge: merge-template

check-slots:
	@chmod +x scripts/ensure_node.sh || true
	@./scripts/ensure_node.sh || true
	@if [ -n "$(FRONTEND_DIR)" ]; then \
		node scripts/check_slots.js "$(FRONTEND_DIR)"; \
	else \
		echo "No frontend directory detected; skipping slot checks."; \
	fi

%:
	@echo "Unknown target '$@'. Showing help:"
	@$(MAKE) help
