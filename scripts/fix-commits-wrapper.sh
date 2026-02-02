#!/usr/bin/env bash
# If the script was invoked under /bin/sh (or another non-bash shell), re-exec under bash
if [ -z "${BASH_VERSION:-}" ]; then
  exec env bash "$0" "$@"
fi
set -euo pipefail

# Normalize common shorthand invocations to the canonical --number-search <n>
# Accepts: 81
#          -- 81
#          -- -n 81
#          -n 81
# and passes through other flags unchanged.

args=()
# preserve all input args
for a in "$@"; do
  args+=("$a")
done

out=()
i=0
n=${#args[@]}
while [ $i -lt $n ]; do
  a="${args[$i]}"
  case "$a" in
    --)
      # If next token is numeric, convert to --number-search <num>
      next="${args[$((i+1))]:-}"
      if [[ "$next" =~ ^[0-9]+$ ]]; then
        out+=("--number-search" "$next")
        i=$((i+2))
      else
        out+=("$a")
        i=$((i+1))
      fi
      ;;
    -n|--number|-N)
      next="${args[$((i+1))]:-}"
      if [[ "$next" =~ ^[0-9]+$ ]]; then
        out+=("--number-search" "$next")
        i=$((i+2))
      else
        out+=("$a")
        i=$((i+1))
      fi
      ;;
    --number-search)
      next="${args[$((i+1))]:-}"
      if [ -n "$next" ]; then
        out+=("$a" "$next")
        i=$((i+2))
      else
        out+=("$a")
        i=$((i+1))
      fi
      ;;
    *)
      if [[ "$a" =~ ^[0-9]+$ ]]; then
        out+=("--number-search" "$a")
        i=$((i+1))
      else
        out+=("$a")
        i=$((i+1))
      fi
      ;;
  esac
done

# Exec the real script (must be in scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Use "${out[@]:-}" to avoid unbound variable errors under 'set -u' when out is empty
exec "$SCRIPT_DIR/fix-commits.sh" "${out[@]:-}"
