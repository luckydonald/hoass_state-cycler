#!/usr/bin/env bash
# Small helper to setup the frontend: enable corepack/package manager and install deps.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

FRONTEND_DIR_ARG="${1:-frontend}"
if [ ! -d "$FRONTEND_DIR_ARG" ] || [ ! -f "$FRONTEND_DIR_ARG/package.json" ]; then
  echo "No frontend package.json found in $FRONTEND_DIR_ARG — skipping setup"
  exit 0
fi

# Ensure ensure_yarn.sh is invoked to activate Corepack and the declared package manager
if [ -x "$SCRIPT_DIR/ensure_yarn.sh" ]; then
  "$SCRIPT_DIR/ensure_yarn.sh" "$FRONTEND_DIR_ARG" || true
fi

cd "$FRONTEND_DIR_ARG"
# Prefer yarn if available
if command -v yarn >/dev/null 2>&1; then
  if [ -f yarn.lock ] || [ -f .yarn/lock.yml ]; then
    echo "Lockfile found, running immutable yarn install"
    yarn install --immutable
  else
    echo "No lockfile found, running regular yarn install"
    yarn install
  fi
elif command -v npm >/dev/null 2>&1; then
  npm install
else
  echo "No npm/yarn found"
fi

exit 0
