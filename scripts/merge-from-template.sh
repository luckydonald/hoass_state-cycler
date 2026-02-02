#!/usr/bin/env bash
# ============================================================================
# Home Assistant Plugin Template Merge Script
# ============================================================================
#
# This script updates a plugin from the template repository by merging the
# template's mane branch into the current branch. It detects template remote, fetches, creates a
# recovery tag, performs the merge, and helps resolve conflicts with the
# same automation and guidance as the rebase script.
# It mirrors the behavior of the rebase update script with that.
#
# Usage:
#   chmod +x scripts/merge-from-template.sh
#   ./scripts/merge-from-template.sh
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
            local url
            url=$(git remote get-url "$remote" 2>/dev/null || echo "")
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

# Function to check if merge is in progress
is_merge_in_progress() {
    [ -f ".git/MERGE_HEAD" ] || [ -d ".git/merge-logs" ]
}

# Function to continue merge after manual resolution
continue_merge() {
    if ! is_merge_in_progress; then
        print_error "No merge in progress"
        return 1
    fi

    # Check if conflicts are still unresolved
    # Auto-stage resolved files if conflict markers gone
    local unmerged_files
    unmerged_files=$(git diff --name-only --diff-filter=U 2>/dev/null)
    if [ -n "$unmerged_files" ]; then
        for file in $unmerged_files; do
            # Check if file still has conflict markers
            if [ -f "$file" ]; then
                if ! grep -q '^<<<<<<< ' "$file" 2>/dev/null; then
                    # File appears resolved but not staged - add it automatically
                    print_info "Auto-staging resolved file: $file"
                    git add "$file"
                else
                    print_error "Conflict still present in $file"
                    return 1
                fi
            fi
        done
    fi

    print_info "Continuing merge after manual resolution..."
    # Prepare a non-interactive merge commit message so git won't open an editor.
    # Create or overwrite .git/MERGE_MSG with our composed message (no commented lines).
    # Uncomment merge details in the commit message
    local message_file=".git/MERGE_MSG"
    local template_rev
    template_rev=$(git rev-parse --short "$TEMPLATE_REMOTE/mane" 2>/dev/null || echo "unknown")

    if [ -n "$message_file" ] && [ -f "$message_file" ]; then
        printf "Merge %s/mane into %s\n\n" "$TEMPLATE_REMOTE" "$CURRENT_BRANCH" > "$message_file"
        # Escape # at start of lines to prevent them from being treated as comments
        sed -i 's/^#/\\#/' "$message_file" 2>/dev/null || true

        # Add rebase details at the end
        echo "" >> "$message_file"
        printf "⛙ Template merge on %s from %s to %s/mane (%s)\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$CURRENT_BRANCH" "$TEMPLATE_REMOTE" "$template_rev" >> "$message_file"
    fi

    # Finalize the merge non-interactively by committing using the prepared message
    # This avoids opening an editor (some git versions may still prompt on merge --continue).
    if git commit -F "$message_file"; then
        print_success "Merge committed successfully"
        return 0
    else
        print_error "Merge commit failed"
        return 1
    fi
}

# Function to handle conflicts
handle_conflicts_for_merge() {
    local conflict_files
    conflict_files=$(git diff --name-only --diff-filter=U)

    print_warning "Conflicts detected in:"
    echo "$conflict_files"
    echo ""

    # Check if conflicts can be auto-resolved
    # Try simple auto-resolution: accept ours when remote deleted local, or accept theirs when local deleted
    for file in $conflict_files; do
        if [ -f "$file" ]; then
            # If stage 3 (their) missing -> remote deleted? For merge, use git ls-files -u to inspect
            if ! git show :3:"$file" >/dev/null 2>&1; then
                print_info "Remote deleted $file, keeping local version"
                git add "$file"
                continue
            fi
            if ! git show :2:"$file" >/dev/null 2>&1; then
                print_info "Local deleted $file, accepting remote version"
                git add "$file"
                continue
            fi
        else
            # File not present locally, accept remote
            print_info "Local missing $file, accepting remote version"
            git add "$file" || true
            continue
        fi
    done

    # If we can auto-stage all, try to continue using our non-interactive continue path
    if git diff --name-only --diff-filter=U | grep -q '.'; then
        print_warning "Some conflicts remain and require manual resolution"
    else
        print_info "Attempting to continue merge after auto-staging..."
        if continue_merge; then
            print_success "Merge auto-resolved and continued"
            return 0
        fi
    fi

    # Manual resolution guidance
    print_warning "Manual conflict resolution required"
    echo ""
    echo "Files with conflicts:"
    echo "$conflict_files"
    echo ""
    echo "Commands to resolve:"
    echo "  1. Edit the conflicted files"
    echo "  2. Stage resolved files: git add <file>"
    echo "  3. Continue merge: git merge --continue (or 'git commit' if 'merge --continue' not available)"
    echo "  4. Or abort: git merge --abort"
    echo ""
    echo "Tip: JetBrains IDEs (IntelliJ, PyCharm, etc.) have excellent Git merge conflict resolution tools"
    echo "     Look for 'Resolve Conflicts' in the Git tool window"
    echo ""
    read -p "Press Enter after resolving conflicts manually, or 'a' to abort: " response

    if [ "$response" = "a" ]; then
        git merge --abort
        print_warning "Merge aborted"
        exit 1
    fi

    # Allow retries if conflicts aren't fully resolved
    while true; do
        if continue_merge; then
            break
        fi
        echo ""
        read -p "Press Enter to try again after resolving remaining conflicts, or 'a' to abort: " retry_response
        if [ "$retry_response" = "a" ]; then
            git merge --abort
            print_warning "Merge aborted"
            exit 1
        fi
    done
}

# Main script
print_header "Home Assistant Plugin Template Merge"

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

# Check if merge is already in progress, try to continue
if is_merge_in_progress; then
    print_info "Merge already in progress, attempting to continue..."
    if continue_merge; then
        print_success "Merge completed"
        # Show summary
        print_header "Merge Summary"
        echo "Files changed during merge:"
        git diff --name-only HEAD~1
        exit 0
    else
        print_error "Failed to continue merge"
        exit 1
    fi
fi

# Detect template remote
TEMPLATE_REMOTE=$(detect_template_remote)
if [ -n "$TEMPLATE_REMOTE" ]; then
    remote_url=$(git remote get-url "$TEMPLATE_REMOTE" 2>/dev/null || echo "unknown")
    print_success "Using template remote: $TEMPLATE_REMOTE ($remote_url)"

    # Check if URL is a local path
    if [[ "$remote_url" =~ ^(\./|\.\./|/|[A-Za-z]:) ]]; then
        print_warning "Remote '$TEMPLATE_REMOTE' points to a local path '$remote_url', not a git URL."
        print_info "This may cause fetch to fail. Consider setting it to the proper git URL:"
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
RECOVERY_TAG="template-merge-backup_$(get_timestamp)"
print_info "Creating recovery tag: $RECOVERY_TAG"
git tag "$RECOVERY_TAG"
print_success "Recovery tag created"

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
if [ -z "$CURRENT_BRANCH" ]; then
    print_error "Not on a branch"
    exit 1
fi

# Perform merge
print_info "Merging $TEMPLATE_REMOTE/mane into $CURRENT_BRANCH..."
if git merge --no-edit "$TEMPLATE_REMOTE/mane"; then
    print_success "Merge completed successfully"
else
    # Handle conflicts
    handle_conflicts_for_merge
fi

# Show summary of changed files
print_header "Merge Summary"
echo "Files changed during merge:"
git diff --name-only "$RECOVERY_TAG"..HEAD

print_success "Template merge completed!"
echo ""
echo "Recovery tag: $RECOVERY_TAG"
echo "To undo: git reset --hard $RECOVERY_TAG"
