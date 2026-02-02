#!/usr/bin/env bash
# Ensure Corepack is enabled and the package manager declared in the frontend's package.json is activated.
# Usage: ./scripts/ensure_yarn.sh [<frontend-dir>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

FRONTEND_DIR_ARG="${1-}"
FRONTENDS=("frontend" "frontend_vue")
if [ -n "$FRONTEND_DIR_ARG" ]; then
  FRONTENDS=("$FRONTEND_DIR_ARG")
fi

SELECTED_FRONTEND=""
for d in "${FRONTENDS[@]}"; do
  if [ -d "$d" ] && [ -f "$d/package.json" ]; then
    SELECTED_FRONTEND="$d"
    break
  fi
done

if [ -z "$SELECTED_FRONTEND" ]; then
  echo "No frontend package.json found in ${FRONTENDS[*]} — skipping Corepack activation"
  exit 0
fi

echo "Selected frontend dir: $SELECTED_FRONTEND"

# Enable Corepack (no error if it's already enabled)
if command -v corepack >/dev/null 2>&1; then
  echo "Enabling Corepack"
  corepack enable || true
else
  echo "Corepack not available in PATH — attempting to continue and hope Node's corepack is present"
fi

# Read packageManager from the selected frontend package.json
PM=$(node -e "try{console.log(require('./$SELECTED_FRONTEND/package.json').packageManager||'')}catch(e){console.error('Could not read package.json'); process.exit(0)}") || true
PM=$(echo "$PM" | tr -d '\r' )

if [ -n "$PM" ]; then
  echo "Found packageManager in $SELECTED_FRONTEND/package.json: $PM"
  echo "Preparing and activating $PM via corepack"
  corepack prepare "$PM" --activate || true
else
  echo "No packageManager field found in $SELECTED_FRONTEND/package.json — skipping corepack prepare"
fi

# Print diagnostics
node -v || true
if command -v yarn >/dev/null 2>&1; then
  echo "yarn: $(yarn -v)"
fi
if command -v pnpm >/dev/null 2>&1; then
  echo "pnpm: $(pnpm -v)"
fi

echo "ensure_yarn.sh finished"
