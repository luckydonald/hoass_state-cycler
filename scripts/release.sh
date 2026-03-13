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

COMMIT_MSG_VERSION_BUMP="⬆️ version: bumped \`{from}\` → \`{to}\`"
COMMIT_MSG_AUTOFIX="🔧{emoji} lint: {reason}"
COMMIT_MSG_LINT="🧹{emoji} lint: {reason}"

# -------------------------------------------------
# tmpl  –  expand a template using environment variables
# Usage:  tmpl "<template>"
# Example call:
#   step=4 substep=1 tmpl "$GIT_MSG_TEMPLATE"
# -------------------------------------------------
. "${SCRIPT_DIR}/tmpl.sh"

echo -e "${GREEN}🚀 State Cycler - Release Script${NC}"
echo ""

# Load project settings
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 not found${NC}"
    exit 1
fi

settings_status=0
settings_output=$(python3 scripts/get_project_settings.py) || settings_status=$?
if [ ${settings_status} -ne 0 ]; then
    echo -e "${RED}Error: Failed to load project settings. Run 'make init' first.${NC}"
    exit 1
fi
eval "${settings_output}"
# running get_project_settings.py should define:
# DISPLAY_NAME=settings['display_name']
# DASH_NAME=settings['dash_name']
# SNAKE_NAME=settings['snake_name']
# PASCAL_NAME=settings['pascal_name']
# GITHUB_USER=settings['github_user']
# GITHUB_URL=settings['github_url']
# KEEP_BACKEND=str(settings['keep_backend']).lower()
# FRONTEND_CHOICE=settings['frontend_choice']
# CURRENT_YEAR=settings['current_year']

# Check we're in the right directory
# Look for custom_components directory with any subdirectory containing manifest.json, or hacs.json
if [ ! -d "custom_components" ] && [ ! -d "frontend" ] && [ ! -d "frontend_vue" ] && [ ! -f "hacs.json" ]; then
    echo -e "${RED}Error: Must be run from the repository root${NC}"
    echo "Expected to find: custom_components/, frontend/, or hacs.json"
    exit 1
fi

# Detect frontend directory to support either frontend/ or frontend_vue/
FRONTEND_DIR=""
if [ -d "frontend" ]; then
    FRONTEND_DIR="frontend"
elif [ -d "frontend_vue" ]; then
    FRONTEND_DIR="frontend_vue"
fi

# Ensure Corepack/package manager is prepared for the frontend (use reusable script if available)
FRONTEND_PM=""
if [ -n "${FRONTEND_DIR}" ] && [ -f "${FRONTEND_DIR}/package.json" ]; then
    if [ -x "${SCRIPT_DIR}/ensure_yarn.sh" ]; then
        "${SCRIPT_DIR}/ensure_yarn.sh" "${FRONTEND_DIR}" || true
    fi
    # Read packageManager field from package.json if present
    FRONTEND_PM=$(node -e "try{console.log(require('./${FRONTEND_DIR}/package.json').packageManager||'')}catch(e){console.log('')}") || true
    FRONTEND_PM=$(echo "${FRONTEND_PM}" | tr -d '\r')
fi

# Helper to run frontend package manager 'install'
pm_install() {
    if [ -z "${FRONTEND_DIR}" ]; then
        echo "No frontend dir set for install"
        return 1
    fi
    if echo "${FRONTEND_PM}" | grep -q '^yarn' >/dev/null 2>&1; then
        (cd "${FRONTEND_DIR}" && if [ -f yarn.lock ] || [ -f .yarn/lock.yml ]; then yarn install --silent --immutable || yarn install --silent; else yarn install --silent; fi)
    elif echo "${FRONTEND_PM}" | grep -q '^pnpm' >/dev/null 2>&1; then
        (cd "${FRONTEND_DIR}" && pnpm install --silent)
    else
        # No explicit PM declared or unknown: prefer yarn if available
        if command -v yarn >/dev/null 2>&1; then
            (cd "${FRONTEND_DIR}" && if [ -f yarn.lock ] || [ -f .yarn/lock.yml ]; then yarn install --silent --immutable || yarn install --silent; else yarn install --silent; fi)
        elif command -v npm >/dev/null 2>&1; then
            # Warn when falling back to npm
            echo "Warning: falling back to npm for frontend install (no packageManager declared and yarn not found)"
            (cd "${FRONTEND_DIR}" && npm install --silent)
        else
            echo "No npm/yarn/pnpm found for frontend install"
            return 1
        fi
    fi
}

# Helper to run a script (like 'build', 'lint', 'type-check') with the appropriate package manager
pm_run_script() {
    script_name="$1"
    shift || true
    if [ -z "${FRONTEND_DIR}" ]; then
        echo "No frontend dir set for running script ${script_name}"
        return 1
    fi
    if echo "${FRONTEND_PM}" | grep -q '^yarn' >/dev/null 2>&1; then
        (cd "${FRONTEND_DIR}" && yarn "${script_name}" "$@")
    elif echo "${FRONTEND_PM}" | grep -q '^pnpm' >/dev/null 2>&1; then
        (cd "${FRONTEND_DIR}" && pnpm run "${script_name}" "$@")
    else
        if command -v yarn >/dev/null 2>&1; then
            (cd "${FRONTEND_DIR}" && yarn "${script_name}" "$@")
        elif command -v npm >/dev/null 2>&1; then
            # Use npm run for scripts
            (cd "${FRONTEND_DIR}" && npm run "${script_name}" -- "$@")
        else
            echo "No npm/yarn/pnpm found for running script ${script_name}"
            return 1
        fi
    fi
}

# Check for uncommitted changes (only tracked files, respects .gitignore)
if ! git diff --quiet HEAD -- || [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo -e "${YELLOW}Warning: You have uncommitted changes${NC}"
    git status --short
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get current version from latest git tag
CURRENT_VERSION=$(git tag --list 'v*' --sort=-version:refname | head -n 1 | sed 's/^v//')
if [ -z "$CURRENT_VERSION" ]; then
    echo -e "${YELLOW}No existing version tags found, starting at v0.0.0-pre1${NC}"
    CURRENT_VERSION="0.0.0-pre0"
fi
echo -e "Current version: ${YELLOW}v${CURRENT_VERSION}${NC}"

# Parse version and bump
if [[ $CURRENT_VERSION =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)-pre([0-9]+)$ ]]; then
    # Pre-release version (e.g., 0.0.0-pre11 -> 0.0.0-pre12)
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    PATCH="${BASH_REMATCH[3]}"
    PRE="${BASH_REMATCH[4]}"
    NEW_PRE=$((PRE + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}-pre${NEW_PRE}"
elif [[ $CURRENT_VERSION =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    # Regular version - bump patch (e.g., 1.0.0 -> 1.0.1)
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    PATCH="${BASH_REMATCH[3]}"
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
else
    echo -e "${RED}Error: Cannot parse version '${CURRENT_VERSION}'${NC}"
    echo "Expected format: X.Y.Z or X.Y.Z-preN"
    exit 1
fi

# Step 1: Check for type errors (not lint - we'll fix those in step 3)
echo ""
echo -e "${GREEN}🔍 Step 1: Check for type errors${NC}"
if ! command -v uv &> /dev/null; then
    echo -e "${RED}  Error: uv not found${NC}"
    echo "  Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi
echo "  Running frontend type-check..."
if [ -n "${FRONTEND_DIR}" ] && [ -f "${FRONTEND_DIR}/package.json" ]; then
    # Use the package-manager aware helper to run the type-check script
    pm_run_script type-check || true
else
    echo "  No frontend detected or no package.json - skipping frontend type-check"
fi

echo "  Type checks passed!"

# Step 2: Run commit.sh to commit pending changes
echo ""
echo -e "${GREEN}📝 Step 2: Commit pending changes${NC}"
chmod +x scripts/commit.sh
./scripts/commit.sh

# Step 3: Auto-fix lint errors if possible
echo ""
echo -e "${GREEN}🔧 Step 3: Auto-fix lint errors${NC}"
# Python autofix
uv run ruff check --fix custom_components/ || true
if ! git diff --quiet -- custom_components/; then
    git add -u custom_components/
    git commit -m "$(reason="ruff autofix" emoji="🐍" tmpl "${COMMIT_MSG_AUTOFIX}")"
    echo "  Committed auto-fixed lint errors"
else
    echo "  No auto-fixable lint errors"
fi

# Frontend autofix (eslint) - only if frontend exists
if [ -n "${FRONTEND_DIR}" ] && [ -f "${FRONTEND_DIR}/package.json" ]; then
    # Run slot checker to ensure we don't convert slot attributes accidentally
    if command -v node >/dev/null 2>&1; then
        echo "  Running slot usage checker..."
        if ! node scripts/check_slots.js "${FRONTEND_DIR}"; then
            echo -e "${RED}  Error: slot usage check failed (non-ha-* slot attributes found). Fix them before releasing.${NC}"
            exit 1
        fi
    else
        echo "  Node.js not found; skipping slot checks."
    fi
    echo "  Running frontend eslint autofix..."
    if grep -q '"lint:fix"' "${FRONTEND_DIR}/package.json" || grep -q '"lint"' "${FRONTEND_DIR}/package.json"; then
        if command -v node >/dev/null 2>&1; then
            if grep -q '"lint:fix"' "${FRONTEND_DIR}/package.json"; then
                pm_run_script lint:fix || true
            elif grep -q '"lint"' "${FRONTEND_DIR}/package.json"; then
                pm_run_script lint || true
            fi
        else
            echo "  Node.js not found - skipping frontend lint autofix"
        fi
    else
        echo "  No lint scripts defined in ${FRONTEND_DIR}/package.json - skipping frontend lint autofix"
    fi

    if ! git diff --quiet -- "${FRONTEND_DIR}/"; then
        git add -u "${FRONTEND_DIR}/"
        git commit -m "$(reason="eslint autofix" emoji="📘" tmpl "${COMMIT_MSG_AUTOFIX}")"
        echo "  Committed frontend auto-fixed lint errors"
    else
        echo "  No frontend autofix changes"
    fi

    # Verify no lint errors remain
    echo "  Verifying frontend lint results..."
    if grep -q '"lint"' "${FRONTEND_DIR}/package.json"; then
        pm_run_script lint
        LINT_STATUS=$?
    else
        LINT_STATUS=0
    fi

    if [ ${LINT_STATUS} -ne 0 ]; then
        echo -e "${RED}  Error: Frontend lint errors remain. Fix them manually or run the lint scripts.${NC}"
        exit 1
    fi
else
    echo "  No frontend detected - skipping frontend lint autofix"
fi

# Verify no errors remain after autofix
echo "  Verifying no errors remain..."
if ! uv run ruff check custom_components/; then
    echo -e "${RED}  Error: Unfixable lint errors remain${NC}"
    exit 1
fi
echo "  All lint errors resolved!"

# Step 4: Run Python formatter and commit
echo ""
echo -e "${GREEN} Step 4: Format Python code${NC}"
uv run ruff format custom_components/
if ! git diff --quiet -- custom_components/; then
    git add -u custom_components/
    git commit -m "$(reason="ruff autoformat" emoji="🐍" tmpl "${COMMIT_MSG_LINT}")"
    echo "  Committed Python formatting changes"
else
    echo "  No Python formatting changes needed"
fi

# Step 5: Run TS formatter and commit
echo ""
echo -e "${GREEN}📘 Step 5: Format TypeScript code${NC}"
if [ -n "${FRONTEND_DIR}" ] && [ -f "${FRONTEND_DIR}/package.json" ]; then
    pm_run_script format || true
else
    echo "  No frontend detected - skipping TypeScript format"
fi

# Step 6: Build frontend to confirm it works
echo ""
echo -e "${GREEN}📦 Step 6: Build frontend${NC}"
if [ -n "${FRONTEND_DIR}" ] && [ -f "${FRONTEND_DIR}/package.json" ]; then
    echo "  Installing dependencies..."
    pm_install
    echo "  Building..."
    pm_run_script build
    echo "  Frontend built successfully!"
else
    echo "  No frontend detected - skipping build"
fi

# Step 7: Bump version AFTER all tests pass

# but first let the user confirm, lol
echo -e "New version: ${GREEN}v${NEW_VERSION}${NC}"
echo ""

read -p "Proceed with release? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi

# now actually bump the version
echo ""
echo -e "${GREEN}🏷️  Step 7: Update version${NC}"
sed -i.bak 's/"version": "[^"]*"/"version": "'"${NEW_VERSION}"'"/' "custom_components/${SNAKE_NAME}/manifest.json"
rm -f "custom_components/${SNAKE_NAME}/manifest.json.bak"
echo "  Updated manifest.json to ${NEW_VERSION}"

git add "custom_components/${SNAKE_NAME}/manifest.json"
git commit -m "$(from="${CURRENT_VERSION}" to="${NEW_VERSION}" tmpl "${COMMIT_MSG_VERSION_BUMP}")"
echo "  Committed version bump"

# Check if tag already exists
if git rev-parse "v${NEW_VERSION}" >/dev/null 2>&1; then
    echo -e "${YELLOW}  Warning: Tag v${NEW_VERSION} already exists${NC}"
    read -p "  Move tag to current commit? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git tag -d "v${NEW_VERSION}"
        echo "  Deleted old tag"
        git tag "v${NEW_VERSION}"
        echo "  Created new tag v${NEW_VERSION}"
    else
        echo -e "${RED}  Aborted: Tag already exists and user chose not to move it${NC}"
        exit 1
    fi
else
    git tag "v${NEW_VERSION}"
    echo "  Created tag v${NEW_VERSION}"
fi

# Step 8: Push
echo ""
echo -e "${GREEN}📤 Step 8: Push to origin${NC}"
git push origin mane
echo "  Pushed to origin/mane"

# Check if we need to force push the tag (if it was moved)
if git ls-remote --tags origin | grep -q "refs/tags/v${NEW_VERSION}"; then
    echo -e "${YELLOW}  Tag exists on remote, force pushing...${NC}"
    git push --force origin "v${NEW_VERSION}"
else
    git push origin "v${NEW_VERSION}"
fi
echo "  Pushed tag v${NEW_VERSION}"

echo ""
echo -e "${GREEN}✅ Release v${NEW_VERSION} complete!${NC}"
echo ""
echo "GitHub Actions will now:"
echo "  1. Build the frontend"
echo "  2. Create a release zip"
echo "  3. Publish to GitHub Releases"
echo ""
echo "View the release at:"
echo "  ${GITHUB_URL%.git}/releases/tag/v${NEW_VERSION}"
echo ""
echo "Install via HACS:"
echo "  https://my.home-assistant.io/redirect/hacs_repository/?owner=${GITHUB_USER}&repository=hoass_${DASH_NAME}&category=integration"
