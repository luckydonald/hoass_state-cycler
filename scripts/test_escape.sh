#!/usr/bin/env bash
set -euo pipefail

samples=(
  "simple"
  "contains\`backtick\`"
  "dollar\$VAR"
  "single'quote"
  $'multi line\nwith newline'
  "complex \$VAR \`cmd\` '\"mixed\"'"
)

printf "Per-argument escaping test:\n\n"
for s in "${samples[@]}"; do
  esc=$(printf "%s" "$s" | sed "s/'/'\\''/g")
  quoted="'$esc'"
  # Reconstruct via eval (safe because we control quoted which uses single quotes)
  reconstructed=$(eval "printf '%s' $quoted")
  printf "ORIG: [%s]\n" "$s"
  printf "QUOTED: %s\n" "$quoted"
  printf "RECON: [%s]\n" "$reconstructed"
  if [ "$s" = "$reconstructed" ]; then
    printf "RESULT: OK\n\n"
  else
    printf "RESULT: FAIL\n\n"
  fi
done

# Show a full printed command for visualization (join all samples into one printed command)
joined=""
for s in "${samples[@]}"; do
  esc=$(printf "%s" "$s" | sed "s/'/'\\''/g")
  joined="$joined '$esc'"
done
printf "Example printed command (copy/paste safe form):\n"
printf "%s\n" "./scripts/fix-commits.sh$joined"
