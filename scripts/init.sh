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

print_header "Home Assistant Plugin Template Initializer"

# Get the repository root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

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

# Step 1: Get the display name (UI name)
print_info "Step 1: Plugin Display Name"
echo "This is the name that will be shown in the Home Assistant UI."

# Try to deduce name from folder
FOLDER_DEFAULT=$(extract_plugin_name_from_folder)
if [ -n "$FOLDER_DEFAULT" ]; then
    echo "Example: 'My Custom Widget'"
    echo ""
    read -p "Enter plugin display name [$FOLDER_DEFAULT]: " DISPLAY_NAME
    DISPLAY_NAME=${DISPLAY_NAME:-$FOLDER_DEFAULT}
else
    echo "Example: 'My Custom Widget'"
    echo ""
    read -p "Enter plugin display name: " DISPLAY_NAME
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
DEFAULT_DASH=$(to_lowercase_dash "$DISPLAY_NAME")
echo ""
read -p "Enter lowercase-dash name [$DEFAULT_DASH]: " DASH_NAME
DASH_NAME=${DASH_NAME:-$DEFAULT_DASH}

print_success "Lowercase-dash name: $DASH_NAME"

# Step 3: Get the snake_case name
print_info "\nStep 3: Snake_Case Name"
echo "This is used for Python module names, integration domain, sensor names, etc."
echo "Example: 'my_custom_widget'"
DEFAULT_SNAKE=$(to_snake_case "$DASH_NAME")
echo ""
read -p "Enter snake_case name [$DEFAULT_SNAKE]: " SNAKE_NAME
SNAKE_NAME=${SNAKE_NAME:-$DEFAULT_SNAKE}

print_success "Snake_case name: $SNAKE_NAME"

# Step 4: Get GitHub username
print_info "\nStep 4: GitHub Username"
echo "This is your GitHub username for the repository URL."
echo ""
read -p "Enter GitHub username [luckydonald]: " GITHUB_USER
GITHUB_USER=${GITHUB_USER:-luckydonald}

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

# Step 7: Ask about frontend choice
print_info "\nStep 7: Frontend Framework"
echo "Choose your frontend framework:"

# Check which frontend directories exist
HAS_VUE=false
HAS_PLAIN=false
[ -d "frontend_vue" ] && HAS_VUE=true
[ -d "frontend_plain" ] && HAS_PLAIN=true

if [ "$HAS_VUE" = true ]; then
    echo "  vue   - Vue.js framework (from frontend_vue/)"
fi
if [ "$HAS_PLAIN" = true ]; then
    echo "  plain - Plain HTML/JS/CSS (from frontend_plain/)"
fi

# Determine default based on what exists
if [ "$HAS_VUE" = true ]; then
    DEFAULT_FRONTEND="vue"
elif [ "$HAS_PLAIN" = true ]; then
    DEFAULT_FRONTEND="plain"
else
    print_error "No frontend directories found (frontend_vue/ or frontend_plain/)"
    exit 1
fi

echo ""
read -p "Enter frontend choice ($([ "$HAS_VUE" = true ] && echo -n "vue")$([ "$HAS_VUE" = true ] && [ "$HAS_PLAIN" = true ] && echo -n "/")$([ "$HAS_PLAIN" = true ] && echo -n "plain")) [$DEFAULT_FRONTEND]: " FRONTEND_CHOICE
FRONTEND_CHOICE=${FRONTEND_CHOICE:-$DEFAULT_FRONTEND}

# Validate choice
if [[ "$FRONTEND_CHOICE" == "vue" && "$HAS_VUE" = false ]]; then
    print_error "frontend_vue/ directory does not exist"
    exit 1
elif [[ "$FRONTEND_CHOICE" == "plain" && "$HAS_PLAIN" = false ]]; then
    print_error "frontend_plain/ directory does not exist"
    exit 1
elif [[ "$FRONTEND_CHOICE" != "vue" && "$FRONTEND_CHOICE" != "plain" ]]; then
    print_error "Invalid frontend choice. Must be 'vue' or 'plain'"
    exit 1
fi

print_success "Frontend choice: $FRONTEND_CHOICE"

# Summary
print_header "Configuration Summary"
echo "Display Name:     $DISPLAY_NAME"
echo "Lowercase-Dash:   $DASH_NAME"
echo "Snake_Case:       $SNAKE_NAME"
echo "GitHub URL:       $GITHUB_URL"
echo "Python Backend:   $KEEP_BACKEND"
echo "Frontend:         $FRONTEND_CHOICE"
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

if [ "$FRONTEND_CHOICE" = "vue" ]; then
    if [ -d "frontend_vue" ]; then
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
elif [ "$FRONTEND_CHOICE" = "plain" ]; then
    if [ -d "frontend_plain" ]; then
        # Remove frontend_vue if it exists
        [ -d "frontend_vue" ] && rm -rf "frontend_vue" && print_success "Removed frontend_vue/"

        # Safely move/merge frontend_plain to frontend
        safe_move_directory "frontend_plain" "frontend" "Frontend"
    elif [ ! -d "frontend" ]; then
        print_error "frontend_plain/ directory not found and no frontend/ exists!"
        exit 1
    else
        print_info "frontend/ directory already exists, keeping it"
    fi
fi

# Generate PascalCase version for class names
PASCAL_NAME=$(to_pascal_case "$DISPLAY_NAME")

print_header "File Replacement Configuration"
print_info "The following replacements will be made:"
echo "  'template'        → '$SNAKE_NAME'"
echo "  'Template'        → '$PASCAL_NAME'"
echo "  'TEMPLATE'        → '$(echo $SNAKE_NAME | tr '[:lower:]' '[:upper:]')'"
echo "  'plugin-template' → '$DASH_NAME'"
echo "  'Plugin template' → '$DISPLAY_NAME'"
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

    # Perform replacements using sed
    # macOS sed requires '' after -i, Linux doesn't
    # IMPORTANT: Order matters! Replace more specific patterns first
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' \
            -e "s|https://github.com/luckydonald/hoass_plugin-template|${GITHUB_URL%.git}|g" \
            -e "s/hoass_plugin-template/hoass_${DASH_NAME}/g" \
            -e "s/hoass_plugin_template/hoass_${SNAKE_NAME}/g" \
            -e "s/hoass-plugin-template/hoass-${DASH_NAME}/g" \
            -e "s/plugin-template-card/${DASH_NAME}-card/g" \
            -e "s/plugin_template/$SNAKE_NAME/g" \
            -e "s/plugin-template\.zip/${DASH_NAME}.zip/g" \
            -e "s/plugin-template/$DASH_NAME/g" \
            -e "s/Plugin template/$DISPLAY_NAME/g" \
            -e "s/Plugin Template/$DISPLAY_NAME/g" \
            -e "s/from '\.\/PluginTemplateCard\.vue'/from '.\/${PASCAL_NAME}Card.vue'/g" \
            -e "s/PluginTemplateCard/${PASCAL_NAME}Card/g" \
            -e "s/PluginTemplate/${PASCAL_NAME}/g" \
            -e "s/PLUGIN_TEMPLATE/$(echo $SNAKE_NAME | tr '[:lower:]' '[:upper:]')/g" \
            "$file"
    else
        # Linux
        sed -i \
            -e "s|https://github.com/luckydonald/hoass_plugin-template|${GITHUB_URL%.git}|g" \
            -e "s/hoass_plugin-template/hoass_${DASH_NAME}/g" \
            -e "s/hoass_plugin_template/hoass_${SNAKE_NAME}/g" \
            -e "s/hoass-plugin-template/hoass-${DASH_NAME}/g" \
            -e "s/plugin-template-card/${DASH_NAME}-card/g" \
            -e "s/plugin_template/$SNAKE_NAME/g" \
            -e "s/plugin-template\.zip/${DASH_NAME}.zip/g" \
            -e "s/plugin-template/$DASH_NAME/g" \
            -e "s/Plugin template/$DISPLAY_NAME/g" \
            -e "s/Plugin Template/$DISPLAY_NAME/g" \
            -e "s/from '\.\/PluginTemplateCard\.vue'/from '.\/${PASCAL_NAME}Card.vue'/g" \
            -e "s/PluginTemplateCard/${PASCAL_NAME}Card/g" \
            -e "s/PluginTemplate/${PASCAL_NAME}/g" \
            -e "s/PLUGIN_TEMPLATE/$(echo $SNAKE_NAME | tr '[:lower:]' '[:upper:]')/g" \
            "$file"
    fi

    print_success "Processed: $file"
}

# Process each file
for file in "${FILES_TO_PROCESS[@]}"; do
    replace_in_file "$file"
done

# Rename the custom_components/plugin_template directory
if [ -d "custom_components/plugin_template" ]; then
    if [ -d "custom_components/$SNAKE_NAME" ]; then
        print_warning "custom_components/$SNAKE_NAME/ already exists"
        print_info "Merging template files into existing directory..."

        # Copy new files from plugin_template to existing directory
        while IFS= read -r -d '' file; do
            rel_path="${file#custom_components/plugin_template/}"
            dest_file="custom_components/$SNAKE_NAME/$rel_path"

            if [ ! -f "$dest_file" ]; then
                read -p "Copy new file $rel_path? (y/n) [y]: " COPY_NEW
                COPY_NEW=${COPY_NEW:-y}
                if [[ "$COPY_NEW" =~ ^[Yy]$ ]]; then
                    mkdir -p "$(dirname "$dest_file")"
                    cp "$file" "$dest_file"
                    print_success "Copied: $rel_path"
                fi
            fi
        done < <(find "custom_components/plugin_template" -type f -print0)

        rm -rf "custom_components/plugin_template"
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
    "CLEANUP_SUMMARY.md"
    "TRANSFORMATION_COMPLETE.md"
    "POST_TRANSFORMATION_CHECKLIST.md"
    "TEST_SETUP_SUMMARY.md"
    "TEST_INFRASTRUCTURE_COMPLETE.md"
    "TEST_CHECKLIST.md"
    "INIT_ENHANCEMENTS_COMPLETE.md"
    "INIT_RERUN_COMPLETE.md"
    "RERUN_GUIDE.md"
    "COMMIT_TRACKING.md"
    "COMMIT_TRACKING_COMPLETE.md"
    "COMMIT_TEMPLATE_FORMAT.md"
    "TEMPLATE_COMMIT_COMPLETE.md"
    "FLEXIBLE_MESSAGE_COMPLETE.md"
    "SYNTAX_FIX.md"
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

print_header "Initialization Complete!"
echo ""
if [ "$ALREADY_INITIALIZED" = true ]; then
    print_success "Your Home Assistant plugin has been updated!"
    echo ""
    print_info "Re-run completed - template files updated and new files added"
else
    print_success "Your new Home Assistant plugin has been initialized!"
fi
echo ""
echo "Summary:"
echo "  • Display Name: $DISPLAY_NAME"
echo "  • Domain: $SNAKE_NAME"
if [ "$KEEP_BACKEND" = true ]; then
    echo "  • Component: custom_components/$SNAKE_NAME/"
fi
if [ -d "frontend" ]; then
    echo "  • Frontend: frontend/"
fi
if [ -d "tests" ]; then
    echo "  • Tests: tests/"
fi
echo ""
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

