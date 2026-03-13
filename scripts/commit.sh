#!/usr/bin/env bash
set -e

# Resolve the full path of the script, even if it was called via a symlink
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do   # resolve $SOURCE until the file is no longer a symlink
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  # If $SOURCE was a relative symlink, prepend the directory where the symlink resides
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done

# Directory containing the script
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"

echo "Script directory: ${SCRIPT_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Commit message templates - now using unified format for all repos
COMMIT_PREFIX_TEMPLATE="📄TEMPLATE | "
COMMIT_MSG_ERRORS="🐞 ai: updated errors"
COMMIT_MSG_QUERY="🤌 ai: updated query"
COMMIT_MSG_STEP="✨ ai: [{padded_step}] {msg} ({substep}/{total_substeps})"
COMMIT_MSG_LOCK="🔏 Updated package versions for {lock_type}."

# Detect if we're in the template repository
REPO_DIR=$(basename "$(cd "$SCRIPT_DIR/.." && pwd)")
COMMIT_PREFIX=""
if echo "$REPO_DIR" | grep -qE "^hoass_(plugin[-_])?template"; then
    COMMIT_PREFIX="${COMMIT_PREFIX_TEMPLATE}"
    echo -e "${YELLOW}Template repository detected - using TEMPLATE prefix${NC}"
fi

# -------------------------------------------------
# tmpl  –  expand a template using environment variables
# Usage:  tmpl "<template>"
# Example call:
#   step=4 substep=1 tmpl "$GIT_MSG_TEMPLATE"
# -------------------------------------------------
. "${SCRIPT_DIR}/tmpl.sh"

echo -e "${GREEN}📝 State Cycler - Commit Script${NC}"
echo ""

# Check we're in the right directory
# Look for any of: custom_components/*/manifest.json, frontend/, scripts/ directory, or hacs.json
if [ ! -d "custom_components" ] && [ ! -d "frontend" ] && [ ! -d "frontend_vue" ] && [ ! -f "hacs.json" ]; then
    echo -e "${RED}Error: Must be run from the repository root${NC}"
    echo "Expected to find: custom_components/, frontend/, or hacs.json"
    exit 1
fi

# Print a quick git status summary so user can see if working tree is dirty
PORCELAIN_OUTPUT=$(git status --porcelain)
if [ -n "${PORCELAIN_OUTPUT}" ]; then
    echo -e "${YELLOW}Git working tree has uncommitted changes:${NC}"
    echo "${PORCELAIN_OUTPUT}"
    echo ""
else
    echo -e "${GREEN}Git working tree is clean${NC}"
fi

# If there are no unstaged changes and no staged changes, nothing to do -> exit
STAGED_OUTPUT=$(git diff --cached --name-only)
if [ -z "${PORCELAIN_OUTPUT}" ] && [ -z "${STAGED_OUTPUT}" ]; then
    echo -e "${YELLOW}No changes detected (working tree and index clean) — nothing to commit.${NC}"
    exit 0
fi

# Save any currently staged changes
STASH_STAGED=false
STAGED_FILES=""
if [ -n "$(git diff --cached --name-only)" ]; then
    echo -e "${YELLOW}Saving staged changes...${NC}"
    # Store the list of staged files
    STAGED_FILES=$(git diff --cached --name-only)
    echo "  Files to restore later:"
    echo "$STAGED_FILES" | sed 's/^/    - /'

    # Unstage them (this does NOT delete anything, just moves from staging to working directory)
    git reset HEAD --quiet
    echo "  Unstaged files (they remain in your working directory)"
    STASH_STAGED=true
fi

# Commit frontend lock files separately (frontend and frontend_vue)
# This ensures package lock updates are recorded with a focused commit message.
# Define frontend lock files once and reuse
FRONTEND_LOCK_FILES=(frontend/yarn.lock frontend/package-lock.json frontend_vue/yarn.lock frontend_vue/package-lock.json)

# Check if any frontend lock files changed or are untracked
if git diff --name-only | grep -Fxq -f <(printf "%s\n" "${FRONTEND_LOCK_FILES[@]}") || \
   git ls-files --others --exclude-standard | grep -Fxq -f <(printf "%s\n" "${FRONTEND_LOCK_FILES[@]}"); then
    echo -e "${GREEN}Committing frontend lock files...${NC}"
    # Add both possible frontend lock files if present; show status for each
    for f in "${FRONTEND_LOCK_FILES[@]}"; do
        if [ -f "$f" ]; then
            echo -e "  ${GREEN}Adding \`$f\`${NC}"
            git add "$f"
        else
            echo -e "  ${YELLOW}Missing: \`$f\`${NC}"
        fi
    done
    # Commit with templating
    git commit -m "${COMMIT_PREFIX}$(lock_type=\"frontend\" tmpl \"${COMMIT_MSG_LOCK}\")"
    echo "  Done"
else
    echo -e "${YELLOW}No frontend lock file changes to commit${NC}"
fi

# Commit backend uv.lock separately
if git diff --name-only | grep -qE '^uv.lock$' || git ls-files --others --exclude-standard | grep -qE '^uv.lock$'; then
    echo -e "${GREEN}Committing uv.lock...${NC}"
    git add uv.lock
    # Commit with templating
    git commit -m "${COMMIT_PREFIX}$(lock_type="backend" tmpl "${COMMIT_MSG_LOCK}")"
    echo "  Done"
else
    echo -e "${YELLOW}No uv.lock changes to commit${NC}"
fi

# Commit ai/query.md if it has changes
if git diff --name-only | grep -q "^ai/query.md$"; then
    echo -e "${GREEN}Committing ai/query.md...${NC}"
    echo "Showing diff for ai/query.md:"
    git --no-pager diff -- ai/query.md || true
    git add ai/query.md
    git commit -m "${COMMIT_PREFIX}${COMMIT_MSG_QUERY}"
    echo "  Done"
elif [ -f "ai/query.md" ] && git ls-files --others --exclude-standard | grep -q "^ai/query.md$"; then
    echo -e "${GREEN}Committing ai/query.md (new file)...${NC}"
    echo "Contents of new ai/query.md:"
    sed -n '1,200p' ai/query.md || true
    git add ai/query.md
    git commit -m "${COMMIT_PREFIX}${COMMIT_MSG_QUERY}"
    echo "  Done"
else
    echo -e "${YELLOW}No changes to ai/query.md${NC}"
fi

# Commit ai/errors.md if it has changes
if git diff --name-only | grep -q "^ai/errors.md$"; then
    echo -e "${GREEN}Committing ai/errors.md...${NC}"
    echo "Showing diff for ai/errors.md:"
    git --no-pager diff -- ai/errors.md || true
    git add ai/errors.md
    git commit -m "${COMMIT_PREFIX}${COMMIT_MSG_ERRORS}"
    echo "  Done"
elif [ -f "ai/errors.md" ] && git ls-files --others --exclude-standard | grep -q "^ai/errors.md$"; then
    echo -e "${GREEN}Committing ai/errors.md (new file)...${NC}"
    echo "Contents of new ai/errors.md:"
    sed -n '1,200p' ai/errors.md || true
    git add ai/errors.md
    git commit -m "${COMMIT_PREFIX}${COMMIT_MSG_ERRORS}"
    echo "  Done"
else
    echo -e "${YELLOW}No changes to ai/errors.md${NC}"
fi

# Commit state_cycler query/errors with diffs shown
if git diff --name-only | grep -q "^ai/state_cycler/query.md$"; then
    echo -e "${GREEN}Committing ai/state_cycler/query.md...${NC}"
    echo "Showing diff for ai/state_cycler/query.md:"
    git --no-pager diff -- ai/state_cycler/query.md || true
    git add ai/state_cycler/query.md
    git commit -m "${COMMIT_PREFIX_TEMPLATE}${COMMIT_MSG_QUERY}"
    echo "  Done"
elif [ -f "ai/state_cycler/query.md" ] && git ls-files --others --exclude-standard | grep -q "^ai/state_cycler/query.md$"; then
    echo -e "${GREEN}Committing ai/state_cycler/query.md (new file)...${NC}"
    sed -n '1,200p' ai/state_cycler/query.md || true
    git add ai/state_cycler/query.md
    git commit -m "${COMMIT_PREFIX_TEMPLATE}${COMMIT_MSG_QUERY}"
    echo "  Done"
fi

if git diff --name-only | grep -q "^ai/state_cycler/errors.md$"; then
    echo -e "${GREEN}Committing ai/state_cycler/errors.md...${NC}"
    echo "Showing diff for ai/state_cycler/errors.md:"
    git --no-pager diff -- ai/state_cycler/errors.md || true
    git add ai/state_cycler/errors.md
    git commit -m "${COMMIT_PREFIX_TEMPLATE}${COMMIT_MSG_ERRORS}"
    echo "  Done"
elif [ -f "ai/state_cycler/errors.md" ] && git ls-files --others --exclude-standard | grep -q "^ai/state_cycler/errors.md$"; then
    echo -e "${GREEN}Committing ai/state_cycler/errors.md (new file)...${NC}"
    sed -n '1,200p' ai/state_cycler/errors.md || true
    git add ai/state_cycler/errors.md
    git commit -m "${COMMIT_PREFIX_TEMPLATE}${COMMIT_MSG_ERRORS}"
    echo "  Done"
fi

# Restore staged changes before the final commit
if [ "$STASH_STAGED" = true ]; then
    echo -e "${YELLOW}Restoring staged changes...${NC}"
    # Re-stage the files that were originally staged
    # (They've been in the working directory this whole time, unchanged)
    RESTORED_COUNT=0
    echo "$STAGED_FILES" | while IFS= read -r file; do
        if [ -n "$file" ] && ([ -f "$file" ] || [ -d "$file" ]); then
            git add "$file"
            RESTORED_COUNT=$((RESTORED_COUNT + 1))
        fi
    done
    echo "  Re-staged files"
fi

# Check if there are any other changes to commit
if [ -n "$(git status --porcelain)" ]; then
    # Intelligently determine step and substep numbers from commit history
    # Look through recent commits to find the last relevant AI commit

    step=1
    substep=1
    found_running=false
    found_query_or_error=false

    # Read commit messages one by one.
    # Format: subject <TAB> parent-hashes (space-separated; >1 parent = merge commit)
    while IFS= read -r line; do
        commit_msg="${line%%	*}"
        parents="${line#*	}"

        # Stop at merge commits — scanning past a branch point gives wrong step numbers
        # and fix-commits would break trying to rebase over a merge.
        parent_count=$(echo "$parents" | wc -w | tr -d ' ')
        if [ "$parent_count" -gt 1 ]; then
            break
        fi

        # In non-template repos: stop the moment we hit a template-prefixed commit.
        # Those belong to this template's history, not the downstream project's.
        if [ -z "$COMMIT_PREFIX" ] && echo "$commit_msg" | grep -qF "$COMMIT_PREFIX_TEMPLATE"; then
            break
        fi

        # Check for "ai: updated query" or "ai: updated errors" FIRST
        if echo "$commit_msg" | grep -qE "(ai: updated query|ai: updated errors)"; then
            # Found a query/errors update - this means next commit should increment step
            found_query_or_error=true
            # Don't break - we need to find the last running commit to get the step number
            continue
        fi

        # Check for unified format: "✨ ai: [007] Any message… (2/5)" or "(2/X)"
        if echo "$commit_msg" | grep -qE "ai: \[[0-9]+\].*\([0-9]+/"; then
            # Extract step and substep from format
            last_step=$(echo "$commit_msg" | sed 's/.*ai: \[\([0-9]*\)\].*/\1/' | sed 's/^0*//')
            last_substep=$(echo "$commit_msg" | sed 's/.*(\([0-9]*\)\/.*/\1/')

            if [ -n "$last_step" ] && [ -n "$last_substep" ]; then
                if [ "$found_query_or_error" = true ]; then
                    # Found query/error before this running commit - increment step, reset substep
                    step=$((last_step + 1))
                    substep=1
                else
                    # No query/error - just increment substep
                    step=$last_step
                    substep=$((last_substep + 1))
                fi
                found_running=true
                break
            fi
        fi
    done < <(git log --format="%s%x09%P" -50)  # subject + TAB + parent hashes

    # If we didn't find any running commit, start fresh
    if [ "$found_running" = false ]; then
        step=1
        substep=1
    fi

    echo -e "${GREEN}Committing remaining changes as step ${step}-${substep}...${NC}"
    git add -u
    git add .  # Also add new files that aren't ignored
    # shellcheck disable=SC2034

    # Use unified template format with zero-padded step
    padded_step=$(printf "%03d" "$step")
    total_substeps="X"  # Unknown at this point
    msg="running…"  # Using … instead of ...
    git commit -m "${COMMIT_PREFIX}$(padded_step="$padded_step" substep="$substep" total_substeps="$total_substeps" msg="$msg" tmpl "${COMMIT_MSG_STEP}")"
    echo "  Done"
else
    echo -e "${YELLOW}No other changes to commit${NC}"
fi

echo ""
echo -e "${GREEN}✅ Commits complete!${NC}"
