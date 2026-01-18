#!/usr/bin/env bash
# ============================================================================
# Home Assistant Plugin Template Update Script
# ============================================================================
#
# This script updates a plugin from the template repository by rebasing onto
# the latest template changes. It handles conflict resolution and provides
# recovery options.
#
# Usage:
#   chmod +x scripts/update-from-template.sh
#   ./scripts/update-from-template.sh
#
# ============================================================================

set -e  # Exit on error

# Colors for output
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

# Function to get current timestamp for template variables
get_timestamp() {
    date +"%Y-%m-%d_%H-%M-%S"
}

# Function to detect TEMPLATE_REMOTE
detect_template_remote() {
    local template_remote=""

    # Check for specific remote names
    local preferred_names=("template" "template-origin" "template-local" "template-online" "template-github")
    for name in "${preferred_names[@]}"; do
        if git remote | grep -q "^${name}$"; then
            template_remote="$name"
            break
        fi
    done

    # If not found, check URLs
    if [ -z "$template_remote" ]; then
        while IFS= read -r remote; do
            local url=$(git remote get-url "$remote" 2>/dev/null || echo "")
            if [[ "$url" =~ github\.com/luckydonald/hoass_(plugin[-_])?template(\.git)?$ ]]; then
                template_remote="$remote"
                break
            fi
        done < <(git remote)
    fi

    # If still not found, check for any remote with 'template' in name
    if [ -z "$template_remote" ]; then
        while IFS= read -r remote; do
            if [[ "$remote" =~ \btemplate\b ]]; then
                template_remote="$remote"
                break
            fi
        done < <(git remote)
    fi

    # If still not found, ask user
    if [ -z "$template_remote" ]; then
        print_warning "No template remote detected automatically"
        echo "Available remotes:"
        git remote -v
        echo ""
        echo "Choose an option:"
        echo "1. Use existing remote (enter remote name)"
        echo "2. Add new remote 'template' pointing to https://github.com/luckydonald/hoass_plugin-template"
        echo ""
        read -p "Enter remote name or '2' to add new remote: " choice

        if [ "$choice" = "2" ]; then
            git remote add template https://github.com/luckydonald/hoass_plugin-template.git
            template_remote="template"
            print_success "Added new remote 'template'"
        else
            template_remote="$choice"
            if ! git remote | grep -q "^${template_remote}$"; then
                print_error "Remote '$template_remote' does not exist"
                exit 1
            fi
        fi
    fi

    echo "$template_remote"
}

# Function to check if rebase is in progress
is_rebase_in_progress() {
    [ -d ".git/rebase-apply" ] || [ -d ".git/rebase-merge" ]
}

# Function to continue rebase after manual resolution
continue_rebase() {
    if ! is_rebase_in_progress; then
        print_error "No rebase in progress"
        return 1
    fi

    # Check if conflicts are still unresolved
    local unmerged_files=$(git diff --name-only --diff-filter=U 2>/dev/null)
    if [ -n "$unmerged_files" ]; then
        local needs_manual=true
        for file in $unmerged_files; do
            # Check if file still has conflict markers
            if ! grep -q "^<<<<<<< " "$file" 2>/dev/null; then
                # File appears resolved but not staged - add it automatically
                print_info "Auto-staging resolved file: $file"
                git add "$file"
            else
                needs_manual=false
                break
            fi
        done

        # Re-check after auto-staging
        unmerged_files=$(git diff --name-only --diff-filter=U 2>/dev/null)
        if [ -n "$unmerged_files" ]; then
            print_error "Conflicts are still present in: $unmerged_files"
            print_error "Please resolve all conflicts and stage the files with 'git add <file>' before continuing."
            return 1
        fi
    fi

    print_info "Continuing rebase after manual resolution..."

    # Uncomment merge details in the commit message
    local message_file=""
    if [ -d ".git/rebase-merge" ]; then
        message_file=".git/rebase-merge/message"
    elif [ -d ".git/rebase-apply" ]; then
        message_file=".git/rebase-apply/message"
    fi

    if [ -n "$message_file" ] && [ -f "$message_file" ]; then
        # Escape # at start of lines to prevent them from being treated as comments
        sed -i 's/^#/\\#/' "$message_file" 2>/dev/null || true
    fi

    # Prevent git from opening editor by setting GIT_EDITOR to true
    if GIT_EDITOR=true git rebase --continue; then
        print_success "Rebase continued successfully"
        return 0
    else
        print_error "Rebase continue failed"
        return 1
    fi
}

# Function to handle conflicts
handle_conflicts() {
    local conflict_files=$(git diff --name-only --diff-filter=U)
    local has_auto_resolvable=true

    print_warning "Conflicts detected in:"
    echo "$conflict_files"
    echo ""

    # Check if conflicts can be auto-resolved
    for file in $conflict_files; do
        if [ -f "$file" ]; then
            # Check if it's a simple case where remote deleted and local kept
            if git show :3:"$file" >/dev/null 2>&1; then
                # File exists in both, check if it's just whitespace or simple changes
                if ! git diff --check :2:"$file" :3:"$file" 2>/dev/null; then
                    has_auto_resolvable=false
                    break
                fi
            else
                # Remote deleted the file, local kept it - we can accept ours
                print_info "Remote deleted $file, keeping local version"
                git add "$file"
                continue
            fi
        else
            # Local deleted, remote kept - accept theirs
            print_info "Local deleted $file, accepting remote version"
            git add "$file"
            continue
        fi
    done

    if [ "$has_auto_resolvable" = true ]; then
        print_info "Attempting auto-resolution..."
        if git add -A && GIT_EDITOR=true git rebase --continue; then
            print_success "Conflicts auto-resolved"
            return 0
        fi
    fi

    # Manual resolution needed
    print_warning "Manual conflict resolution required"
    echo ""
    echo "Files with conflicts:"
    echo "$conflict_files"
    echo ""
    echo "Commands to resolve:"
    echo "  1. Edit the conflicted files"
    echo "  2. Stage resolved files: git add <file>"
    echo "  3. Continue rebase: git rebase --continue"
    echo "  4. Or abort: git rebase --abort"
    echo ""
    echo "Tip: JetBrains IDEs (IntelliJ, PyCharm, etc.) have excellent Git rebase conflict resolution tools"
    echo "     Look for 'Resolve Conflicts' in the Git tool window"
    echo ""
    read -p "Press Enter after resolving conflicts manually, or 'a' to abort: " response

    if [ "$response" = "a" ]; then
        git rebase --abort
        print_warning "Rebase aborted"
        exit 1
    fi

    # Allow retries if conflicts aren't fully resolved
    while true; do
        if continue_rebase; then
            break
        fi
        echo ""
        read -p "Press Enter to try again after resolving remaining conflicts, or 'a' to abort: " retry_response
        if [ "$retry_response" = "a" ]; then
            git rebase --abort
            print_warning "Rebase aborted"
            exit 1
        fi
    done
}

# Main script
print_header "Home Assistant Plugin Template Update"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    print_error "Not in a git repository!"
    exit 1
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    print_warning "You have uncommitted changes"
    git status --short
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if rebase is already in progress
if is_rebase_in_progress; then
    print_info "Rebase already in progress, attempting to continue..."
    if continue_rebase; then
        print_success "Rebase completed"
        # Show summary
        print_header "Rebase Summary"
        echo "Files changed during rebase:"
        git diff --name-only HEAD~1
        exit 0
    else
        print_error "Failed to continue rebase"
        exit 1
    fi
fi

# Detect template remote
TEMPLATE_REMOTE=$(detect_template_remote)
if [ -n "$TEMPLATE_REMOTE" ]; then
    remote_url=$(git remote get-url "$TEMPLATE_REMOTE" 2>/dev/null || echo "unknown")
    print_success "Using template remote: $TEMPLATE_REMOTE ($remote_url)"

    # Check if URL is a local path
    if [[ "$remote_url" =~ ^(\.\./|\./|/|[A-Za-z]:) ]]; then
        print_warning "Remote '$TEMPLATE_REMOTE' points to a local path '$remote_url', not a git URL."
        print_info "This will cause fetch to fail. Consider setting it to the proper git URL:"
        echo "  git remote set-url $TEMPLATE_REMOTE https://github.com/luckydonald/hoass_plugin-template.git"
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    print_error "No template remote found"
    exit 1
fi

# Fetch from template remote
print_info "Fetching from $TEMPLATE_REMOTE..."
if ! git fetch "$TEMPLATE_REMOTE"; then
    print_error "Failed to fetch from $TEMPLATE_REMOTE"
    exit 1
fi
print_success "Fetched latest changes"

# Create recovery tag
RECOVERY_TAG="template-rebase-backup_$(get_timestamp)"
print_info "Creating recovery tag: $RECOVERY_TAG"
git tag "$RECOVERY_TAG"
print_success "Recovery tag created"

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
if [ -z "$CURRENT_BRANCH" ]; then
    print_error "Not on a branch"
    exit 1
fi

# Start rebase onto mane
print_info "Starting rebase of $CURRENT_BRANCH onto $TEMPLATE_REMOTE/mane..."
if git rebase "$TEMPLATE_REMOTE/mane"; then
    print_success "Rebase completed successfully"
else
    # Handle conflicts
    handle_conflicts
fi

# Show summary of changed files
print_header "Rebase Summary"
echo "Files changed during rebase:"
git diff --name-only "$RECOVERY_TAG"..HEAD

print_success "Template update completed!"
echo ""
echo "Recovery tag: $RECOVERY_TAG"
echo "To undo: git reset --hard $RECOVERY_TAG"
