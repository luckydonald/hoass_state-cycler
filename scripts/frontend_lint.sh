#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/frontend_lint.sh <frontend_dir>
FRONTEND_DIR="$1"

if [ -z "${FRONTEND_DIR}" ] || [ ! -f "${FRONTEND_DIR}/package.json" ]; then
  echo "No frontend detected or no package.json - skipping frontend lint."
  exit 0
fi

cd "${FRONTEND_DIR}"

# Run slot checker to ensure only ha-* elements use slot attributes
if command -v node >/dev/null 2>&1; then
  echo "Running slot usage checker..."
  if ! node ../scripts/check_slots.js .; then
    echo "Slot usage check failed: please fix non-ha-* slot attributes before linting."
    exit 1
  fi
else
  echo "Node.js not found; cannot run slot checker. Proceeding without slot checks."
fi

# Helper: check if package.json has a script
has_script() {
  local name="$1"
  # Use POSIX whitespace class to be portable
  grep -q "\"${name}\"[[:space:]]*:[[:space:]]*\"" package.json >/dev/null 2>&1
}

# Helper: run npm/yarn script
run_script() {
  local name="$1"
  if command -v npm >/dev/null 2>&1; then
    echo "Running: npm run ${name}"
    npm run "${name}"
  elif command -v yarn >/dev/null 2>&1; then
    echo "Running: yarn ${name}"
    yarn "${name}"
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

# 1) Type check: prefer script, else try local binaries (vue-tsc or tsc)
if has_script "type-check"; then
  if ! run_script "type-check"; then STATUS=$?; fi
else
  if ! run_local_or_global "vue-tsc" "-b" >/dev/null 2>&1; then
    if ! run_local_or_global "tsc" "-p" "." >/dev/null 2>&1; then
      echo "No type-check script or suitable local/global binary (vue-tsc/tsc) found. Skipping type-check."
    else
      if ! run_local_or_global "tsc" "-p" "."; then STATUS=$?; fi
    fi
  else
    if ! run_local_or_global "vue-tsc" "-b"; then STATUS=$?; fi
  fi
fi

# 2) Lint: prefer script, else try local/global eslint
if has_script "lint"; then
  if ! run_script "lint"; then STATUS=$((STATUS|$?)); fi
else
  # run eslint on src files
  if run_local_or_global "eslint" "--ext" ".ts,.tsx,.js,.vue" "." >/dev/null 2>&1; then
    if ! run_local_or_global "eslint" "--ext" ".ts,.tsx,.js,.vue" "."; then STATUS=$((STATUS|$?)); fi
  else
    echo "No lint script and no eslint binary found. Skipping lint."
  fi
fi

exit ${STATUS}
