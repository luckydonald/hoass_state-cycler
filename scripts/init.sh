#!/usr/bin/env bash
# ============================================================================
# Home Assistant Plugin Template Initializer
# ============================================================================
#
# This script initializes a new Home Assistant plugin from this template repository.
# It will:
#   1. Ask for your plugin name (display name for UI)
#   2. Calculate and confirm lowercase-dash version (for filenames)
#   3. Calculate and confirm snake_case version (for Python modules)
#   4. Generate GitHub repository URL
#   5. Optionally remove Python backend files
#   6. Choose frontend framework (vue or plain)
#   7. Replace all plugin template strings with your plugin names
#   8. Rename directories appropriately
#
# Usage:
#   git clone https://github.com/luckydonald/hoass_plugin-template hoass_<your-plugin-name>
#   cd hoass_<your-plugin-name>/
#   ./scripts/init.sh
#
# Example:
#   Plugin Display Name: My Custom Widget
#   Lowercase-dash:      my-custom-widget
#   Snake_case:          my_custom_widget
#
# ============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Prompt helper: read from terminal if available, otherwise fall back to default
# Usage: result=$(prompt_default "Prompt text" "default")
prompt_default() {
    local prompt="$1"
    local default="$2"
    local ans=""

    # Prefer reading from /dev/tty so we don't consume process-substitution stdin
    if [ -e /dev/tty ] && [ -r /dev/tty ]; then
        # shellcheck disable=SC2034
        if read -r -p "$prompt" ans </dev/tty; then :; else ans="$default"; fi
    elif [ -t 0 ]; then
        # fallback: stdin is a TTY
        if read -r -p "$prompt" ans; then :; else ans="$default"; fi
    else
        # Non-interactive: use default
        ans="$default"
    fi

    # Apply default when empty
    if [ -z "$ans" ]; then
        ans="$default"
    fi
    echo "$ans"
}

# Function to convert string to lowercase-dash format
to_lowercase_dash() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

# Function to convert string to snake_case format
to_snake_case() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]/_/g' | sed 's/__*/_/g' | sed 's/^_//' | sed 's/_$//'
}

# Function to convert string to PascalCase format
to_pascal_case() {
    echo "$1" | sed -E 's/[^a-zA-Z0-9]+/ /g' | awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) tolower(substr($i,2))}}1' | sed 's/ //g'
}

# Function to extract plugin name from folder name
extract_plugin_name_from_folder() {
    local folder_name=$(basename "$PWD")

    # Strip common prefixes (case insensitive)
    local name="$folder_name"
    name=$(echo "$name" | sed -E 's/^(ha|hacs|hoass|homeassistant)[-_]//i')

    # Convert underscores and dashes to spaces for display name
    name=$(echo "$name" | sed 's/[-_]/ /g')

    # Capitalize each word
    name=$(echo "$name" | awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1')

    echo "$name"
}

# Function to safely move/merge directories
safe_move_directory() {
    local src=$1
    local dest=$2
    local desc=$3

    if [ ! -d "$src" ]; then
        print_warning "Source directory $src not found, skipping"
        return 0
    fi

    if [ -d "$dest" ]; then
        print_warning "$desc directory already exists at: $dest"
        print_info "Will copy any new files from template..."

        # Find files in source that don't exist in dest
        local new_files=()
        while IFS= read -r -d '' file; do
            local rel_path="${file#$src/}"
            if [ ! -f "$dest/$rel_path" ]; then
                new_files+=("$rel_path")
            fi
        done < <(find "$src" -type f -print0)

        if [ ${#new_files[@]} -eq 0 ]; then
            print_info "No new files to copy from template"
            rm -rf "$src"
            return 0
        fi

        print_info "Found ${#new_files[@]} new file(s) in template:"
        for file in "${new_files[@]}"; do
            echo "  - $file"
        done

        read -p "Copy these files to your plugin? (y/n/selective) [y]: " COPY_CHOICE
        COPY_CHOICE=${COPY_CHOICE:-y}

        if [[ "$COPY_CHOICE" =~ ^[Yy]$ ]]; then
            # Copy all new files
            for file in "${new_files[@]}"; do
                local src_file="$src/$file"
                local dest_file="$dest/$file"
                mkdir -p "$(dirname "$dest_file")"
                cp "$src_file" "$dest_file"
                print_success "Copied: $file"
            done
        elif [[ "$COPY_CHOICE" =~ ^[Ss]$ ]]; then
            # Ask for each file
            for file in "${new_files[@]}"; do
                read -p "Copy $file? (y/n) [y]: " COPY_FILE
                COPY_FILE=${COPY_FILE:-y}
                if [[ "$COPY_FILE" =~ ^[Yy]$ ]]; then
                    local src_file="$src/$file"
                    local dest_file="$dest/$file"
                    mkdir -p "$(dirname "$dest_file")"
                    cp "$src_file" "$dest_file"
                    print_success "Copied: $file"
                else
                    print_info "Skipped: $file"
                fi
            done
        else
            print_info "Skipped copying new files"
        fi

        # Remove source directory
        rm -rf "$src"
    else
        # Simple rename
        mv "$src" "$dest"
        print_success "Renamed $src/ to $dest/"
    fi
}

# Function to set up README files
setup_readme_files() {
    if [ ! -f "scripts/README_PROJECT_TEMPLATE.md" ]; then
        print_warning "README_PROJECT_TEMPLATE.md not found in scripts/"
        return
    fi

    if [ -f "README.md" ] && ! grep -q "init.sh" "README.md" 2>/dev/null; then
        print_info "README.md exists but is not the template version - skipping README setup"
        return
    fi

    if [ -f "README.md" ] && grep -q "$SNAKE_NAME\|$DASH_NAME\|$DISPLAY_NAME" "README.md" 2>/dev/null; then
        print_info "README.md appears to be already customized - leaving it unchanged"
        return
    fi

    print_info "README.md is the template version - renaming to README_REPO_TEMPLATE.md"
    mv "README.md" "README_REPO_TEMPLATE.md" 2>/dev/null || true  # Overwrite if exists
    print_success "Renamed README.md → README_REPO_TEMPLATE.md"

    print_info "Moving README_PROJECT_TEMPLATE.md to README.md"
    cp "scripts/README_PROJECT_TEMPLATE.md" "README.md"
    print_success "Copied /scripts/README_PROJECT_TEMPLATE.md → /README.md"

    # Process the new README.md with replacements
    replace_in_file "README.md"
}

# Function to set up CLAUDE.md
setup_claude_md() {
    if [ ! -f "scripts/CLAUDE_PROJECT_TEMPLATE.md" ]; then
        print_warning "CLAUDE_PROJECT_TEMPLATE.md not found in scripts/ - skipping CLAUDE.md setup"
        return
    fi

    # Not the template version if the marker is absent
    if [ -f "CLAUDE.md" ] && ! grep -q "TEMPLATE_CLAUDE_MD" "CLAUDE.md" 2>/dev/null; then
        print_info "CLAUDE.md exists but is not the template version - skipping CLAUDE.md setup"
        return
    fi

    # Already customized with the new plugin name
    if [ -f "CLAUDE.md" ] && grep -q "$SNAKE_NAME\|$DASH_NAME\|$DISPLAY_NAME" "CLAUDE.md" 2>/dev/null \
        && ! grep -q "TEMPLATE_CLAUDE_MD" "CLAUDE.md" 2>/dev/null; then
        print_info "CLAUDE.md appears to be already customized - leaving it unchanged"
        return
    fi

    if [ -f "CLAUDE.md" ]; then
        print_info "CLAUDE.md is the template version - renaming to CLAUDE_REPO_TEMPLATE.md"
        mv "CLAUDE.md" "CLAUDE_REPO_TEMPLATE.md"
        print_success "Renamed CLAUDE.md → CLAUDE_REPO_TEMPLATE.md"
    fi

    print_info "Copying scripts/CLAUDE_PROJECT_TEMPLATE.md to CLAUDE.md"
    cp "scripts/CLAUDE_PROJECT_TEMPLATE.md" "CLAUDE.md"
    print_success "Copied scripts/CLAUDE_PROJECT_TEMPLATE.md → CLAUDE.md"

    replace_in_file "CLAUDE.md"
}

print_header "Home Assistant Plugin Template Initializer"

# Get the repository root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    print_error "Not in a git repository!"
    print_info "Initialize git first with: git init"
    exit 1
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    print_warning "You have uncommitted changes:"
    echo ""
    git status --short
    echo ""

    read -p "Would you like to commit these changes before initializing? (y/n) [n]: " COMMIT_BEFORE
    COMMIT_BEFORE=${COMMIT_BEFORE:-n}

    if [[ "$COMMIT_BEFORE" =~ ^[Yy]$ ]]; then
        echo ""
        read -p "Enter commit message: " COMMIT_MSG

        if [ -z "$COMMIT_MSG" ]; then
            print_error "Commit message cannot be empty!"
            exit 1
        fi

        print_info "Staging all changes..."
        git add -A

        print_info "Committing..."
        git commit -m "$COMMIT_MSG"
        print_success "Changes committed"
        echo ""
    else
        print_warning "Continuing with uncommitted changes..."
        print_warning "You may want to commit or stash them first"
        echo ""
        read -p "Continue anyway? (y/n) [n]: " CONTINUE_ANYWAY
        CONTINUE_ANYWAY=${CONTINUE_ANYWAY:-n}

        if [[ ! "$CONTINUE_ANYWAY" =~ ^[Yy]$ ]]; then
            print_info "Initialization cancelled"
            exit 0
        fi
    fi
fi

# Safety check: ensure this is the plugin_template repository OR already initialized
ALREADY_INITIALIZED=false
if [ -d "custom_components/plugin_template" ] || [ -d "frontend_vue" ] || [ -d "frontend_plain" ]; then
    # This is the template - first time initialization
    ALREADY_INITIALIZED=false
elif [ -d "custom_components" ] && [ "$(ls -A custom_components)" ]; then
    # Has custom_components with content - likely already initialized
    ALREADY_INITIALIZED=true
    print_warning "This appears to be an already initialized plugin"
    print_info "Re-running will update files and add any new template files"
else
    print_error "This doesn't appear to be a valid template or initialized repository!"
    exit 1
fi

# Detect existing plugin name if already initialized
if [ "$ALREADY_INITIALIZED" = true ]; then
    # Try to detect existing plugin name from custom_components
    EXISTING_SNAKE=$(ls -1 custom_components | head -n 1)
    if [ -n "$EXISTING_SNAKE" ] && [ "$EXISTING_SNAKE" != "plugin_template" ]; then
        print_info "Detected existing plugin: $EXISTING_SNAKE"
        # Read from manifest.json if it exists
        if [ -f "custom_components/$EXISTING_SNAKE/manifest.json" ]; then
            EXISTING_DISPLAY=$(grep -oP '"name":\s*"\K[^"]+' "custom_components/$EXISTING_SNAKE/manifest.json" 2>/dev/null || echo "")
            [ -n "$EXISTING_DISPLAY" ] && print_info "Existing display name: $EXISTING_DISPLAY"
        fi
    fi
fi

print_info "Working directory: $REPO_ROOT"

# Load existing project settings if available (pre-fill prompts)
SETTINGS_LOADED=false
if [ -f "scripts/get_project_settings.py" ]; then
    if python3 scripts/get_project_settings.py >/dev/null 2>&1; then
        print_info "Found existing project settings (scripts/init.json), pre-filling prompts"
        # This script prints export VAR=... lines; eval them into the environment
        eval "$(python3 scripts/get_project_settings.py)"
        SETTINGS_LOADED=true
    else
        print_info "scripts/get_project_settings.py found but could not load scripts/init.json (it may be missing or invalid)"
    fi
fi

# Step 1: Get the display name (UI name)
print_info "Step 1: Plugin Display Name"
echo "This is the name that will be shown in the Home Assistant UI."

# Try to deduce name from folder or existing settings
if [ -n "${DISPLAY_NAME:-}" ]; then
    # When DISPLAY_NAME is already set from previous init.json, use it as the prompt default
    FOLDER_DEFAULT="$DISPLAY_NAME"
else
    FOLDER_DEFAULT=$(extract_plugin_name_from_folder)
fi

if [ -n "$FOLDER_DEFAULT" ]; then
    echo "Example: 'My Custom Widget'"
    echo ""
    # Read into a temporary variable so we don't overwrite an already loaded DISPLAY_NAME when the user presses Enter
    read -p "Enter plugin display name [$FOLDER_DEFAULT]: " INPUT_DISPLAY_NAME
    if [ -n "$INPUT_DISPLAY_NAME" ]; then
        DISPLAY_NAME="$INPUT_DISPLAY_NAME"
    else
        DISPLAY_NAME=${DISPLAY_NAME:-$FOLDER_DEFAULT}
    fi
else
    echo "Example: 'My Custom Widget'"
    echo ""
    read -p "Enter plugin display name: " INPUT_DISPLAY_NAME
    DISPLAY_NAME=${INPUT_DISPLAY_NAME}
fi

if [ -z "$DISPLAY_NAME" ]; then
    print_error "Display name cannot be empty!"
    exit 1
fi

print_success "Display name: $DISPLAY_NAME"

# Step 2: Get the lowercase-dash name
print_info "\nStep 2: Lowercase-Dash Name"
echo "This is used for custom component names and filenames."
echo "Example: 'my-custom-widget' (for <my-custom-widget-card>, my-custom-widget-card.js, etc.)"
# Compute default from display name, but respect existing DASH_NAME loaded from settings
DEFAULT_DASH=$(to_lowercase_dash "$DISPLAY_NAME")
echo ""
read -p "Enter lowercase-dash name [$DEFAULT_DASH]: " INPUT_DASH
if [ -n "$INPUT_DASH" ]; then
    DASH_NAME="$INPUT_DASH"
else
    DASH_NAME=${DASH_NAME:-$DEFAULT_DASH}
fi

print_success "Lowercase-dash name: $DASH_NAME"

# Step 3: Get the snake_case name
print_info "\nStep 3: Snake_Case Name"
echo "This is used for Python module names, integration domain, sensor names, etc."
echo "Example: 'my_custom_widget'"
# Compute default from dash name, but respect existing SNAKE_NAME loaded from settings
DEFAULT_SNAKE=$(to_snake_case "$DASH_NAME")
echo ""
read -p "Enter snake_case name [$DEFAULT_SNAKE]: " INPUT_SNAKE
if [ -n "$INPUT_SNAKE" ]; then
    SNAKE_NAME="$INPUT_SNAKE"
else
    SNAKE_NAME=${SNAKE_NAME:-$DEFAULT_SNAKE}
fi

print_success "Snake_case name: $SNAKE_NAME"

# Step 4: Get GitHub username
print_info "\nStep 4: GitHub Username"
echo "This is your GitHub username for the repository URL."
echo ""
read -p "Enter GitHub username [luckydonald]: " INPUT_GITHUB
GITHUB_USER=${INPUT_GITHUB:-${GITHUB_USER:-luckydonald}}

print_success "GitHub username: $GITHUB_USER"

# Step 5: Construct GitHub URL
GITHUB_URL="https://github.com/${GITHUB_USER}/hoass_${DASH_NAME}.git"
print_info "\nStep 5: GitHub Repository"
print_success "GitHub URL: $GITHUB_URL"

# Step 6: Ask about Python backend
print_info "\nStep 6: Python Backend"
read -p "Do you need a Python backend? (y/n) [y]: " NEED_BACKEND
NEED_BACKEND=${NEED_BACKEND:-y}

if [[ "$NEED_BACKEND" =~ ^[Yy]$ ]]; then
    print_success "Keeping Python backend files"
    KEEP_BACKEND=true
else
    print_warning "Python backend files will be removed"
    KEEP_BACKEND=false
fi

# Clean up lock files for backend if this is the first run
if [ "$KEEP_BACKEND" = true ] && [ "$ALREADY_INITIALIZED" = false ]; then
    if [ -f "uv.lock" ]; then
        rm -f "uv.lock"
        print_success "Removed uv.lock (will be regenerated)"
    fi
fi

# Step 7: Ask about frontend choice
print_info "\nStep 7: Frontend Framework"
echo "Choose your frontend framework:"

# Check which frontend directories exist
# On first run: frontend_vue/ exists
# On re-run: frontend/ exists (already renamed)
HAS_VUE=false
HAS_PLAIN=false
[ -d "frontend_vue" ] && HAS_VUE=true
[ -d "frontend" ] && HAS_VUE=true  # Already initialized
[ -d "frontend_plain" ] && HAS_PLAIN=true

if [ "$HAS_VUE" = true ]; then
    if [ -d "frontend_vue" ]; then
        echo "  vue   - Vue.js framework (from frontend_vue/)"
    else
        echo "  vue   - Vue.js framework (keep existing frontend/)"
    fi
fi
# Uncomment when frontend_plain is implemented:
# if [ "$HAS_PLAIN" = true ]; then
#     echo "  plain - Plain TypeScript (from frontend_plain/)"
# fi
echo "  none  - No frontend (backend-only plugin)"

# Determine default based on what exists
if [ "$HAS_VUE" = true ]; then
    DEFAULT_FRONTEND="vue"
# Uncomment when frontend_plain is implemented:
# elif [ "$HAS_PLAIN" = true ]; then
#     DEFAULT_FRONTEND="plain"
else
    DEFAULT_FRONTEND="none"
fi

echo ""
# Build the choice prompt dynamically
CHOICES=""
[ "$HAS_VUE" = true ] && CHOICES="vue"
# Uncomment when frontend_plain is implemented:
# [ "$HAS_PLAIN" = true ] && CHOICES="${CHOICES:+$CHOICES/}plain"
CHOICES="${CHOICES:+$CHOICES/}none"

read -p "Enter frontend choice ($CHOICES) [$DEFAULT_FRONTEND]: " FRONTEND_CHOICE
FRONTEND_CHOICE=${FRONTEND_CHOICE:-$DEFAULT_FRONTEND}

# Validate choice
if [[ "$FRONTEND_CHOICE" == "vue" && "$HAS_VUE" = false ]]; then
    print_error "frontend_vue/ or frontend/ directory does not exist"
    exit 1
# Uncomment when frontend_plain is implemented:
# elif [[ "$FRONTEND_CHOICE" == "plain" && "$HAS_PLAIN" = false ]]; then
#     print_error "frontend_plain/ directory does not exist"
#     exit 1
elif [[ "$FRONTEND_CHOICE" != "vue" && "$FRONTEND_CHOICE" != "none" ]]; then
    # Uncomment when frontend_plain is implemented:
    # elif [[ "$FRONTEND_CHOICE" != "vue" && "$FRONTEND_CHOICE" != "plain" && "$FRONTEND_CHOICE" != "none" ]]; then
    print_error "Invalid frontend choice. Must be 'vue' or 'none'"
    # Uncomment when frontend_plain is implemented:
    # print_error "Invalid frontend choice. Must be 'vue', 'plain', or 'none'"
    exit 1
fi

if [ "$FRONTEND_CHOICE" = "none" ]; then
    print_warning "No frontend will be configured"
else
    print_success "Frontend choice: $FRONTEND_CHOICE"
fi

# Summary
print_header "Configuration Summary"
echo "Display Name:     $DISPLAY_NAME"
echo "Lowercase-Dash:   $DASH_NAME"
echo "Snake_Case:       $SNAKE_NAME"
echo "GitHub URL:       $GITHUB_URL"
echo "Python Backend:   $([ "$KEEP_BACKEND" = true ] && echo "yes" || echo "no")"
if [ "$FRONTEND_CHOICE" = "none" ]; then
    echo "Frontend:         no"
else
    echo "Frontend:         yes, $FRONTEND_CHOICE"
fi
echo ""
read -p "Proceed with initialization? (y/n) [y]: " CONFIRM
CONFIRM=${CONFIRM:-y}

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_warning "Initialization cancelled"
    exit 0
fi

print_header "Starting Initialization"


# Step 7: Remove Python backend if not needed
if [ "$KEEP_BACKEND" = false ]; then
    print_info "Removing Python backend files..."

    # Remove Python component files
    if [ -d "custom_components/plugin_template" ]; then
        rm -rf "custom_components/plugin_template"
        print_success "Removed custom_components/plugin_template/"
    fi

    # Also check for already renamed directory
    if [ -d "custom_components/$SNAKE_NAME" ]; then
        read -p "Remove custom_components/$SNAKE_NAME/? (y/n) [n]: " REMOVE_BACKEND
        REMOVE_BACKEND=${REMOVE_BACKEND:-n}
        if [[ "$REMOVE_BACKEND" =~ ^[Yy]$ ]]; then
            rm -rf "custom_components/$SNAKE_NAME"
            print_success "Removed custom_components/$SNAKE_NAME/"
        else
            print_warning "Keeping custom_components/$SNAKE_NAME/"
            KEEP_BACKEND=true  # Don't remove if user says no
        fi
    fi

    # Remove tests directory
    if [ -d "tests" ]; then
        rm -rf "tests"
        print_success "Removed tests/"
    fi

    # Remove pyproject.toml if it exists
    if [ -f "pyproject.toml" ]; then
        rm -f "pyproject.toml"
        print_success "Removed pyproject.toml"
    fi
fi

# Step 8: Handle frontend choice
print_info "Setting up frontend..."

if [ "$FRONTEND_CHOICE" = "none" ]; then
    # Remove all frontend directories
    print_warning "Removing all frontend directories..."
    [ -d "frontend_vue" ] && rm -rf "frontend_vue" && print_success "Removed frontend_vue/"
    [ -d "frontend_plain" ] && rm -rf "frontend_plain" && print_success "Removed frontend_plain/"
    [ -d "frontend" ] && rm -rf "frontend" && print_success "Removed frontend/"
    print_success "Frontend setup skipped (backend-only plugin)"

elif [ "$FRONTEND_CHOICE" = "vue" ]; then
    if [ -d "frontend_vue" ]; then
        # Clean up lock files from frontend_vue
        [ -f "frontend_vue/yarn.lock" ] && rm -f "frontend_vue/yarn.lock" && print_success "Removed frontend_vue/yarn.lock"
        [ -f "frontend_vue/package-lock.json" ] && rm -f "frontend_vue/package-lock.json" && print_success "Removed frontend_vue/package-lock.json"

        # Remove frontend_plain if it exists
        [ -d "frontend_plain" ] && rm -rf "frontend_plain" && print_success "Removed frontend_plain/"

        # Safely move/merge frontend_vue to frontend
        safe_move_directory "frontend_vue" "frontend" "Frontend"
    elif [ ! -d "frontend" ]; then
        print_error "frontend_vue/ directory not found and no frontend/ exists!"
        exit 1
    else
        print_info "frontend/ directory already exists, keeping it"
    fi

# Uncomment when frontend_plain is implemented:
# elif [ "$FRONTEND_CHOICE" = "plain" ]; then
#     if [ -d "frontend_plain" ]; then
#         # Clean up lock files from frontend_plain
#         [ -f "frontend_plain/yarn.lock" ] && rm -f "frontend_plain/yarn.lock" && print_success "Removed frontend_plain/yarn.lock"
#         [ -f "frontend_plain/package-lock.json" ] && rm -f "frontend_plain/package-lock.json" && print_success "Removed frontend_plain/package-lock.json"
#
#         # Remove frontend_vue if it exists
#         [ -d "frontend_vue" ] && rm -rf "frontend_vue" && print_success "Removed frontend_vue/"
#
#         # Safely move/merge frontend_plain to frontend
#         safe_move_directory "frontend_plain" "frontend" "Frontend"
#     elif [ ! -d "frontend" ]; then
#         print_error "frontend_plain/ directory not found and no frontend/ exists!"
#         exit 1
#     else
#         print_info "frontend/ directory already exists, keeping it"
#     fi
fi

# Generate PascalCase version for class names
PASCAL_NAME=$(to_pascal_case "$DISPLAY_NAME")

print_header "File Replacement Configuration"
print_info "The following replacements will be made:"
echo "  'plugin_template'        → '$SNAKE_NAME'"
echo "  'PluginTemplate'         → '$PASCAL_NAME'"
echo "  'PLUGIN_TEMPLATE'        → '$(echo $SNAKE_NAME | tr '[:lower:]' '[:upper:]')'"
echo "  'plugin-template'        → '$DASH_NAME'"
echo "  'plugin-template-card'   → '${DASH_NAME}-card'"
echo "  'Plugin Template'        → '$DISPLAY_NAME'"
echo "  'hoass_plugin-template'  → 'hoass_${DASH_NAME}'"
echo "  GitHub URL               → '$GITHUB_URL'"

# Show author replacements if GitHub user is different
if [ "$GITHUB_USER" != "luckydonald" ] && [ "$GITHUB_USER" != "luckylucy" ]; then
    echo ""
    print_info "Author name replacements:"
    echo "  'luckydonald'            → '$GITHUB_USER'"
    echo "  'luckylucy'              → '$GITHUB_USER'"
    echo "  '@luckydonald'           → '@$GITHUB_USER'"
    echo "  'lucky lucy (aka. luckydonald)' → '$GITHUB_USER'"
fi

echo ""
print_warning "Ready to perform replacements in all files."
print_warning "This operation will modify files in place!"
echo ""
read -p "Continue with file replacements? (y/n) [y]: " CONTINUE
CONTINUE=${CONTINUE:-y}

if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
    print_warning "File replacements skipped. You can run them manually later."
    print_success "\nInitialization partially complete!"
    exit 0
fi

print_header "Performing File Replacements"

# Define the list of files to process
# Note: This is a hardcoded list to avoid replacing "plugin_template" in unintended places
FILES_TO_PROCESS=()

# Add root level files
[ -f "hacs.json" ] && FILES_TO_PROCESS+=("hacs.json")
[ -f "pyproject.toml" ] && FILES_TO_PROCESS+=("pyproject.toml")
[ -f "Makefile" ] && FILES_TO_PROCESS+=("Makefile")
[ -f "README.md" ] && FILES_TO_PROCESS+=("README.md")
# CLAUDE.md is handled by setup_claude_md (which calls replace_in_file itself on first run).
# On re-runs, if CLAUDE.md no longer has the template marker, process it directly.
if [ -f "CLAUDE.md" ] && ! grep -q "TEMPLATE_CLAUDE_MD" "CLAUDE.md" 2>/dev/null; then
    FILES_TO_PROCESS+=("CLAUDE.md")
fi

# Add script files
[ -f "scripts/commit.sh" ] && FILES_TO_PROCESS+=("scripts/commit.sh")
[ -f "scripts/release.sh" ] && FILES_TO_PROCESS+=("scripts/release.sh")

# Add .github workflow files
if [ -d ".github/workflows" ]; then
    while IFS= read -r -d '' file; do
        FILES_TO_PROCESS+=("$file")
    done < <(find .github/workflows -type f \( -name "*.yml" -o -name "*.yaml" \) -print0)
fi

# Add all files in custom_components/plugin_template/ (if backend is kept)
if [ "$KEEP_BACKEND" = true ] && [ -d "custom_components/plugin_template" ]; then
    # Add Python files
    while IFS= read -r -d '' file; do
        FILES_TO_PROCESS+=("$file")
    done < <(find custom_components/plugin_template -type f \( -name "*.py" -o -name "*.yaml" -o -name "*.json" \) -print0)

    # Add test files if they exist
    if [ -d "tests" ]; then
        while IFS= read -r -d '' file; do
            FILES_TO_PROCESS+=("$file")
        done < <(find tests -type f -name "*.py" -print0)
    fi
fi

# Add all relevant frontend files
if [ -d "frontend" ]; then
    # Add frontend files that typically contain plugin names
    [ -f "frontend/package.json" ] && FILES_TO_PROCESS+=("frontend/package.json")
    [ -f "frontend/index.html" ] && FILES_TO_PROCESS+=("frontend/index.html")
    [ -f "frontend/vite.config.ts" ] && FILES_TO_PROCESS+=("frontend/vite.config.ts")
    [ -f "frontend/vitest.config.ts" ] && FILES_TO_PROCESS+=("frontend/vitest.config.ts")
    [ -f "frontend/README.md" ] && FILES_TO_PROCESS+=("frontend/README.md")

    # Add source files
    while IFS= read -r -d '' file; do
        FILES_TO_PROCESS+=("$file")
    done < <(find frontend/src -type f \( -name "*.ts" -o -name "*.vue" -o -name "*.js" \) 2>/dev/null -print0)

    # Add test files
    if [ -d "frontend/tests" ]; then
        while IFS= read -r -d '' file; do
            FILES_TO_PROCESS+=("$file")
        done < <(find frontend/tests -type f \( -name "*.ts" -o -name "*.js" \) 2>/dev/null -print0)
    fi
fi

# Function to replace text in a file
replace_in_file() {
    local file=$1

    if [ ! -f "$file" ]; then
        print_warning "File not found: $file (skipping)"
        return
    fi

    # Check if file has already been processed (contains the target name already)
    if grep -q "$SNAKE_NAME" "$file" 2>/dev/null || grep -q "$DASH_NAME" "$file" 2>/dev/null; then
        # File might be already processed, check if it still has template patterns
        if ! grep -q "plugin_template\|plugin-template\|PluginTemplate" "$file" 2>/dev/null; then
            print_info "Skipped (already processed): $file"
            return
        fi
    fi

    # Backup the file
    cp "$file" "$file.bak"

    # Get current year
    CURRENT_YEAR=$(date +%Y)

    # Perform replacements using sed
    # macOS sed requires '' after -i, Linux doesn't
    # IMPORTANT: Order matters! Replace more specific patterns first

    # Determine if we need to replace author names
    REPLACE_AUTHORS=false
    if [ "$GITHUB_USER" != "luckydonald" ] && [ "$GITHUB_USER" != "luckylucy" ]; then
        REPLACE_AUTHORS=true
    fi

    # Build the sed command with common replacements
    SED_CMD=""
    SED_CMD+=" -e \"s|https://github.com/luckydonald/hoass_plugin-template|${GITHUB_URL%.git}|g\""
    SED_CMD+=" -e \"s/hoass_plugin-template/hoass_${DASH_NAME}/g\""
    SED_CMD+=" -e \"s/hoass_plugin_template/hoass_${SNAKE_NAME}/g\""
    SED_CMD+=" -e \"s/hoass-plugin-template/hoass-${DASH_NAME}/g\""
    SED_CMD+=" -e \"s/plugin-template-card/${DASH_NAME}-card/g\""
    SED_CMD+=" -e \"s/PLUGIN-TEMPLATE-CARD/$(echo $DASH_NAME | tr '[:lower:]' '[:upper:]')-CARD/g\""
    SED_CMD+=" -e \"s/plugin_template/$SNAKE_NAME/g\""
    SED_CMD+=" -e \"s/plugin-template\.zip/${DASH_NAME}.zip/g\""
    SED_CMD+=" -e \"s/plugin-template/$DASH_NAME/g\""
    SED_CMD+=" -e \"s/Plugin template/$DISPLAY_NAME/g\""
    SED_CMD+=" -e \"s/Plugin Template/$DISPLAY_NAME/g\""
    SED_CMD+=" -e \"s/from '\.\/PluginTemplateCard\.vue'/from '.\/${PASCAL_NAME}Card.vue'/g\""
    SED_CMD+=" -e \"s/PluginTemplateCard/${PASCAL_NAME}Card/g\""
    SED_CMD+=" -e \"s/PluginTemplate/${PASCAL_NAME}/g\""
    SED_CMD+=" -e \"s/PLUGIN_TEMPLATE/$(echo $SNAKE_NAME | tr '[:lower:]' '[:upper:]')/g\""
    # Add year replacements
    SED_CMD+=" -e \"s/2026/$CURRENT_YEAR/g\""
    SED_CMD+=" -e \"s/2026-2\\([0-9]\\{3\\}\\)/$CURRENT_YEAR-2\\1/g\""

    # Add author replacements if needed
    if [ "$REPLACE_AUTHORS" = true ]; then
        SED_CMD+=" -e \"s/lucky lucy (aka\. luckydonald)/$GITHUB_USER/g\""
        SED_CMD+=" -e \"s/@luckydonald\", \"@luckylucy/@$GITHUB_USER/g\""
        SED_CMD+=" -e \"s/{ name = \\\"luckydonald\\\" }, { name = \\\"luckylucy\\\" }/{ name = \\\"$GITHUB_USER\\\" }/g\""
        SED_CMD+=" -e \"s/@luckydonald/@$GITHUB_USER/g\""
        SED_CMD+=" -e \"s/\\\"luckydonald\\\"/\\\"$GITHUB_USER\\\"/g\""
        SED_CMD+=" -e \"s/luckydonald/$GITHUB_USER/g\""
        SED_CMD+=" -e \"s/luckylucy/$GITHUB_USER/g\""
    fi

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        eval "sed -i '' $SED_CMD \"$file\""
    else
        # Linux
        eval "sed -i $SED_CMD \"$file\""
    fi

    print_success "Processed: $file"
}

# Process each file
for file in "${FILES_TO_PROCESS[@]}"; do
    replace_in_file "$file"
done

# Handle README files
print_info "Setting up README files..."
setup_readme_files

# Handle CLAUDE.md
print_info "Setting up CLAUDE.md..."
setup_claude_md

# Rename the custom_components/plugin_template directory
if [ -d "custom_components/plugin_template" ]; then
    if [ -d "custom_components/$SNAKE_NAME" ]; then
        print_warning "custom_components/$SNAKE_NAME/ already exists"

        # Ask user whether to merge new template files into the existing directory,
        # backup & replace the existing directory with the template, or skip.
        print_info "Choose how to handle the existing directory:"
        echo "  m - merge new files into existing directory (default)"
        echo "  r - move existing directory to a date-stamped backup and replace with template"
        echo "  s - skip (leave both directories as-is)"
        ACTION=$(prompt_default "Action (m/r/s) [m]: " "m")

        if [[ "$ACTION" =~ ^[Rr]$ ]]; then
            # Backup-and-replace: move existing to .YYYY-MM-DD.bak (avoid collisions)
            DATE_STAMP=$(date +%F)
            BACKUP_BASE="custom_components/${SNAKE_NAME}.${DATE_STAMP}.bak"
            BACKUP_PATH="$BACKUP_BASE"
            i=1
            while [ -e "$BACKUP_PATH" ]; do
                BACKUP_PATH="${BACKUP_BASE}.${i}"
                i=$((i+1))
            done

            print_info "Moving existing directory to: $BACKUP_PATH"
            mv "custom_components/$SNAKE_NAME" "$BACKUP_PATH"
            if [ $? -ne 0 ]; then
                print_error "Failed to move existing directory to $BACKUP_PATH"
                print_info "Aborting replace operation"
            else
                # Now move the template into place
                mv "custom_components/plugin_template" "custom_components/$SNAKE_NAME"
                if [ $? -eq 0 ]; then
                    print_success "Replaced custom_components/$SNAKE_NAME with template (backup at $BACKUP_PATH)"
                else
                    print_error "Failed to move plugin_template into place; attempt to roll back"
                    # Try to restore backup
                    if [ ! -d "custom_components/$SNAKE_NAME" ] && [ -d "$BACKUP_PATH" ]; then
                        mv "$BACKUP_PATH" "custom_components/$SNAKE_NAME" || true
                        print_info "Restored original to custom_components/$SNAKE_NAME"
                    fi
                fi
            fi

        elif [[ "$ACTION" =~ ^[Ss]$ ]]; then
            print_info "Skipping merge/replace for custom_components/$SNAKE_NAME. Leaving plugin_template/ in place."

        else
            # Default: merge new files from plugin_template to existing directory
            print_info "Merging template files into existing directory..."
            while IFS= read -r -d '' file; do
                rel_path="${file#custom_components/plugin_template/}"
                dest_file="custom_components/$SNAKE_NAME/$rel_path"

                if [ ! -f "$dest_file" ]; then
                    COPY_NEW=$(prompt_default "Copy new file $rel_path? (y/n) [y]: " "y")
                    if [[ "$COPY_NEW" =~ ^[Yy]$ ]]; then
                        mkdir -p "$(dirname "$dest_file")"
                        cp "$file" "$dest_file"
                        print_success "Copied: $rel_path"
                    fi
                fi
            done < <(find "custom_components/plugin_template" -type f -print0)

            rm -rf "custom_components/plugin_template"
        fi
    else
        print_info "Renaming custom_components/plugin_template/ to custom_components/$SNAKE_NAME/"
        mv "custom_components/plugin_template" "custom_components/$SNAKE_NAME"
        print_success "Renamed directory"
    fi
elif [ ! -d "custom_components/$SNAKE_NAME" ] && [ "$KEEP_BACKEND" = true ]; then
    print_warning "Neither plugin_template nor $SNAKE_NAME directory found in custom_components/"
fi

# Rename the Vue component file if it exists
if [ -f "frontend/src/PluginTemplateCard.vue" ]; then
    if [ -f "frontend/src/${PASCAL_NAME}Card.vue" ]; then
        print_warning "frontend/src/${PASCAL_NAME}Card.vue already exists"
        read -p "Overwrite with template version? (y/n) [n]: " OVERWRITE_VUE
        OVERWRITE_VUE=${OVERWRITE_VUE:-n}
        if [[ "$OVERWRITE_VUE" =~ ^[Yy]$ ]]; then
            mv -f "frontend/src/PluginTemplateCard.vue" "frontend/src/${PASCAL_NAME}Card.vue"
            print_success "Overwrote Vue component"
        else
            rm "frontend/src/PluginTemplateCard.vue"
            print_info "Kept existing ${PASCAL_NAME}Card.vue"
        fi
    else
        print_info "Renaming PluginTemplateCard.vue to ${PASCAL_NAME}Card.vue"
        mv "frontend/src/PluginTemplateCard.vue" "frontend/src/${PASCAL_NAME}Card.vue"
        print_success "Renamed Vue component"
    fi
elif [ -f "frontend/src/${PASCAL_NAME}Card.vue" ]; then
    print_info "Component already renamed to ${PASCAL_NAME}Card.vue"
fi

# Clean up template-specific directories
print_info "Cleaning up template-specific files..."

# Remove ai/plugin_template/ directory (template-specific AI context)
if [ -d "ai/plugin_template" ]; then
    rm -rf "ai/plugin_template"
    print_success "Removed ai/plugin_template/"
fi

# Remove unused frontend_* directories (if they still exist)
if [ -d "frontend_vue" ]; then
    rm -rf "frontend_vue"
    print_success "Removed unused frontend_vue/"
fi

if [ -d "frontend_plain" ]; then
    rm -rf "frontend_plain"
    print_success "Removed unused frontend_plain/"
fi

# Remove template-specific documentation files
TEMPLATE_DOCS=(
    "CLAUDE_REPO_TEMPLATE.md"
    "CLEANUP_SUMMARY.md"
    "TRANSFORMATION_COMPLETE.md"
    "POST_TRANSFORMATION_CHECKLIST.md"
    "TEST_SETUP_SUMMARY.md"
    "TEST_INFRASTRUCTURE_COMPLETE.md"
    "TEST_CHECKLIST.md"
    "INIT_ENHANCEMENTS_COMPLETE.md"
    "INIT_RERUN_COMPLETE.md"
    "INIT_CLEANUP_COMPLETE.md"
    "RERUN_GUIDE.md"
    "COMMIT_TRACKING.md"
    "COMMIT_TRACKING_COMPLETE.md"
    "COMMIT_TEMPLATE_FORMAT.md"
    "TEMPLATE_COMMIT_COMPLETE.md"
    "FLEXIBLE_MESSAGE_COMPLETE.md"
    "SYNTAX_FIX.md"
    "FIX_COMMITS_GUIDE.md"
    "FIX_COMMITS_COMPLETE.md"
    "FIX_COMMITS_FIXED.md"
)

for doc in "${TEMPLATE_DOCS[@]}"; do
    if [ -f "$doc" ]; then
        rm "$doc"
        print_success "Removed template doc: $doc"
    fi
done

# Clean up backup files
print_info "Cleaning up backup files..."
find "$REPO_ROOT" -name "*.bak" -delete
print_success "Backup files removed"

# Write project settings to scripts/init.json
print_info "Saving project settings to scripts/init.json..."
cat > "scripts/init.json" << EOF
{
  "display_name": "$DISPLAY_NAME",
  "dash_name": "$DASH_NAME",
  "snake_name": "$SNAKE_NAME",
  "pascal_name": "$PASCAL_NAME",
  "github_user": "$GITHUB_USER",
  "github_url": "$GITHUB_URL",
  "keep_backend": $KEEP_BACKEND,
  "frontend_choice": "$FRONTEND_CHOICE",
  "current_year": $(date +%Y),
  "replacements": {
    "": ""
  },
  "": ""
}
EOF
print_success "Project settings saved"

print_header "Initialization Complete!"
echo ""
if [ "$ALREADY_INITIALIZED" = true ]; then
    print_success "Your Home Assistant plugin has been updated!"
    echo ""
    print_info "Re-running will update files and add any new template files"
else
    print_success "Your new Home Assistant plugin has been initialized!"
fi
echo ""
echo "Summary:"
echo "  • Display Name: $DISPLAY_NAME"
echo "  • Domain: $SNAKE_NAME"
echo "  • GitHub: $GITHUB_URL"
if [ "$KEEP_BACKEND" = true ]; then
    echo "  • Backend: yes (custom_components/$SNAKE_NAME/)"
else
    echo "  • Backend: no"
fi
if [ "$FRONTEND_CHOICE" = "none" ]; then
    echo "  • Frontend: no"
elif [ -d "frontend" ]; then
    echo "  • Frontend: yes, $FRONTEND_CHOICE"
fi
if [ -d "tests" ]; then
    echo "  • Tests: Included"
fi
echo ""

# Ask about committing the changes
if [ -n "$(git status --porcelain)" ]; then
    print_info "Changes have been made to the repository"
    echo ""
    git status --short
    echo ""

    read -p "Would you like to commit these changes? (y/n) [y]: " COMMIT_AFTER
    COMMIT_AFTER=${COMMIT_AFTER:-y}

    if [[ "$COMMIT_AFTER" =~ ^[Yy]$ ]]; then
        print_info "Staging all changes (including new and deleted files)..."
        git add -A

        # Build comprehensive commit message
        COMMIT_HEADER="🛫 template | Applied plugin template with \`init.sh\`"
        COMMIT_BODY=""
        COMMIT_BODY+="Configuration:"
        COMMIT_BODY+=$'\n'"  • Display Name: $DISPLAY_NAME"
        COMMIT_BODY+=$'\n'"  • Domain: $SNAKE_NAME"
        COMMIT_BODY+=$'\n'"  • Snake Case: $SNAKE_NAME"
        COMMIT_BODY+=$'\n'"  • Dash Case: $DASH_NAME"
        COMMIT_BODY+=$'\n'"  • PascalCase: $PASCAL_NAME"
        COMMIT_BODY+=$'\n'"  • GitHub User: $GITHUB_USER"
        COMMIT_BODY+=$'\n'"  • Repository: $GITHUB_URL"
        COMMIT_BODY+=$'\n'

        if [ "$KEEP_BACKEND" = true ]; then
            COMMIT_BODY+=$'\n'"Backend: Python component included"
            COMMIT_BODY+=$'\n'"  • Custom component: custom_components/$SNAKE_NAME/"
            if [ -d "tests" ]; then
                COMMIT_BODY+=$'\n'"  • Tests: Included"
            fi
        else
            COMMIT_BODY+=$'\n'"Backend: Not included (frontend-only plugin)"
        fi

        COMMIT_BODY+=$'\n'
        if [ "$FRONTEND_CHOICE" = "none" ]; then
            COMMIT_BODY+=$'\n'"Frontend: Not included (backend-only plugin)"
        else
            COMMIT_BODY+=$'\n'"Frontend: $FRONTEND_CHOICE"
            if [ "$FRONTEND_CHOICE" = "vue" ]; then
                COMMIT_BODY+=$'\n'"  • Framework: Vue 3 + TypeScript + Vite"
            # Uncomment when frontend_plain is implemented:
            # elif [ "$FRONTEND_CHOICE" = "plain" ]; then
            #     COMMIT_BODY+=$'\n'"  • Framework: Plain TypeScript"
            fi
            COMMIT_BODY+=$'\n'"  • Directory: frontend/"
        fi

        if [ "$ALREADY_INITIALIZED" = true ]; then
            COMMIT_BODY+=$'\n'
            COMMIT_BODY+=$'\n'"Note: This was a re-run of init.sh on an already initialized plugin"
            COMMIT_BODY+=$'\n'"      Template files updated and new files added"
        fi

        # Combine header and body
        FULL_COMMIT_MSG="$COMMIT_HEADER"
        FULL_COMMIT_MSG+=$'\n'
        FULL_COMMIT_MSG+=$'\n'"$COMMIT_BODY"

        print_info "Committing with message:"
        echo ""
        echo "$FULL_COMMIT_MSG"
        echo ""

        git commit -m "$FULL_COMMIT_MSG"
        print_success "Changes committed!"
        echo ""
    else
        print_info "Changes not committed - you can commit them later with:"
        echo "  git add -A"
        echo "  git commit -m 'Applied plugin template'"
        echo ""
    fi
else
    print_info "No changes to commit"
fi

print_info "Next steps:"
if [ "$ALREADY_INITIALIZED" = false ]; then
    echo "  1. Review the changes made to the files"
    echo "  2. Update README.md with your plugin details"
    echo "  3. Update LICENSE if needed"
    echo "  4. Run 'make setup' to install dependencies"
    echo "  5. Run 'make test' to verify everything works"
    echo "  6. Start developing your plugin!"
else
    echo "  1. Review any new files that were copied"
    echo "  2. Run 'make test' to verify everything still works"
    echo "  3. Continue developing your plugin!"
fi
echo ""
print_warning "Note: You may need to restart Home Assistant and clear browser cache"
echo ""
