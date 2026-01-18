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
COMMIT_MSG_LINT="🔧 lint: {reason}"

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

settings_output=$(python3 scripts/get_project_settings.py 2>/dev/null)
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to load project settings. Run 'make init' first.${NC}"
    exit 1
fi
eval "$settings_output"
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

echo -e "New version: ${GREEN}v${NEW_VERSION}${NC}"
echo ""

read -p "Proceed with release? (Y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
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
cd frontend
yarn type-check
cd ..
echo "  Type checks passed!"

# Step 2: Run commit.sh to commit pending changes
echo ""
echo -e "${GREEN}📝 Step 2: Commit pending changes${NC}"
chmod +x scripts/commit.sh
./scripts/commit.sh

# Step 3: Auto-fix lint errors if possible
echo ""
echo -e "${GREEN}🔧 Step 3: Auto-fix lint errors${NC}"
uv run ruff check --fix custom_components/
if ! git diff --quiet -- custom_components/; then
    git add -u custom_components/
    git commit -m "$(reason="ruff autofix" tmpl "${COMMIT_MSG_LINT}")"
    echo "  Committed auto-fixed lint errors"
else
    echo "  No auto-fixable lint errors"
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
echo -e "${GREEN}🐍 Step 4: Format Python code${NC}"
uv run ruff format custom_components/
if ! git diff --quiet -- custom_components/; then
    git add -u custom_components/
    git commit -m "$(reason="ruff" tmpl "${COMMIT_MSG_LINT}")"
    echo "  Committed Python formatting changes"
else
    echo "  No Python formatting changes needed"
fi

# Step 5: Run TS formatter and commit
echo ""
echo -e "${GREEN}📘 Step 5: Format TypeScript code${NC}"
cd frontend
yarn format
cd ..
if ! git diff --quiet -- frontend/; then
    git add -u frontend/
    git commit -m "$(reason="ts" tmpl "${COMMIT_MSG_LINT}")"
    echo "  Committed TypeScript formatting changes"
else
    echo "  No TypeScript formatting changes needed"
fi

# Step 6: Build frontend to confirm it works
echo ""
echo -e "${GREEN}📦 Step 6: Build frontend${NC}"
cd frontend
echo "  Installing dependencies..."
yarn install --silent
echo "  Building..."
yarn build
cd ..
echo "  Frontend built successfully!"

# Step 7: Bump version AFTER all tests pass
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
