#!/usr/bin/env bash
set -euo pipefail

REQUIRED_MAJOR=24

# If NVM_DIR is set, source nvm
if [ -n "${NVM_DIR-}" ] && [ -s "${NVM_DIR}/nvm.sh" ]; then
  # shellcheck disable=SC1090
  . "${NVM_DIR}/nvm.sh"
fi

# Fallback: try common nvm location
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck disable=SC1090
  . "$HOME/.nvm/nvm.sh"
fi

# If nvm exists, try to use/install Node 24
if command -v nvm >/dev/null 2>&1; then
  # Check if Node 24 is installed in nvm
  if ! nvm ls 24 >/dev/null 2>&1; then
    echo "Node 24 not found in nvm. Installing Node 24 via nvm..."
    nvm install 24
  fi
  echo "Switching to Node 24 via nvm"
  nvm use 24 >/dev/null 2>&1 || true
fi

# Now ensure node binary is available
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js not found in PATH. Please install Node ${REQUIRED_MAJOR} or ensure nvm is available."
  exit 2
fi

NODE_VER=$(node -v)
NODE_VER=${NODE_VER#v}
NODE_MAJOR=${NODE_VER%%.*}

if [ "$NODE_MAJOR" -lt "$REQUIRED_MAJOR" ]; then
  echo "Node ${REQUIRED_MAJOR} or newer is required. Detected: v${NODE_VER}"
  echo "If you use nvm: 'nvm install ${REQUIRED_MAJOR} && nvm use ${REQUIRED_MAJOR}'"
  exit 3
fi

# success
exit 0
