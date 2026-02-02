#!/usr/bin/env bash
set -euo pipefail

# scripts/commit-format.sh
# Flow:
# 1) Do a normal commit (user staged changes) with provided message or default
# 2) Run format check; if formatting changes are needed, create a backup tag, run formatter, and amend the commit with formatted changes
# 3) If no formatter changes, exit normally

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}/.."

TAG_PREFIX="format-backup"

timestamp() {
  date +"%Y-%m-%d_%H-%M-%S"
}

pad() {
  printf "%03d" "$1"
}

usage() {
  echo "Usage: $0 [-m "commit message"]"
  exit 2
}

MSG=""
while getopts ":m:" opt; do
  case ${opt} in
    m) MSG="$OPTARG" ;;
    \?) usage ;;
  esac
done
shift $((OPTIND -1))

# If nothing staged, just exit
if git diff --cached --quiet; then
  echo "No staged changes to commit. Exiting."
  exit 0
fi

# 1) Do the normal commit
if [ -z "$MSG" ]; then
  read -p "Commit message: " MSG
  MSG=${MSG:-"chore: commit"}
fi

echo "Committing staged changes..."
git commit -m "$MSG"

# Save commit sha
LAST_COMMIT=$(git rev-parse --verify HEAD)

# 2) Check if formatting would change files
# Run format scripts (they are tolerant) but first run a dry-run to see if a change is needed
# For Python: use ruff --fix-check (ruff >=0.17?) - fallback to running ruff check and detect diffs
PY_FORMAT_CHANGED=0
TS_FORMAT_CHANGED=0

# Python format check
if [ -d "custom_components" ]; then
  if command -v ruff >/dev/null 2>&1; then
    if ! ruff check --fix --exit-zero custom_components/; then
      PY_FORMAT_CHANGED=1
    fi
  fi
fi

# TypeScript format check: run our frontend_format script but on a temp branch/state
if [ -d "frontend_vue" ] || [ -d "frontend" ]; then
  FRONTEND_DIR=frontend_vue
  if [ -d "frontend" ]; then FRONTEND_DIR=frontend; fi
  # Run formatter in a way we can detect files changed
  # Create a temporary worktree to run formatting without touching current working tree
  TMP_BRANCH="commit-format-temp-$(date +%s)"
  git branch "$TMP_BRANCH"
  git checkout "$TMP_BRANCH"
  set +e
  ./scripts/frontend_format.sh "$FRONTEND_DIR"
  set -e
  # Check if there are unstaged changes (format touched files)
  if ! git diff --quiet; then
    TS_FORMAT_CHANGED=1
  fi
  # return to previous branch
  git checkout -
  git branch -D "$TMP_BRANCH"
fi

if [ $PY_FORMAT_CHANGED -eq 0 ] && [ $TS_FORMAT_CHANGED -eq 0 ]; then
  echo "No formatting changes detected. Done."
  exit 0
fi

# If formatting changes detected in either, create a backup tag and apply formatting on current branch
COUNTER_FILE=".git/format_backup_counter"
COUNTER=1
if [ -f "$COUNTER_FILE" ]; then
  COUNTER=$(cat "$COUNTER_FILE" || echo 1)
  COUNTER=$((COUNTER + 1))
fi
printf "%d" "$COUNTER" > "$COUNTER_FILE"
PADDED=$(pad "$COUNTER")
TAG_NAME="${TAG_PREFIX}_$(timestamp)_${PADDED}"

# Create lightweight tag at last commit
git tag "$TAG_NAME" "$LAST_COMMIT"

echo "Created backup tag: $TAG_NAME at $LAST_COMMIT"

# Now run formatters for real and amend the last commit
if [ $PY_FORMAT_CHANGED -eq 1 ]; then
  echo "Running Python formatter (ruff)..."
  if command -v ruff >/dev/null 2>&1; then
    ruff check --fix custom_components/ || true
    ruff format custom_components/ || true
  fi
  git add -u custom_components/ || true
fi

if [ $TS_FORMAT_CHANGED -eq 1 ]; then
  echo "Running frontend formatter..."
  FRONTEND_DIR=frontend_vue
  if [ -d "frontend" ]; then FRONTEND_DIR=frontend; fi
  ./scripts/frontend_format.sh "$FRONTEND_DIR" || true
  git add -u "$FRONTEND_DIR" || true
fi

# Amend commit with formatted changes
if ! git diff --cached --quiet; then
  echo "Amending last commit with formatting changes..."
  git commit --amend --no-edit
  echo "Amended commit. Backup tag: $TAG_NAME"
else
  echo "Formatting produced no staged changes to amend."
fi

echo "Done."
