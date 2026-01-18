# Is this a frontend or backend project, or both?
# Set explicit (e.g. by `make lint FRONTEND=1 BACKEND=1`), or let the
# defaults detect the presence of the directories.
FRONTEND ?= $(if $(wildcard frontend),1,0)
BACKEND  ?= $(if $(wildcard custom_components),1,0)

.PHONY: release lint format build setup help commit init fix-commits

help:
	@echo "Plugin Template - Development Commands"
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
	@echo "  release        - Bump version, lint, build, and push release"
	@echo "  help           - Show this help message"

init:
	@chmod +x scripts/init.sh
	@./scripts/init.sh

fix-commits:
	@chmod +x scripts/fix-commits.sh
	@./scripts/fix-commits.sh

setup: setup-backend setup-frontend

setup-backend:
ifeq ($(BACKEND),1)
	@echo "Setting up Python development environment..."
	uv sync
else
	@echo "No Python sources detected – skipping backend setup."
endif

setup-frontend:
ifeq ($(FRONTEND),1)
	@echo "Setting up frontend development environment..."
	cd frontend && yarn install
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
	cd frontend && yarn test
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

else
	@echo "No frontend sources detected – skipping frontend setup."
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
	@echo "Type checking frontend..."
	cd frontend && yarn type-check
else
	@echo "No frontend sources detected – skipping TypeScript lint."
endif

format: format-py format-ts

format-py:
ifeq ($(BACKEND),1)
	@echo "Formatting Python..."
	uv run ruff format custom_components/
	uv run ruff check --fix custom_components/ || true
else
	@echo "No Python sources detected – skipping backend format."
endif

format-ts:
ifeq ($(FRONTEND),1)
	@echo "Formatting TypeScript..."
	cd frontend && yarn format
else
	@echo "No frontend sources detected – skipping TypeScript format."
endif

build: build-frontend

build-frontend:
ifeq ($(FRONTEND),1)
	@echo "Building frontend..."
	cd frontend && yarn install && yarn build
else
	@echo "No frontend sources detected – skipping build."
endif

commit:
	@chmod +x scripts/commit.sh
	@./scripts/commit.sh

release:
	@chmod +x scripts/release.sh
	@./scripts/release.sh

