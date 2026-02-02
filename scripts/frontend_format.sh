#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/frontend_format.sh <frontend_dir>
FRONTEND_DIR="$1"

if [ -z "${FRONTEND_DIR}" ] || [ ! -f "${FRONTEND_DIR}/package.json" ]; then
  echo "No frontend detected or no package.json - skipping frontend format."
  exit 0
fi

cd "${FRONTEND_DIR}"

# Run slot checker prior to formatting
if command -v node >/dev/null 2>&1; then
  echo "Running slot usage checker..."
  if ! node ../scripts/check_slots.js .; then
    echo "Slot usage check failed: please fix non-ha-* slot attributes before formatting."
    exit 1
  fi
else
  echo "Node.js not found; cannot run slot checker. Proceeding without slot checks."
fi

# NOTE: Embedded HTML formatting via external script removed. We use html-eslint to lint embedded HTML.

# Helper: check if package.json has a script
has_script() {
  local name="$1"
  grep -q "\"${name}\"[[:space:]]*:[[:space:]]*\"" package.json >/dev/null 2>&1
}

# Helper: run npm/yarn script
run_script() {
  local name="$1"
  # Try to detect packageManager from package.json
  PM=""
  if command -v node >/dev/null 2>&1; then
    PM=$(node -e "try{console.log(require('./package.json').packageManager||'')}catch(e){console.log('')}") || true
    PM=$(echo "$PM" | tr -d '\r')
  fi
  # Prefer packageManager declared (yarn/pnpm), otherwise prefer yarn, then npm
  if echo "$PM" | grep -q '^yarn' >/dev/null 2>&1 || command -v yarn >/dev/null 2>&1; then
    echo "Running: yarn ${name}"
    yarn "${name}"
  elif echo "$PM" | grep -q '^pnpm' >/dev/null 2>&1 || command -v pnpm >/dev/null 2>&1; then
    echo "Running: pnpm run ${name}"
    pnpm run "${name}"
  elif command -v npm >/dev/null 2>&1; then
    echo "Running: npm run ${name}"
    npm run "${name}"
  else
    return 127
  fi
}

# Helper: run local binary (node_modules/.bin) or global fallback
run_local_or_global() {
  local cmd="${1}"
  shift
  local args=("$@")
  if [ -x "./node_modules/.bin/${cmd}" ]; then
    echo "Running local: ./node_modules/.bin/${cmd} ${args[*]}"
    ./node_modules/.bin/${cmd} "${args[@]}"
    return $?
  fi
  if command -v ${cmd} >/dev/null 2>&1; then
    echo "Running global: ${cmd} ${args[*]}"
    ${cmd} "${args[@]}"
    return $?
  fi
  return 127
}

STATUS=0

# 1) Lint autofix: prefer package script lint:fix, else try eslint --fix
if has_script "lint:fix"; then
  if ! run_script "lint:fix"; then STATUS=$?; fi
else
  # try eslint --fix via local/global binary
  if run_local_or_global "eslint" "--ext" ".ts,.tsx,.js,.vue" "--fix" "." >/dev/null 2>&1; then
    if ! run_local_or_global "eslint" "--ext" ".ts,.tsx,.js,.vue" "--fix" "."; then STATUS=$?; fi
  else
    echo "No lint:fix script and no eslint binary found. Skipping lint autofix."
  fi
fi

# 2) Formatter: prefer package script 'format', else try dprint or prettier
if has_script "format"; then
  if ! run_script "format"; then STATUS=$((STATUS|$?)); fi
else
  # try dprint
  if run_local_or_global "dprint" "fmt" >/dev/null 2>&1; then
    if ! run_local_or_global "dprint" "fmt"; then STATUS=$((STATUS|$?)); fi
  elif run_local_or_global "prettier" "--write" "." >/dev/null 2>&1; then
    if ! run_local_or_global "prettier" "--write" "."; then STATUS=$((STATUS|$?)); fi
  else
    echo "No format script and no known formatter (dprint/prettier) found. Skipping format."
  fi
fi

# 3) Validate typescript
if has_script "type-check"; then
  if ! run_script "type-check"; then STATUS=$((STATUS|$?)); fi
else
  if run_local_or_global "vue-tsc" "-b" >/dev/null 2>&1; then
    if ! run_local_or_global "vue-tsc" "-b"; then STATUS=$((STATUS|$?)); fi
  elif run_local_or_global "tsc" "-p" "." >/dev/null 2>&1; then
    if ! run_local_or_global "tsc" "-p" "."; then STATUS=$((STATUS|$?)); fi
  else
    echo "No type-check script or suitable local/global binary (vue-tsc/tsc) found. Skipping type-check."
  fi
fi

exit ${STATUS}
