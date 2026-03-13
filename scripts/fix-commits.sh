#!/usr/bin/env bash
# ============================================================================
# Fix AI Commit Messages
# ============================================================================
#
# This script rebases the last batch of AI commits to:
#   1. Replace X with the actual total count in template format
#   2. Allow editing default "running…" messages to meaningful descriptions
#
# Supports both formats:
#   - Template: 📄TEMPLATE | ✨ ai: [013] running… (2/X)
#   - Regular: ✨ ai: running… (2-3)
#
# Usage:
#   ./scripts/fix-commits.sh
#   make fix-commits
#
# ============================================================================

set -e  # Exit on error

# Recovery tag template - customize this as needed
# Available variables: {step}, {date}, {time}
RECOVERY_TAG_TEMPLATE="fix-commits-backup-step-{step}_{date}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YIGHLIGHT='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color, the reset code
BLACK_ON_WHITE='\033[47;30m'

# Helper functions
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_code() {
    # black on white
    # -n: no trailing newline
    echo -e -n "${GRAY}»${NC} ${BLACK_ON_WHITE}$1\n${NC}"
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

linebreak() {
  echo ""
}

# Dry-run header printer (used when --dry-run is passed)
PRINT_DRY_RUN_HEADER() {
    linebreak
    print_info "Dry-run mode: the script will not create tags or perform a rebase."
    print_info "Selected commits (shown in chronological order):"
    linebreak
}

print_header "Fix AI Commit Messages"

# Get the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    print_error "Not in a git repository!"
    exit 1
fi

# Check if HEAD is detached
if ! git symbolic-ref -q HEAD > /dev/null; then
    print_error "HEAD is in a detached state!"
    print_info "Please checkout a branch first: git checkout <branch>"
    exit 1
fi

# Check for ongoing git operations
if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
    print_error "A rebase is already in progress!"
    print_info "Continue with: git rebase --continue"
    print_info "Or abort with: git rebase --abort"
    exit 1
fi

if [ -f ".git/MERGE_HEAD" ]; then
    print_error "A merge is in progress!"
    print_info "Complete the merge first or abort with: git merge --abort"
    exit 1
fi

if [ -f ".git/CHERRY_PICK_HEAD" ]; then
    print_error "A cherry-pick is in progress!"
    print_info "Complete it or abort with: git cherry-pick --abort"
    exit 1
fi

if [ -f ".git/REVERT_HEAD" ]; then
    print_error "A revert is in progress!"
    print_info "Complete it or abort with: git revert --abort"
    exit 1
fi

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    print_error "You have uncommitted changes. Please commit or stash them first."
    git status --short
    exit 1
fi

# Detect if this is a template repository and set commit prefix
REPO_DIR=$(basename "$PWD")
IS_TEMPLATE_REPO=false
COMMIT_PREFIX=""
if echo "$REPO_DIR" | grep -qE "^hoass_(plugin[-_])?template"; then
    IS_TEMPLATE_REPO=true
    COMMIT_PREFIX="📄TEMPLATE | "
    print_info "Template repository detected"
fi

# Find the last batch of AI commits
print_info "Scanning for AI commit batches..."

# Parse CLI arguments
START_COMMIT=""
END_COMMIT=""
IGNORE_BLOCKS=false
NUMBER_SEARCH=()
NUMBER_OVERRIDE=""
DRY_RUN=false
INTERACTIVE=false
# Default batch message (can be set via --message / -m)
BATCH_MESSAGE=""

print_usage() {
    echo "Usage: $0 [--start-commit <commit>] [--end-commit <commit>] [--ignore-blocks] [--number-search 10,11,23] [--number-override <number>] [--message <msg>|-m <msg>] [--dry-run] [--interactive|-i]"
}

# Helper: check if array contains value (portable)
array_contains() {
    local val="$1"; shift
    local item
    for item in "$@"; do
        if [ "$item" = "$val" ]; then
            return 0
        fi
    done
    return 1
}

# Helper: normalize step number (remove leading zeros, empty -> empty)
normalize_step() {
    echo "$1" | sed 's/^0*//'
}

# Helper: parse a number/search string like "10,11,58-60" into NUMBER_SEARCH array
parse_number_search() {
    local input="$1"
    NUMBER_SEARCH=()
    # Empty input -> empty array
    if [ -z "${input// /}" ]; then
        return 0
    fi

    # Split on commas
    OLD_IFS="$IFS"
    IFS=','
    for raw in $input; do
        IFS="$OLD_IFS"
        # Trim whitespace
        token=$(echo "$raw" | sed 's/^ *//; s/ *$//')
        if [ -z "$token" ]; then
            IFS=','
            continue
        fi
        # If token is a range like 58-69
        if echo "$token" | grep -qE '^[0-9]+[[:space:]]*-[[:space:]]*[0-9]+$'; then
            start=$(echo "$token" | sed -E 's/^([0-9]+).*/\1/')
            end=$(echo "$token" | sed -E 's/.*-([0-9]+)$/\1/')
            # Normalize and ensure numeric ordering
            start=$(normalize_step "$start")
            end=$(normalize_step "$end")
            # If start or end empty after normalization, skip
            if [ -z "$start" ] || [ -z "$end" ]; then
                IFS=','
                continue
            fi
            # Convert to integers and handle reversed ranges
            start=$((10#$start))
            end=$((10#$end))
            if [ "$start" -le "$end" ]; then
                i=$start
                while [ $i -le $end ]; do
                    NUMBER_SEARCH+=("$i")
                    i=$((i+1))
                done
            else
                i=$start
                while [ $i -ge $end ]; do
                    NUMBER_SEARCH+=("$i")
                    i=$((i-1))
                done
            fi
        elif echo "$token" | grep -qE '^[0-9]+$'; then
            # Single number
            num=$(normalize_step "$token")
            if [ -n "$num" ]; then
                # Strip leading zeros via arithmetic
                num=$((10#$num))
                NUMBER_SEARCH+=("$num")
            fi
        else
            # Not a number or range; ignore
            :
        fi
        IFS=','
    done
    IFS="$OLD_IFS"

    # Remove duplicates while preserving order
    if [ ${#NUMBER_SEARCH[@]} -gt 0 ]; then
        local uniq=()
        for v in "${NUMBER_SEARCH[@]}"; do
            if [ -z "$v" ]; then
                continue
            fi
            found=false
            for u in "${uniq[@]}"; do
                if [ "$u" = "$v" ]; then
                    found=true
                    break
                fi
            done
            if [ "$found" = false ]; then
                uniq+=("$v")
            fi
        done
        NUMBER_SEARCH=("${uniq[@]}")
    fi
}

# Helper: check if a string is pure ASCII (returns 1 for ascii, 0 for non-ascii)
is_ascii() {
    # Use python3 for reliable unicode detection; print 1 if ascii else 0
    python3 - <<PY "$1"
import sys
try:
    s = sys.argv[1]
    print(1 if s.isascii() else 0)
except Exception:
    print(0)
PY
}

# Helper: check if a string is safe to include directly in a shell command
# Return 1 if the string is ASCII, printable, and contains no control characters
# (notably avoids ESC, newlines, etc.) — otherwise return 0.
is_shell_printable() {
    python3 - <<PY "$1"
import sys
try:
    s = sys.argv[1]
    # isprintable covers many cases; additionally ensure ASCII-only
    ok = s.isascii() and s.isprintable()
    # disallow any escape/control characters explicitly (just in case)
    if any(ord(c) < 32 or ord(c) == 127 for c in s):
        ok = False
    print(1 if ok else 0)
except Exception:
    print(0)
PY
}

# Helper: base64-encode a UTF-8 string (no newline)
b64_of() {
    python3 - <<PY "$1"
import sys,base64
try:
    print(base64.b64encode(sys.argv[1].encode('utf-8')).decode())
except Exception:
    print('')
PY
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --start-commit)
            START_COMMIT="$2"; shift 2 || true;;
        --end-commit)
            END_COMMIT="$2"; shift 2 || true;;
        --ignore-blocks)
            IGNORE_BLOCKS=true; shift;;
        --number-search)
            if [ -n "$2" ]; then
                parse_number_search "$2"
                shift 2 || true
            else
                print_error "--number-search requires a comma-separated list"
                exit 1
            fi
            ;;
        --number-override)
            NUMBER_OVERRIDE="$2"; shift 2 || true;;
        --message|-m)
            # Default message for the batch (may be overridden interactively)
            BATCH_MESSAGE="$2"; shift 2 || true;;
        --message-base64|--message-b64)
            # Accept message as base64 to avoid shell/Make quoting issues; decode using python3 to preserve UTF-8
            if [ -n "$2" ]; then
                MESSAGE_B64="$2"; shift 2 || true
                # decode safely via python3 into BATCH_MESSAGE
                BATCH_MESSAGE=$(python3 - <<PY
import sys,base64
sys.stdout.write(base64.b64decode('$MESSAGE_B64').decode('utf-8'))
PY
) || BATCH_MESSAGE=""
            else
                print_error "--message-base64 requires a base64 value"
                exit 1
            fi
            ;;
        --dry-run)
            DRY_RUN=true; shift;;
        --interactive|-i)
            INTERACTIVE=true; shift;;
        -h|--help)
            print_usage; exit 0;;
        *)
            # stop parsing on unknown argument (allow other wrappers)
            break;;
    esac
done

# If interactive mode is enabled, prompt the user for each configurable flag/param
if [ "$INTERACTIVE" = true ]; then
    linebreak
    print_info "Interactive mode: press Enter to keep defaults/omit a setting"

    # Start commit
    if [ -n "$START_COMMIT" ]; then
        read -p "Start commit (current: $START_COMMIT) [press Enter to keep/omit]: " __input
        if [ -n "${__input}" ]; then
            START_COMMIT="$__input"
        fi
    else
        read -p "Start commit [press Enter to omit]: " __input
        if [ -n "${__input}" ]; then
            START_COMMIT="$__input"
        fi
    fi

    # End commit
    if [ -n "$END_COMMIT" ]; then
        read -p "End commit (current: $END_COMMIT) [press Enter to keep/omit]: " __input
        if [ -n "${__input}" ]; then
            END_COMMIT="$__input"
        fi
    else
        read -p "End commit [press Enter to omit]: " __input
        if [ -n "${__input}" ]; then
            END_COMMIT="$__input"
        fi
    fi

    # Ignore blocks (y/N)
    read -p "Ignore blocks (treat matching commits even if separated)? [y/N]: " __yn
    if [[ "${__yn}" =~ ^[Yy] ]]; then
        IGNORE_BLOCKS=true
    fi

    # Number search (comma-separated)
    if [ ${#NUMBER_SEARCH[@]} -gt 0 ]; then
        curns=$(IFS=,; echo "${NUMBER_SEARCH[*]}")
        read -p "Number search (current: $curns) [comma-separated, Enter to keep/omit]: " __input
        if [ -n "${__input}" ]; then
            parse_number_search "$__input"
        fi
    else
        read -p "Number search (comma-separated) [press Enter to omit]: " __input
        if [ -n "${__input}" ]; then
            parse_number_search "$__input"
        fi
    fi

    # Number override
    if [ -n "$NUMBER_OVERRIDE" ]; then
        read -p "Number override (current: $NUMBER_OVERRIDE) [press Enter to keep/omit]: " __input
        if [ -n "${__input}" ]; then
            NUMBER_OVERRIDE="$__input"
        fi
    else
        read -p "Number override [press Enter to omit]: " __input
        if [ -n "${__input}" ]; then
            NUMBER_OVERRIDE="$__input"
        fi
    fi

    # Dry-run (y/N)
    read -p "Dry run (no changes will be made)? [y/N]: " __yn
    if [[ "${__yn}" =~ ^[Yy] ]]; then
        DRY_RUN=true
    fi

    # cleanup temp variable
    unset __input __yn curns
    linebreak
fi

# If interactive mode was used, display the calculated command the script will run
if [ "$INTERACTIVE" = true ]; then
    # Build argument list for display
    cmd_path="./scripts/fix-commits.sh"
    display_args=()
    if [ -n "$START_COMMIT" ]; then
        display_args+=("--start-commit" "$START_COMMIT")
    fi
    if [ -n "$END_COMMIT" ]; then
        display_args+=("--end-commit" "$END_COMMIT")
    fi
    if [ "$IGNORE_BLOCKS" = true ]; then
        display_args+=("--ignore-blocks")
    fi
    if [ ${#NUMBER_SEARCH[@]} -gt 0 ]; then
        ns=$(IFS=,; echo "${NUMBER_SEARCH[*]}")
        display_args+=("--number-search" "$ns")
    fi
    if [ -n "$NUMBER_OVERRIDE" ]; then
        # Normalize and only include the override in the printed command if it differs from the detected step
        no_norm=$(normalize_step "$NUMBER_OVERRIDE")
        if [ -z "$DETECTED_STEP" ] || [ "$no_norm" != "$DETECTED_STEP" ]; then
            display_args+=("--number-override" "$no_norm")
        fi
    fi
    if [ -n "$BATCH_MESSAGE" ]; then
        # If user provided an original base64, prefer including that in displayed make command
        if [ -n "$MESSAGE_B64" ]; then
            display_args+=("--message-base64" "$MESSAGE_B64")
        else
            display_args+=("-m" "$BATCH_MESSAGE")
        fi
    fi
    if [ "$DRY_RUN" = true ]; then
        display_args+=("--dry-run")
    fi

    # Do not precompute a printf-escaped 'joined' (it can produce $'...' for non-ASCII).
    # We'll use SHELL_JOINED / MAKE_JOINED below which handle base64 encoding when needed.

    linebreak
    print_info "Calculated command based on your interactive choices:"
    # Build a shell-friendly invocation for direct script running and convert non-ASCII messages
    SHELL_JOINED=""
    skip_next=false
    i=0
    while [ $i -lt ${#display_args[@]} ]; do
        a="${display_args[$i]}"
        if [ "$skip_next" = true ]; then
            skip_next=false
            i=$((i+1))
            continue
        fi
        if [ "$a" = "-m" ] || [ "$a" = "--message" ]; then
            val="${display_args[$((i+1))]}"
            if [ "$(is_shell_printable "$val")" -eq 1 ]; then
                esc=$(printf "%q" "-m")
                vesc=$(printf "%q" "$val")
                SHELL_JOINED="$SHELL_JOINED $esc $vesc"
            else
                b64=$(b64_of "$val")
                esc=$(printf "%q" "--message-base64")
                vesc=$(printf "%q" "$b64")
                SHELL_JOINED="$SHELL_JOINED $esc $vesc"
            fi
            skip_next=true
        else
            esc=$(printf "%q" "$a")
            SHELL_JOINED="$SHELL_JOINED $esc"
        fi
        i=$((i+1))
    done

    print_code "$cmd_path$SHELL_JOINED"
    # Build a Make-friendly invocation but omit any -m <msg> that contains non-ASCII
    MAKE_JOINED=""
    skip_next=false
    omitted_message=false
    i=0
    while [ $i -lt ${#display_args[@]} ]; do
        a="${display_args[$i]}"
        if [ "$skip_next" = true ]; then
            skip_next=false
            i=$((i+1))
            continue
        fi
        if [ "$a" = "-m" ] || [ "$a" = "--message" ]; then
            # lookahead to value
            val="${display_args[$((i+1))]}"
            # Use helper to check ascii-ness robustly
            if [ "$(is_shell_printable "$val")" -eq 1 ]; then
                esc=$(printf "%q" "-m")
                vesc=$(printf "%q" "$val")
                MAKE_JOINED="$MAKE_JOINED $esc $vesc"
                skip_next=true
            else
                # include base64-safe message flag
                b64=$(b64_of "$val")
                esc=$(printf "%q" "--message-base64")
                vesc=$(printf "%q" "$b64")
                MAKE_JOINED="$MAKE_JOINED $esc $vesc"
                omitted_message=true
                skip_next=true
            fi
        else
            esc=$(printf "%q" "$a")
            MAKE_JOINED="$MAKE_JOINED $esc"
        fi
        i=$((i+1))
    done

    print_info "Equivalent make invocation (wrapper supports positional shortcut forms):"
    if [ -n "$MAKE_JOINED" ]; then
        print_code "make fix-commits --$MAKE_JOINED"
    else
        print_code "make fix-commits"
    fi
    if [ "$omitted_message" = true ]; then
        print_warning "Note: message contained non-ASCII characters and was omitted from the make invocation; use the 'Safe (Unicode) reproducible command' shown below to run exactly."
    fi
    # Also print a Unicode-safe python runner that decodes base64 arguments and invokes the script.
    # This avoids problems with non-ASCII characters (e.g. ellipsis) and exotic quoting.
    py_b64_args=()
    for a in "${display_args[@]}"; do
        # base64-encode each argument (no newlines)
        b64=$(printf "%s" "$a" | base64 | tr -d '\n') || b64=""
        py_b64_args+=("$b64")
    done
    if [ ${#py_b64_args[@]} -gt 0 ]; then
        linebreak
        print_info "Safe (Unicode) reproducible command using python3:"
        # Build a small heredoc that decodes and runs the script; print without executing
        printf "»%s %s\n" "" "python3 - <<'PY'" >/dev/null 2>&1 || true
        # Construct printed heredoc content
        PY_CONTENT="import base64,subprocess\nargs=["
        for b in "${py_b64_args[@]}"; do
            PY_CONTENT+="base64.b64decode('$b').decode('utf-8'),"
        done
        PY_CONTENT+="]\nsubprocess.run(['./scripts/fix-commits.sh']+args)\n"
        # Use print_code to show the heredoc (preserve newlines)
        # Surround with PY markers as printed to the user
        print_code "python3 - <<'PY'\n${PY_CONTENT}PY"
        linebreak
    fi
    linebreak
 fi

# Validate commits if provided
if [ -n "$START_COMMIT" ]; then
    if ! git cat-file -e "${START_COMMIT}^{commit}" 2>/dev/null; then
        print_error "Start commit '$START_COMMIT' not found"
        exit 1
    fi
fi
if [ -n "$END_COMMIT" ]; then
    if ! git cat-file -e "${END_COMMIT}^{commit}" 2>/dev/null; then
        print_error "End commit '$END_COMMIT' not found"
        exit 1
    fi
fi

# Build candidate commit list (chronological: oldest -> newest)
if [ -n "$START_COMMIT" ]; then
    RANGE="${START_COMMIT}^..${END_COMMIT:-HEAD}"
    CANDIDATE_COMMITS=()
    while IFS= read -r line; do
        CANDIDATE_COMMITS+=("$line")
    done < <(git rev-list --reverse "$RANGE")
else
    if [ -n "$END_COMMIT" ]; then
        CANDIDATE_COMMITS=()
        while IFS= read -r line; do
            CANDIDATE_COMMITS+=("$line")
        done < <(git rev-list --reverse "${END_COMMIT}")
    else
        CANDIDATE_COMMITS=()
        while IFS= read -r line; do
            CANDIDATE_COMMITS+=("$line")
        done < <(git rev-list --reverse HEAD)
    fi
fi

if [ ${#CANDIDATE_COMMITS[@]} -eq 0 ]; then
    print_error "No commits found in the specified range"
    exit 1
fi

# Helper: extract step number from commit subject (returns empty if none)
extract_step_from_msg() {
    echo "$1" | sed -n 's/.*ai: \[\([0-9]*\)\].*/\1/p' | sed 's/^0*//'
}

# Helper: normalize step number (remove leading zeros, empty -> empty)
# (defined earlier; keep single definition only)
# normalize_step() { ... }

# Helper: parse a number/search string like "10,11,58-60" into NUMBER_SEARCH array
# (defined earlier; reuse existing function; no duplicate here)
# parse_number_search() { ... }

# Helper: check if a step is allowed by NUMBER_SEARCH (if specified)
is_step_allowed() {
    local s="$1"
    if [ ${#NUMBER_SEARCH[@]} -eq 0 ]; then
        # no explicit filter, allow all
        return 0
    fi
    for v in "${NUMBER_SEARCH[@]}"; do
        # trim leading zeros from v
        v=$(normalize_step "$v")
        if [ "$v" = "$s" ]; then
            return 0
        fi
    done
    return 1
}

# Find the last (newest) commit in the candidate range that matches ai: [NNN]
DETECTED_INDEX=-1
DETECTED_STEP=""
for (( idx=${#CANDIDATE_COMMITS[@]}-1; idx>=0; idx-- )); do
    chash=${CANDIDATE_COMMITS[$idx]}
    subject=$(git log --format=%s -1 "$chash")
    step=$(extract_step_from_msg "$subject")
    if [ -n "$step" ]; then
        step_norm=$(normalize_step "$step")
        # If number search is provided, ensure this step is allowed
        if is_step_allowed "$step_norm"; then
            DETECTED_INDEX=$idx
            DETECTED_STEP=$step_norm
            break
        fi
    fi
done

# If we didn't detect any matching commit but a NUMBER_SEARCH was given, we may still proceed (empty set handled later).
if [ "$DETECTED_INDEX" -eq -1 ] && [ -z "$NUMBER_OVERRIDE" ] && [ ${#NUMBER_SEARCH[@]} -eq 0 ]; then
    print_error "No AI commits found in the specified range matching the criteria"
    print_info "Try --number-search or check the commit range"
    exit 1
fi

# Determine the step we will use when editing messages (override only affects editing)
if [ -n "$NUMBER_OVERRIDE" ]; then
    EDIT_STEP=$(normalize_step "$NUMBER_OVERRIDE")
else
    EDIT_STEP="$DETECTED_STEP"
fi

# If override provided, ensure detected step is also set to the override so selection logic uses it
if [ -n "$NUMBER_OVERRIDE" ]; then
    DETECTED_STEP="$EDIT_STEP"
fi

# PADDED_STEP used later for prompts and tags; leave empty if no EDIT_STEP
if [ -n "$EDIT_STEP" ]; then
    PADDED_STEP=$(printf "%03d" "$EDIT_STEP")
else
    PADDED_STEP=""
fi

# Decide selection mode: allow auto-inclusion when non-interactive and a DETECTED_STEP exists
# EFFECTIVE_IGNORE_BLOCKS will be used instead of raw IGNORE_BLOCKS during selection
EFFECTIVE_IGNORE_BLOCKS="$IGNORE_BLOCKS"
# If user didn't pass --number-search and script is non-interactive and we detected a step,
# include all commits with that detected step (so non-interactive runs act across history)
if [ "$EFFECTIVE_IGNORE_BLOCKS" = false ] && [ ${#NUMBER_SEARCH[@]} -eq 0 ] && [ -n "$DETECTED_STEP" ] && [ "$INTERACTIVE" = false ]; then
    EFFECTIVE_IGNORE_BLOCKS=true
fi

# Build the list of commits to operate on
COMMIT_HASHES=()
if [ "$EFFECTIVE_IGNORE_BLOCKS" = true ]; then
    # Include all commits in the candidate range that match NUMBER_SEARCH (if provided),
    # otherwise match DETECTED_STEP (the most recent matching step).
    for chash in "${CANDIDATE_COMMITS[@]}"; do
        subject=$(git log --format=%s -1 "$chash")
        step=$(extract_step_from_msg "$subject")
        if [ -n "$step" ]; then
            step_norm=$(normalize_step "$step")
            if [ ${#NUMBER_SEARCH[@]} -gt 0 ]; then
                if is_step_allowed "$step_norm"; then
                    COMMIT_HASHES+=("$chash")
                fi
            else
                # no NUMBER_SEARCH provided, fall back to detected step if available
                if [ -n "$DETECTED_STEP" ]; then
                    if [ "$step_norm" = "$DETECTED_STEP" ]; then
                        COMMIT_HASHES+=("$chash")
                    fi
                fi
            fi
        fi
    done
else
    # Connected-block mode
    if [ ${#NUMBER_SEARCH[@]} -gt 0 ]; then
        # For each matching commit in the candidate range, collect its connected block
        for (( idx=${#CANDIDATE_COMMITS[@]}-1; idx>=0; idx-- )); do
            chash=${CANDIDATE_COMMITS[$idx]}
            subject=$(git log --format=%s -1 "$chash")
            step=$(extract_step_from_msg "$subject")
            if [ -z "$step" ]; then
                continue
            fi
            step_norm=$(normalize_step "$step")
            if ! is_step_allowed "$step_norm"; then
                continue
            fi

            # Walk backwards from idx to gather the connected block for this step
            block=()
            j=$idx
            while [ $j -ge 0 ]; do
                ch=${CANDIDATE_COMMITS[$j]}
                subj=$(git log --format=%s -1 "$ch")
                st=$(extract_step_from_msg "$subj")
                st_norm=$(normalize_step "$st")

                # Stop if step differs
                # If this commit has no step, stop
                if [ -z "$st_norm" ]; then
                    break
                fi

                # If the step is not one of the allowed NUMBER_SEARCH values, stop
                if ! is_step_allowed "$st_norm"; then
                    break
                fi

                # Prepend to block (so block will be chronological)
                block=("$ch" "${block[@]}")

                # Check parent commit message (previous in candidate list)
                pj=$((j-1))
                if [ $pj -lt 0 ]; then
                    break
                fi
                pch=${CANDIDATE_COMMITS[$pj]}
                pmsg=$(git log --format=%s -1 "$pch")

                # Stop if parent is query/error
                # If this commit has no step, stop
                if [ -z "$st_norm" ]; then
                    break
                fi

                # If the step is not one of the allowed NUMBER_SEARCH values, stop
                if ! is_step_allowed "$st_norm"; then
                    break
                fi

                # Prepend to block (so block will be chronological)
                block=("$ch" "${block[@]}")

                # Check parent commit message (previous in candidate list)
                pj=$((j-1))
                if [ $pj -lt 0 ]; then
                    break
                fi
                pch=${CANDIDATE_COMMITS[$pj]}
                pmsg=$(git log --format=%s -1 "$pch")

                # Stop if parent is query/error (match broader variants: ai: ... query/error or 'updated query/errors')
                if echo "$pmsg" | grep -qiE "(ai:[[:space:]]*.*(query|error)s?)|(updated[[:space:]]+(query|error)s?)"; then
                    break
                fi

                # If parent has an AI step, only continue if that parent's step is allowed by NUMBER_SEARCH
                if echo "$pmsg" | grep -q "ai: \[[0-9]\+\]"; then
                    parent_step=$(extract_step_from_msg "$pmsg")
                    parent_step_norm=$(normalize_step "$parent_step")
                    if ! is_step_allowed "$parent_step_norm"; then
                        break
                    fi
                fi

                j=$pj
            done

            # Append block commits to COMMIT_HASHES if not already present
            for bh in "${block[@]}"; do
                if ! array_contains "$bh" "${COMMIT_HASHES[@]}"; then
                    COMMIT_HASHES+=("$bh")
                fi
            done
        done
    else
        # Original single-block behavior: walk backwards from DETECTED_INDEX
        if [ "$DETECTED_INDEX" -ge 0 ]; then
            idx=$DETECTED_INDEX
            while [ $idx -ge 0 ]; do
                chash=${CANDIDATE_COMMITS[$idx]}
                subject=$(git log --format=%s -1 "$chash")
                step=$(extract_step_from_msg "$subject")

                step_norm=$(normalize_step "$step")
                # If no step or not matching the detected step, stop
                if [ -z "$step_norm" ] || [ "$step_norm" != "$DETECTED_STEP" ]; then
                    break
                fi

                # Prepend to keep chronological order
                COMMIT_HASHES=("$chash" "${COMMIT_HASHES[@]}")

                # Prepare to check parent (in candidate array)
                idx=$((idx-1))
                if [ $idx -lt 0 ]; then
                    break
                fi

                parent_chash=${CANDIDATE_COMMITS[$idx]}
                parent_msg=$(git log --format=%s -1 "$parent_chash")

                # If parent is a query/error update, stop (do not include parent)
                if echo "$parent_msg" | grep -qE "(ai: updated query|ai: updated errors)"; then
                    print_info "Stopping at query/error commit: $parent_msg"
                    break
                fi

                # If parent is a different AI step, stop
                if echo "$parent_msg" | grep -q "ai: \[[0-9]\+\]" && ! echo "$parent_msg" | grep -q "ai: \[$DETECTED_STEP\]"; then
                    print_info "Stopping at different AI step: $parent_msg"
                    break
                fi
            done
        fi
    fi
fi

COMMIT_COUNT=${#COMMIT_HASHES[@]}

# Re-order COMMIT_HASHES to be chronological (oldest -> newest) using CANDIDATE_COMMITS ordering
if [ ${#COMMIT_HASHES[@]} -gt 0 ]; then
    ORDERED_COMMITS=()
    for ch in "${CANDIDATE_COMMITS[@]}"; do
        for target in "${COMMIT_HASHES[@]}"; do
            if [ "$ch" = "$target" ]; then
                ORDERED_COMMITS+=("$ch")
                break
            fi
        done
    done
    # Replace COMMIT_HASHES with ordered list
    COMMIT_HASHES=("${ORDERED_COMMITS[@]}")
fi

COMMIT_COUNT=${#COMMIT_HASHES[@]}

if [ "$COMMIT_COUNT" -eq 0 ]; then
    print_error "No commits found matching the specified criteria"
    exit 1
fi

print_success "Found $COMMIT_COUNT commit(s) matching criteria"

# Detect if there's a preceding query/error commit before our batch and show its diff
# Strategy: 1) If first_hash is inside CANDIDATE_COMMITS, scan backwards up to N commits in that list.
#           2) Fallback: use git rev-list to examine up to N parent commits before first_hash.
QUERY_ERROR_COMMIT=""
SEARCH_LIMIT=20
if [ ${#COMMIT_HASHES[@]} -gt 0 ]; then
    first_hash=${COMMIT_HASHES[0]}
    found=""

    # 1) If present in CANDIDATE_COMMITS, search there first (backwards)
    first_idx=-1
    for i in "${!CANDIDATE_COMMITS[@]}"; do
        if [ "${CANDIDATE_COMMITS[$i]}" = "$first_hash" ]; then
            first_idx=$i
            break
        fi
    done

    if [ $first_idx -ge 0 ]; then
        count=0
        CHECKED_CANDIDATE=()
        for (( j=first_idx-1; j>=0 && count<SEARCH_LIMIT; j-- )); do
            ch=${CANDIDATE_COMMITS[$j]}
            subj=$(git log --format=%s -1 "$ch" 2>/dev/null || true)
            CHECKED_CANDIDATE+=("$ch:$subj")
            # Detect query/error commits more broadly (case-insensitive, allow prefixes/emojis)
            if echo "$subj" | grep -qiE "(ai:[[:space:]]*.*(query|error)s?)|(updated[[:space:]]+(query|error)s?)"; then
                QUERY_ERROR_COMMIT="$ch"
                found=1
                break
            fi
            count=$((count+1))
        done
    fi

    # 2) Fallback: use git rev-list to walk history before first_hash
    if [ -z "$found" ]; then
        count=0
        CHECKED_REVLIST=()
        while IFS= read -r ch && [ $count -lt $SEARCH_LIMIT ]; do
            subj=$(git log --format=%s -1 "$ch" 2>/dev/null || true)
            CHECKED_REVLIST+=("$ch:$subj")
            if echo "$subj" | grep -qiE "(ai:[[:space:]]*.*(query|error)s?)|(updated[[:space:]]+(query|error)s?)"; then
                QUERY_ERROR_COMMIT="$ch"
                found=1
                break
            fi
            count=$((count+1))
        done < <(git rev-list --max-count=$SEARCH_LIMIT "$first_hash^" 2>/dev/null || true)
    fi

    if [ -n "$QUERY_ERROR_COMMIT" ]; then
        linebreak
        print_info "Detected preceding query/error commit:"
        git log --oneline -1 "$QUERY_ERROR_COMMIT"
        echo "Showing diff for the query/error commit (context):"
        # Prefer showing diffs for known AI files under ai/ and ai/plugin_template/
        git --no-pager show --name-only --pretty="%h %s" "$QUERY_ERROR_COMMIT"
        git --no-pager show "$QUERY_ERROR_COMMIT" -- ai/query.md ai/errors.md ai/plugin_template/query.md ai/plugin_template/errors.md 2>/dev/null || git --no-pager show "$QUERY_ERROR_COMMIT" || true
        linebreak
    fi
    # Fallback: if we couldn't find a commit by message, check whether any of the inspected commits modified ai/ files
    if [ -z "$QUERY_ERROR_COMMIT" ]; then
        # Check candidate list we inspected first
        if [ ${#CHECKED_CANDIDATE[@]} -gt 0 ]; then
            for entry in "${CHECKED_CANDIDATE[@]}"; do
                ch=$(echo "$entry" | cut -d: -f1)
                # list files changed in commit and look for ai/ paths
                if git show --name-only --pretty="" "$ch" 2>/dev/null | grep -qE "^ai/|^ai/plugin_template/"; then
                    QUERY_ERROR_COMMIT="$ch"
                    linebreak
                    print_info "Detected preceding query/error commit by file changes:"
                    git log --oneline -1 "$QUERY_ERROR_COMMIT"
                    echo "Showing diff for the query/error commit (context):"
                    git --no-pager show --name-only --pretty="%h %s" "$QUERY_ERROR_COMMIT"
                    git --no-pager show "$QUERY_ERROR_COMMIT" -- ai/query.md ai/errors.md ai/plugin_template/query.md ai/plugin_template/errors.md 2>/dev/null || git --no-pager show "$QUERY_ERROR_COMMIT" || true
                    linebreak
                    break
                fi
            done
        fi

        # If still not found, check the rev-list entries we inspected
        if [ -z "$QUERY_ERROR_COMMIT" ] && [ ${#CHECKED_REVLIST[@]} -gt 0 ]; then
            for entry in "${CHECKED_REVLIST[@]}"; do
                ch=$(echo "$entry" | cut -d: -f1)
                if git show --name-only --pretty="" "$ch" 2>/dev/null | grep -qE "^ai/|^ai/plugin_template/"; then
                    QUERY_ERROR_COMMIT="$ch"
                    linebreak
                    print_info "Detected preceding query/error commit by file changes:"
                    git log --oneline -1 "$QUERY_ERROR_COMMIT"
                    echo "Showing diff for the query/error commit (context):"
                    git --no-pager show --name-only --pretty="%h %s" "$QUERY_ERROR_COMMIT"
                    git --no-pager show "$QUERY_ERROR_COMMIT" -- ai/query.md ai/errors.md ai/plugin_template/query.md ai/plugin_template/errors.md 2>/dev/null || git --no-pager show "$QUERY_ERROR_COMMIT" || true
                    linebreak
                    break
                fi
            done
        fi
    fi
fi

# If nothing found, print a diagnostic list of the commits we checked (helps debugging why no query/error commit was found)
if [ -z "$found" ]; then
    linebreak
    print_info "No preceding query/error commit found within $SEARCH_LIMIT commits. Commits inspected (newest->oldest):"
    if [ ${#CHECKED_CANDIDATE[@]} -gt 0 ]; then
        for entry in "${CHECKED_CANDIDATE[@]}"; do
            ch=$(echo "$entry" | cut -d: -f1)
            subj=$(echo "$entry" | cut -d: -f2-)
            echo "  $ch - $subj"
        done
    elif [ ${#CHECKED_REVLIST[@]} -gt 0 ]; then
        for entry in "${CHECKED_REVLIST[@]}"; do
            ch=$(echo "$entry" | cut -d: -f1)
            subj=$(echo "$entry" | cut -d: -f2-)
            echo "  $ch - $subj"
        done
    else
        print_info "  (no commits inspected — first_hash may be unreachable)"
    fi
    linebreak
fi

# Show the commits we will fix
linebreak
print_info "Commits to fix:"
for commit_hash in "${COMMIT_HASHES[@]}"; do
    git log --oneline -1 "$commit_hash"
done
linebreak

# Ask for the message once for all commits in this batch
linebreak
print_info "Enter a message for all commits in this batch"
print_warning "Leave empty to keep individual 'running…' messages"
print_warning "Press Ctrl+C to cancel"
linebreak
# Show a short red dry-run reminder at the prompt time (so user knows this is a dry-run), but do not run the simulation yet
if [ "$DRY_RUN" = true ]; then
    echo -e "${RED}⚠ DRY RUN: No changes will be made. A simulated rebase will be shown after you enter the message.${NC}"
fi
# If a message was provided via CLI, show it as the current default and allow edit
if [ -n "$BATCH_MESSAGE" ]; then
    read -p "Message for step [$PADDED_STEP] (current: $BATCH_MESSAGE) [Enter to keep]: " __input
    if [ -n "${__input}" ]; then
        BATCH_MESSAGE="$__input"
    fi
else
    read -p "Message for step [$PADDED_STEP]: " __input
    if [ -n "${__input}" ]; then
        BATCH_MESSAGE="$__input"
    fi
fi
unset __input
linebreak

# If dry-run requested, now show simulated rebase operations and exit before any destructive actions
if [ "$DRY_RUN" = true ]; then
    # Print the dry-run header
    PRINT_DRY_RUN_HEADER
    # Determine REBASE_PARENT similar to actual rebase logic
    if [ -n "$QUERY_ERROR_COMMIT" ]; then
        REBASE_PARENT=$(git rev-parse "$QUERY_ERROR_COMMIT^" 2>/dev/null || true)
    else
        FIRST_COMMIT="${COMMIT_HASHES[0]}"
        REBASE_PARENT=$(git rev-parse "${FIRST_COMMIT}^" 2>/dev/null || true)
    fi

    if [ -z "$REBASE_PARENT" ]; then
        print_warning "Could not determine rebase parent; aborting dry-run simulation"
        exit 0
    fi

    # Build squash map (hashes that should be squashed into previous)
    SQUASH_SET=()
    for pair in "${SQUASH_COMMITS[@]}"; do
        idx2=$(echo "$pair" | cut -d: -f2)
        if [ -n "${COMMIT_HASHES[$idx2]}" ]; then
            SQUASH_SET+=("${COMMIT_HASHES[$idx2]}")
        fi
    done

    # Build modify set from COMMIT_HASHES and optional QUERY_ERROR_COMMIT
    MODIFY_SET=("${COMMIT_HASHES[@]}")
    if [ -n "$QUERY_ERROR_COMMIT" ]; then
        MODIFY_SET+=("$QUERY_ERROR_COMMIT")
    fi

    # Helper to check membership
    in_set() {
        local needle="$1"; shift
        for x in "$@"; do
            if [ "$x" = "$needle" ]; then
                return 0
            fi
        done
        return 1
    }

    # Build the todo commits (what git rebase -i would show) from REBASE_PARENT..HEAD
    TODO_COMMITS=()
    while IFS= read -r line; do
        TODO_COMMITS+=("$line")
    done < <(git rev-list --reverse "$REBASE_PARENT..HEAD")

    # Simulate walking the todo and print operations
    echo "🧾 Simulated rebase todo (from $REBASE_PARENT..HEAD):"
    echo
    substep_counter=1

    # Compute simulated TOTAL (account for squashes)
    if [ "$DO_SQUASH" = true ]; then
        SIM_TOTAL=$((COMMIT_COUNT - ${#SQUASH_COMMITS[@]}))
    else
        SIM_TOTAL=$COMMIT_COUNT
    fi

    for th in "${TODO_COMMITS[@]}"; do
        subj=$(git log --format='%s' -1 "$th" 2>/dev/null || true)
        # Determine if this commit will be squashed
        should_squash=false
        if in_set "$th" "${SQUASH_SET[@]}"; then
            should_squash=true
        fi

        # Determine if we'll modify this commit
        will_modify=false
        if in_set "$th" "${MODIFY_SET[@]}"; then
            will_modify=true
        fi

        if [ "$should_squash" = true ]; then
            # Squash line
            echo "🔀 squash $th $subj"
            # If commit is also modified, note that it'll be squashed (message merging)
            if [ "$will_modify" = true ]; then
                echo "    🧩 (will be squashed into previous commit; modified message may be combined)"
            fi
        else
            # pick line
            echo "✅ pick   $th $subj"
            if [ "$will_modify" = true ]; then
                # Show what the rebase editor would exec: compute new message
                # For AI commits, compute STEP and SUBSTEP from the commit message
                if echo "$subj" | grep -qE "ai: \[[0-9]+\]"; then
                    orig_step=$(echo "$subj" | sed -n 's/.*ai: \[\([0-9]*\)\].*/\1/p' | sed 's/^0*//')
                    # Extract current substep if present
                    orig_substep=$(echo "$subj" | sed -n 's/.*(\([0-9]*\)\/.*)/\1/p' || true)
                    # Determine the step to write: if NUMBER_OVERRIDE specified, use that, else use orig_step
                    if [ -n "$NUMBER_OVERRIDE" ]; then
                        write_step=$(echo "$NUMBER_OVERRIDE" | sed 's/^0*//')
                    else
                        write_step="$orig_step"
                    fi
                    padded_step=$(printf "%03d" "${write_step:-0}")
                    # Determine message body: if BATCH_MESSAGE provided, use it; otherwise keep existing unless it's 'running…'
                    if [ -n "$BATCH_MESSAGE" ]; then
                        new_body="$BATCH_MESSAGE"
                    else
                        # Extract between ] and (  -> message body
                        new_body=$(echo "$subj" | sed 's/.*\] \(.*\) (.*/\1/' || true)
                        if echo "$new_body" | grep -qE "^running[.…]+$"; then
                            new_body="running…"
                        fi
                    fi
                    # Compute SUB and TOTAL for display
                    SUB_DISPLAY=$substep_counter
                    TOTAL_DISPLAY=$SIM_TOTAL
                    # If this commit will be amended (i.e. will_modify true), show the amended message
                    echo "    ✏️ will amend message -> ✉️ \"✨ ai: [$padded_step] $new_body ($SUB_DISPLAY/$TOTAL_DISPLAY)\""
                    # Only increment substep if this commit results in a separate amended commit
                    if [ "$should_squash" = false ]; then
                        substep_counter=$((substep_counter + 1))
                    fi
                else
                    # Non-AI commit modified (e.g., query/error) will be appended with BATCH_MESSAGE
                    if [ -n "$BATCH_MESSAGE" ]; then
                        echo "    ✏️ will amend message -> \"$subj: $BATCH_MESSAGE\""
                    else
                        echo "    ✏️ will keep existing message unless BATCH_MESSAGE provided"
                    fi
                fi
            fi
        fi
    done
    echo
    # Also print the final reproducible command (dry-run should show same summary as real run)
    FINAL_CMD_PATH="./scripts/fix-commits.sh"
    FINAL_ARGS=()
    if [ -n "$START_COMMIT" ]; then
        FINAL_ARGS+=("--start-commit" "$START_COMMIT")
    fi
    if [ -n "$END_COMMIT" ]; then
        FINAL_ARGS+=("--end-commit" "$END_COMMIT")
    fi
    if [ "$IGNORE_BLOCKS" = true ]; then
        FINAL_ARGS+=("--ignore-blocks")
    fi
    # effective ns
    ns=""
    if [ ${#NUMBER_SEARCH[@]} -gt 0 ]; then
        ns=$(IFS=,; echo "${NUMBER_SEARCH[*]}")
    elif [ -n "$DETECTED_STEP" ]; then
        ns="$DETECTED_STEP"
    fi
    if [ -n "$ns" ]; then
        FINAL_ARGS+=("--number-search" "$ns")
    fi
    if [ -n "$NUMBER_OVERRIDE" ]; then
        no_norm=$(normalize_step "$NUMBER_OVERRIDE")
        include_override=true
        if [ -n "$ns" ]; then
            if echo "$ns" | grep -q ','; then
                include_override=true
            else
                ns_norm=$(normalize_step "$ns")
                if [ "$no_norm" = "$ns_norm" ]; then
                    include_override=false
                fi
            fi
        fi
        if [ "$include_override" = true ]; then
            FINAL_ARGS+=("--number-override" "$no_norm")
        fi
    fi
    if [ -n "$BATCH_MESSAGE" ]; then
        if [ -n "$MESSAGE_B64" ]; then
            FINAL_ARGS+=("--message-base64" "$MESSAGE_B64")
        else
            FINAL_ARGS+=("-m" "$BATCH_MESSAGE")
        fi
    fi
    if [ "$DRY_RUN" = true ]; then
        FINAL_ARGS+=("--dry-run")
    fi

    # Build and print shell-friendly and make-friendly invocations
    SHELL_FINAL_JOINED=""
    skip_next=false
    j=0
    while [ $j -lt ${#FINAL_ARGS[@]} ]; do
        a="${FINAL_ARGS[$j]}"
        if [ "$skip_next" = true ]; then
            skip_next=false
            j=$((j+1))
            continue
        fi
        if [ "$a" = "-m" ] || [ "$a" = "--message" ]; then
            val="${FINAL_ARGS[$((j+1))]}"
            if [ "$(is_shell_printable "$val")" -eq 1 ]; then
                esc=$(printf "%q" "-m")
                vesc=$(printf "%q" "$val")
                SHELL_FINAL_JOINED="$SHELL_FINAL_JOINED $esc $vesc"
            else
                b64=$(b64_of "$val")
                esc=$(printf "%q" "--message-base64")
                vesc=$(printf "%q" "$b64")
                SHELL_FINAL_JOINED="$SHELL_FINAL_JOINED $esc $vesc"
                omitted_message=true
            fi
            skip_next=true
        else
            esc=$(printf "%q" "$a")
            SHELL_FINAL_JOINED="$SHELL_FINAL_JOINED $esc"
        fi
        j=$((j+1))
    done

    print_info "Final command to reproduce this operation (dry-run):"
    print_code "$FINAL_CMD_PATH$SHELL_FINAL_JOINED"

    MAKE_FINAL_JOINED=""
    omitted_message=false
    skip_next=false
    j=0
    while [ $j -lt ${#FINAL_ARGS[@]} ]; do
        a="${FINAL_ARGS[$j]}"
        if [ "$skip_next" = true ]; then
            skip_next=false
            j=$((j+1))
            continue
        fi
        if [ "$a" = "-m" ] || [ "$a" = "--message" ]; then
            val="${FINAL_ARGS[$((j+1))]}"
            if [ "$(is_shell_printable "$val")" -eq 1 ]; then
                esc=$(printf "%q" "-m")
                vesc=$(printf "%q" "$val")
                MAKE_FINAL_JOINED="$MAKE_FINAL_JOINED $esc $vesc"
                skip_next=true
            else
                b64=$(b64_of "$val")
                esc=$(printf "%q" "--message-base64")
                vesc=$(printf "%q" "$b64")
                MAKE_FINAL_JOINED="$MAKE_FINAL_JOINED $esc $vesc"
                omitted_message=true
                skip_next=true
            fi
        else
            esc=$(printf "%q" "$a")
            MAKE_FINAL_JOINED="$MAKE_FINAL_JOINED $esc"
        fi
        j=$((j+1))
    done

    print_info "Or via make (positional shortcuts supported):"
    if [ -n "$MAKE_FINAL_JOINED" ]; then
        print_code "make fix-commits --$MAKE_FINAL_JOINED"
    else
        print_code "make fix-commits"
    fi
    if [ "$omitted_message" = true ]; then
        print_warning "Note: message contained non-ASCII characters and was omitted from the make invocation; use the 'Safe (Unicode) reproducible command' shown above to run exactly."
    fi

    echo
    echo "⚠ This is a dry-run simulation; no tags or rebase operations were performed."
    exit 0
 fi

# Analyze commits for potential squashing
print_info "Analyzing commits for potential squashing..."

# Array to track which commits to squash
SQUASH_COMMITS=()

# Check each pair of consecutive commits
for ((i=0; i<${#COMMIT_HASHES[@]}-1; i++)); do
    COMMIT1="${COMMIT_HASHES[$i]}"
    COMMIT2="${COMMIT_HASHES[$((i+1))]}"

    # Check if these commits can be squashed by analyzing line overlaps
    can_squash=true

    # Get all files changed in both commits
    FILES1=$(git diff-tree --no-commit-id --name-only -r "$COMMIT1" | sort)
    FILES2=$(git diff-tree --no-commit-id --name-only -r "$COMMIT2" | sort)

    # Find files that appear in both commits
    COMMON_FILES=$(comm -12 <(echo "$FILES1") <(echo "$FILES2"))

    if [ -n "$COMMON_FILES" ]; then
        # They touch some common files - check if they modify different lines
        while IFS= read -r file; do
            if [ -z "$file" ]; then
                continue
            fi

            # Get the line ranges modified in each commit for this file
            # Use git diff to see which lines were changed

            # Get parent of COMMIT1 to compare against
            PARENT1=$(git rev-parse "$COMMIT1^")

            # Get lines changed in COMMIT1 for this file
            LINES1=$(git diff "$PARENT1" "$COMMIT1" -- "$file" 2>/dev/null | grep '^@@' | sed 's/@@ -[0-9,]* +\([0-9,]*\).*/\1/')

            # Get lines changed in COMMIT2 for this file (comparing against COMMIT1)
            LINES2=$(git diff "$COMMIT1" "$COMMIT2" -- "$file" 2>/dev/null | grep '^@@' | sed 's/@@ -[0-9,]* +\([0-9,]*\).*/\1/')

            # Convert line ranges to actual line numbers for comparison
            # This is a simplified check - if we can't determine, assume overlap
            if [ -n "$LINES1" ] && [ -n "$LINES2" ]; then
                # Extract starting line numbers
                START1=$(echo "$LINES1" | head -1 | cut -d, -f1)
                START2=$(echo "$LINES2" | head -1 | cut -d, -f1)

                # Get ending line numbers (start + count, or just start if no comma)
                if echo "$LINES1" | head -1 | grep -q ','; then
                    COUNT1=$(echo "$LINES1" | head -1 | cut -d, -f2)
                    END1=$((START1 + COUNT1))
                else
                    END1=$START1
                fi

                if echo "$LINES2" | head -1 | grep -q ','; then
                    COUNT2=$(echo "$LINES2" | head -1 | cut -d, -f2)
                    END2=$((START2 + COUNT2))
                else
                    END2=$START2
                fi

                # Check if ranges overlap
                # Ranges overlap if: START1 <= END2 AND START2 <= END1
                if [ "$START1" -le "$END2" ] && [ "$START2" -le "$END1" ]; then
                    # Lines overlap - cannot squash
                    can_squash=false
                    break
                fi
            else
                # Cannot determine line ranges safely - assume overlap
                can_squash=false
                break
            fi
        done <<< "$COMMON_FILES"
    fi

    if [ "$can_squash" = true ]; then
        SQUASH_COMMITS+=("$i:$((i+1))")
    fi
done

# Present squashing opportunities to the user
if [ ${#SQUASH_COMMITS[@]} -gt 0 ]; then
    linebreak
    print_info "Found commits that could potentially be squashed:"
    linebreak

    for pair in "${SQUASH_COMMITS[@]}"; do
        idx1=$(echo "$pair" | cut -d: -f1)
        idx2=$(echo "$pair" | cut -d: -f2)
        commit1="${COMMIT_HASHES[$idx1]}"
        commit2="${COMMIT_HASHES[$idx2]}"

        msg1=$(git log --format=%s -1 "$commit1")
        msg2=$(git log --format=%s -1 "$commit2")

        echo "  Commits $((idx1+1)) and $((idx2+1)):"
        echo "    [$((idx1+1))] $msg1"
        echo "    [$((idx2+1))] $msg2"

        # Show what files each touches
        files1=$(git diff-tree --no-commit-id --name-only -r "$commit1" | head -3)
        files2=$(git diff-tree --no-commit-id --name-only -r "$commit2" | head -3)
        echo "    Files in [$((idx1+1))]: $(echo "$files1" | tr '\n' ', ' | sed 's/,$//')"
        echo "    Files in [$((idx2+1))]: $(echo "$files2" | tr '\n' ', ' | sed 's/,$//')"
        linebreak
    done

    read -p "Would you like to squash these commits? (y/n) [y]: " SQUASH_CHOICE
    SQUASH_CHOICE=${SQUASH_CHOICE:-y}

    if [[ "$SQUASH_CHOICE" =~ ^[Yy]$ ]]; then
        print_info "Will squash the identified commits and adjust sub-numbering"
        DO_SQUASH=true
    else
        print_info "Keeping all commits separate"
        DO_SQUASH=false
    fi
else
    print_info "No squashing opportunities found (commits modify overlapping lines)"
    DO_SQUASH=false
fi
linebreak

# Create a temporary script for the rebase
REBASE_SCRIPT=$(mktemp)
trap "rm -f $REBASE_SCRIPT" EXIT

# Generate the rebase script
cat > "$REBASE_SCRIPT" << 'EOFSCRIPT'
#!/usr/bin/env bash
# Extract step and substep
# If an override step is provided via EDIT_STEP_ENV, prefer it
if [ -n "$EDIT_STEP_ENV" ]; then
    STEP="$EDIT_STEP_ENV"
else
    STEP=$(echo "$1" | sed 's/.*ai: \[\([0-9]*\)\].*/\1/' | sed 's/^0*//')
fi
STEP=$(echo "$STEP" | sed 's/^0*//')
SUBSTEP=$(echo "$1" | sed 's/.*(\([0-9]*\)\/.*/\1/')
TOTAL="TOTAL_PLACEHOLDER"

# Use override substep if provided (for renumbering after squash)
if [ -n "$SUBSTEP_OVERRIDE" ]; then
    SUBSTEP="$SUBSTEP_OVERRIDE"
fi

# Extract current message (everything between ] and ()
CURRENT_MSG=$(echo "$1" | sed 's/.*\] \(.*\) (.*/\1/')

# Use batch message from environment variable if provided, otherwise check individual message
if [ -n "$BATCH_MSG_ENV" ]; then
    NEW_MSG="$BATCH_MSG_ENV"
elif echo "$CURRENT_MSG" | grep -qE "^running[.…]+$"; then
    # Still default, keep it
    NEW_MSG="running…"
else
    # Keep existing non-default message
    NEW_MSG="$CURRENT_MSG"
fi

# Build the full commit message (without prefix)
PADDED_STEP=$(printf "%03d" "$STEP")
FULL_MSG="✨ ai: [$PADDED_STEP] $NEW_MSG ($SUBSTEP/$TOTAL)"
if [ -n "$COMMIT_PREFIX" ]; then
    case "$FULL_MSG" in
        "$COMMIT_PREFIX"*) echo "$FULL_MSG" ;;
        *) echo "$COMMIT_PREFIX$FULL_MSG" ;;
    esac
else
    echo "$FULL_MSG"
fi
EOFSCRIPT

# Replace placeholders
# Adjust total if squashing
if [ "$DO_SQUASH" = true ]; then
    ADJUSTED_TOTAL=$((COMMIT_COUNT - ${#SQUASH_COMMITS[@]}))
    sed -i.bak "s/TOTAL_PLACEHOLDER/$ADJUSTED_TOTAL/g" "$REBASE_SCRIPT"
else
    sed -i.bak "s/TOTAL_PLACEHOLDER/$COMMIT_COUNT/g" "$REBASE_SCRIPT"
fi

rm -f "$REBASE_SCRIPT.bak"

chmod +x "$REBASE_SCRIPT"

# Create a script for updating query/error commits
QUERY_ERROR_SCRIPT=$(mktemp)
trap "rm -f $COMMITS_TO_MODIFY $REBASE_SCRIPT $QUERY_ERROR_SCRIPT" EXIT

# The query/error commit message format may be: "<title>" or "<title>: <additional>".
# When re-running fixes we should replace the part after the last ":" with the new batch
# message rather than appending repeatedly. If there's no colon we append as before.
cat > "$QUERY_ERROR_SCRIPT" << 'EOFSCRIPT'
#!/usr/bin/env bash
# Update or append message to query/error commit

# Get the current commit message (passed in as first arg)
CURRENT_MSG="$1"

# If no batch message provided, keep the current message (respecting prefix)
if [ -z "$BATCH_MSG_ENV" ]; then
    FULL_MSG="$CURRENT_MSG"
else
    # If the message contains the known marker 'ai: updated query:' or 'ai: updated errors:'
    # replace everything after that marker with the new batch message. This avoids
    # repeated appends when the script is run multiple times.
    if echo "$CURRENT_MSG" | grep -qiE "ai:[[:space:]]*updated[[:space:]]\+\(query\|errors\):"; then
        # Extract up to and including the marker (preserve casing and any prefix)
        head_part=$(echo "$CURRENT_MSG" | sed -n 's/\(.*ai:[[:space:]]*updated[[:space:]]\+\(query\|errors\):\).*/\1/p')
        # Trim trailing whitespace from head_part
        head_part=$(echo "$head_part" | sed 's/[[:space:]]*$//')
        FULL_MSG="${head_part} ${BATCH_MSG_ENV}"
    else
        # Fallback: if there's any ':' present, replace after the last colon as before
        if echo "$CURRENT_MSG" | grep -q ":"; then
            head_part=$(echo "$CURRENT_MSG" | sed 's/\(.*\):.*/\1/')
            head_part=$(echo "$head_part" | sed 's/[[:space:]]*$//')
            FULL_MSG="${head_part}: ${BATCH_MSG_ENV}"
        else
            FULL_MSG="${CURRENT_MSG}: ${BATCH_MSG_ENV}"
        fi
    fi
fi

# Apply COMMIT_PREFIX if needed
if [ -n "$COMMIT_PREFIX" ]; then
    case "$FULL_MSG" in
        "$COMMIT_PREFIX"*) echo "$FULL_MSG" ;;
        *) echo "$COMMIT_PREFIX$FULL_MSG" ;;
    esac
else
    echo "$FULL_MSG"
fi
EOFSCRIPT

chmod +x "$QUERY_ERROR_SCRIPT"

# Replace COMMIT_PREFIX_PLACEHOLDER in query/error script (no-op kept for compatibility)
ESCAPED_PREFIX=$(echo "$COMMIT_PREFIX" | sed 's/[\/&]/\\&/g')
sed -i.bak "s/COMMIT_PREFIX_PLACEHOLDER/$ESCAPED_PREFIX/g" "$QUERY_ERROR_SCRIPT" 2>/dev/null || true
rm -f "$QUERY_ERROR_SCRIPT.bak" 2>/dev/null || true

# Find the parent commit (the commit before the first AI commit in this batch)
# If there's a query/error commit, start from before that
if [ -n "$QUERY_ERROR_COMMIT" ]; then
    REBASE_PARENT=$(git rev-parse "$QUERY_ERROR_COMMIT^" 2>/dev/null)
    if [ -z "$REBASE_PARENT" ]; then
        print_error "Could not find parent commit for $QUERY_ERROR_COMMIT. Aborting."
        exit 1
    fi
else
    FIRST_COMMIT="${COMMIT_HASHES[0]}"
    if [ -z "$FIRST_COMMIT" ]; then
        print_error "Could not find the first commit for step [$PADDED_STEP]. Aborting."
        exit 1
    fi
    REBASE_PARENT=$(git rev-parse "$FIRST_COMMIT^" 2>/dev/null)
    if [ -z "$REBASE_PARENT" ]; then
        print_error "Could not find parent commit for $FIRST_COMMIT. Aborting."
        exit 1
    fi
fi

# Create a set of commits to modify (for fast lookup)
COMMITS_TO_MODIFY=$(mktemp)
trap "rm -f $REBASE_SCRIPT $QUERY_ERROR_SCRIPT" EXIT

# Add all commits from our batch
for commit_hash in "${COMMIT_HASHES[@]}"; do
    echo "$commit_hash" >> "$COMMITS_TO_MODIFY"
done

# Add query/error commit to the list if it exists
if [ -n "$QUERY_ERROR_COMMIT" ]; then
    echo "$QUERY_ERROR_COMMIT" >> "$COMMITS_TO_MODIFY"
fi

# Create rebase editor script that modifies only our AI commits
REBASE_EDITOR=$(mktemp)
SQUASH_MAP=$(mktemp)
# create a temp file that will receive the new commit hashes (one per amended commit)
NEW_COMMIT_LIST_FILE=$(mktemp)
trap "rm -f $COMMITS_TO_MODIFY $REBASE_SCRIPT $QUERY_ERROR_SCRIPT $REBASE_EDITOR $SQUASH_MAP $NEW_COMMIT_LIST_FILE" EXIT

# Build squash map if needed
if [ "$DO_SQUASH" = true ]; then
    # Create a map of which commits to squash
    for pair in "${SQUASH_COMMITS[@]}"; do
        idx1=$(echo "$pair" | cut -d: -f1)
        idx2=$(echo "$pair" | cut -d: -f2)
        echo "${COMMIT_HASHES[$idx2]}" >> "$SQUASH_MAP"
    done
fi

cat > "$REBASE_EDITOR" << 'EOF'
#!/usr/bin/env bash
# This script modifies the git rebase todo list
# It adds exec commands only for the AI commits we want to fix
# And optionally marks commits for squashing

TODO_FILE="$1"
TEMP_FILE="${TODO_FILE}.tmp"

> "$TEMP_FILE"

# Track which substep we're on (for renumbering after squash)
current_substep=1

while IFS= read -r line; do
    # Extract commit hash from the line (format: "pick abc123 commit message")
    if [[ "$line" =~ ^pick[[:space:]]+([a-f0-9]+) ]]; then
        commit_hash="${BASH_REMATCH[1]}"

        # Check if this commit should be squashed
        should_squash=false
        if [ "$DO_SQUASH_ENV" = "true" ] && grep -q "^$commit_hash" "$SQUASH_MAP_FILE" 2>/dev/null; then
            should_squash=true
        fi

        # Check if this commit is in our list to modify
        if grep -q "^$commit_hash" "$COMMITS_TO_MODIFY_FILE"; then
            # This is an AI commit we want to fix
            commit_msg=$(git log --format=%s -1 "$commit_hash")

            # Use a unique temp file based on commit hash
            temp_msg_file="/tmp/new_msg_${commit_hash}.txt"

            # Check if this is a query/error commit
            if echo "$commit_msg" | grep -qE "(ai: updated query|ai: updated errors)"; then
                # Query/error commit - use the query/error script to append message
                echo "exec BATCH_MSG_ENV=\"\$BATCH_MSG_ENV\" $QUERY_ERROR_SCRIPT_FILE '$commit_msg' > $temp_msg_file" >> "$TEMP_FILE"
            else
                # Regular AI commit - use the regular script
                # Pass the current substep for renumbering
                # Also pass EDIT_STEP_ENV so the called script can use the override
                echo "exec BATCH_MSG_ENV=\"\$BATCH_MSG_ENV\" SUBSTEP_OVERRIDE=$current_substep EDIT_STEP_ENV=\"\$EDIT_STEP_ENV\" $REBASE_SCRIPT_FILE '$commit_msg' > $temp_msg_file" >> "$TEMP_FILE"

                # Only increment substep if not squashing this commit
                if [ "$should_squash" = false ]; then
                    current_substep=$((current_substep + 1))
                fi
            fi

            # Pick or squash
            if [ "$should_squash" = true ]; then
                # Change pick to squash
                echo "squash $commit_hash $(git log --format=%s -1 \"$commit_hash\")" >> "$TEMP_FILE"
            else
                # Keep the pick
                echo "$line" >> "$TEMP_FILE"
            fi

            # Add exec to amend with new message (only for non-squashed commits)
            if [ "$should_squash" = false ]; then
                # After amending, append the new commit hash to the NEW_COMMIT_LIST_FILE so we can show exact updated commits later
                echo "exec git commit --amend -m \"\$(cat $temp_msg_file)\" && echo \"\$(git rev-parse --verify HEAD)\" >> \"$NEW_COMMIT_LIST_FILE\" && rm -f $temp_msg_file" >> "$TEMP_FILE"
            else
                # For squashed commits, just clean up the temp file
                echo "exec rm -f $temp_msg_file" >> "$TEMP_FILE"
            fi
        else
            # Not an AI commit, keep as-is
            echo "$line" >> "$TEMP_FILE"
        fi
    else
        # Not a pick line (comment, etc), keep as-is
        echo "$line" >> "$TEMP_FILE"
    fi
done < "$TODO_FILE"

mv "$TEMP_FILE" "$TODO_FILE"
EOF

chmod +x "$REBASE_EDITOR"

# Export variables needed by the rebase editor
export COMMITS_TO_MODIFY_FILE="$COMMITS_TO_MODIFY"
export REBASE_SCRIPT_FILE="$REBASE_SCRIPT"
export QUERY_ERROR_SCRIPT_FILE="$QUERY_ERROR_SCRIPT"
export DO_SQUASH_ENV="$DO_SQUASH"
export SQUASH_MAP_FILE="$SQUASH_MAP"
# Export the path to the file that will contain the new commit hashes
export NEW_COMMIT_LIST_FILE="$NEW_COMMIT_LIST_FILE"

print_info "Starting interactive rebase..."
linebreak

# Create recovery tag before rebase
CURRENT_HEAD=$(git rev-parse HEAD)
DATE_STR=$(date +%Y-%m-%d_%H-%M-%S)
TIME_STR=$(date +%H%M%S)

# Build recovery tag name from template (always use padded step)
RECOVERY_TAG=$(echo "$RECOVERY_TAG_TEMPLATE" | sed "s/{step}/$PADDED_STEP/g" | sed "s/{date}/$DATE_STR/g" | sed "s/{time}/$TIME_STR/g")

# Create the recovery tag
if git tag "$RECOVERY_TAG" "$CURRENT_HEAD" 2>/dev/null; then
    print_success "Created recovery tag: $RECOVERY_TAG"
    print_info "If something goes wrong, you can recover with: git reset --hard $RECOVERY_TAG"
else
    print_warning "Could not create recovery tag (may already exist): $RECOVERY_TAG"
    exit 2
fi
linebreak

# Export the batch message as an environment variable (preserves all special characters)
export BATCH_MSG_ENV="$BATCH_MESSAGE"

# Export edit-step override for the rebase script (if any)
export EDIT_STEP_ENV="$EDIT_STEP"

# Create a custom git editor for handling squash commit messages
GIT_EDITOR_WRAPPER="$SCRIPT_DIR/fix-commits-editor-wrapper.sh"
GIT_EDITOR_REAL="$SCRIPT_DIR/fix-commits-editor-real.sh"
chmod +x "$GIT_EDITOR_WRAPPER" "$GIT_EDITOR_REAL"

# Save the current core.editor
ORIGINAL_CORE_EDITOR=$(git config --get core.editor || true)
# Set core.editor to our wrapper
GIT_EDITOR_WRAPPER_ABS=$(cd "$SCRIPT_DIR" && pwd)/fix-commits-editor-wrapper.sh
GIT_EDITOR_REAL_ABS=$(cd "$SCRIPT_DIR" && pwd)/fix-commits-editor-real.sh
export COMMIT_PREFIX="$COMMIT_PREFIX"
git config core.editor "$GIT_EDITOR_WRAPPER_ABS"

# Set up environment for the rebase
export GIT_SEQUENCE_EDITOR="$REBASE_EDITOR"
# (No need to set GIT_EDITOR, core.editor is used)

# Run the rebase
if git rebase -i "$REBASE_PARENT"; then
    print_success "Rebase completed successfully!"
    linebreak
    print_info "Updated commits:"
    # Calculate expected number of commits after squashing
    if [ "$DO_SQUASH" = true ]; then
        EXPECTED_COUNT=$((COMMIT_COUNT - ${#SQUASH_COMMITS[@]}))
    else
        EXPECTED_COUNT=$COMMIT_COUNT
    fi
    # Prefer using the exact new commit hashes produced during the rebase (if available)
    commits_after=()
    if [ -n "$NEW_COMMIT_LIST_FILE" ] && [ -f "$NEW_COMMIT_LIST_FILE" ] && [ -s "$NEW_COMMIT_LIST_FILE" ]; then
        # Read hashes in order and remove duplicates while preserving order
        while IFS= read -r h; do
            [ -z "$h" ] && continue
            skip=false
            for ex in "${commits_after[@]}"; do
                if [ "$ex" = "$h" ]; then
                    skip=true
                    break
                fi
            done
            if [ "$skip" = false ]; then
                commits_after+=("$h")
            fi
        done < "$NEW_COMMIT_LIST_FILE"
        # If EXPECTED_COUNT set, trim to that many
        if [ "$EXPECTED_COUNT" -ne 0 ]; then
            if [ ${#commits_after[@]} -gt $EXPECTED_COUNT ]; then
                # Keep first EXPECTED_COUNT entries
                commits_after=("${commits_after[@]:0:$EXPECTED_COUNT}")
            fi
        fi
    else
        # Fallback to the previous grep approach (best-effort)
        # shellcheck disable=SC2207
        commits_after=($(
          git log --oneline --pretty=format:"%H" --grep="ai: \[$PADDED_STEP\]" --reverse \
          | head -n "$EXPECTED_COUNT"
        ))
    fi

    # Loop over each hash and print a one-line summary
    for commit_hash in "${commits_after[@]}"; do
      git log --oneline -1 "$commit_hash"
    done
    linebreak
    print_success "All done! Commits have been fixed."
    linebreak

    # Restore the original core.editor
    if [ -n "$ORIGINAL_CORE_EDITOR" ]; then
        git config core.editor "$ORIGINAL_CORE_EDITOR"
    else
        git config --unset core.editor
    fi

    # Clean up old recovery tags
    print_info "Checking for old recovery tags to clean up..."

    # Get current branch
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

    # Find all tags matching the recovery pattern
    RECOVERY_PATTERN="fix-commits-backup-step-"
    OLD_TAGS=()

    while IFS= read -r tag; do
        if [ -z "$tag" ]; then
            continue
        fi

        # Skip the current recovery tag we just created
        if [ "$tag" = "$RECOVERY_TAG" ]; then
            continue
        fi

        # Check if tag is in the current branch
        if ! git merge-base --is-ancestor "$tag" HEAD 2>/dev/null; then
            # Tag is not in current branch history
            OLD_TAGS+=("$tag")
        fi
    done < <(git tag -l "${RECOVERY_PATTERN}*")

    if [ ${#OLD_TAGS[@]} -gt 0 ]; then
        linebreak
        print_warning "Found ${#OLD_TAGS[@]} old recovery tag(s) not in current branch:"
        for tag in "${OLD_TAGS[@]}"; do
            echo "  - $tag"
        done
        linebreak

        # read -p "Would you like to delete these old recovery tags? (y/n) [n]: " DELETE_TAGS
        DELETE_TAGS=${DELETE_TAGS:-n}

        if [[ "$DELETE_TAGS" =~ ^[Yy]$ ]]; then
            for tag in "${OLD_TAGS[@]}"; do
                if git tag -d "$tag" 2>/dev/null; then
                    print_success "Deleted tag: $tag"
                else
                    print_warning "Could not delete tag: $tag"
                fi
            done
            linebreak
            print_success "Old recovery tags cleaned up"
        else
            print_info "Keeping old recovery tags"
            # Print an actual git delete command including the tag names
            DELETE_CMD="git tag -d"
            for tag in "${OLD_TAGS[@]}"; do
                DELETE_CMD+=" $tag"
            done
            print_info "You can manually delete them later with: "
            print_code "$DELETE_CMD"
          fi
    else
        print_info "No old recovery tags found to clean up"
    fi

    # Also delete the current recovery tag now that rebase succeeded
    linebreak

    # read -p "Delete the recovery tag for this rebase? (y/n) [n]: " DELETE_CURRENT
    DELETE_CURRENT=${DELETE_CURRENT:-n}

    if [[ "$DELETE_CURRENT" =~ ^[Yy]$ ]]; then
        if git tag -d "$RECOVERY_TAG" 2>/dev/null; then
            print_success "Deleted recovery tag: $RECOVERY_TAG"
        fi
    else
        print_info "Keeping recovery tag: $RECOVERY_TAG"
        print_info "Delete it manually when no longer needed: "
        print_code "git tag -d $RECOVERY_TAG"
    fi
    linebreak

    # Print the final reproducible command (always) so the user can repeat it.
    # This appears before the recovery-tag cleanup prompt so it's visible in logs.
    FINAL_CMD_PATH="./scripts/fix-commits.sh"
    FINAL_ARGS=()
    if [ -n "$START_COMMIT" ]; then
        FINAL_ARGS+=("--start-commit" "$START_COMMIT")
    fi
    if [ -n "$END_COMMIT" ]; then
        FINAL_ARGS+=("--end-commit" "$END_COMMIT")
    fi
    if [ "$IGNORE_BLOCKS" = true ]; then
        FINAL_ARGS+=("--ignore-blocks")
    fi

    # Compute effective number-search string (ns): prefer explicit NUMBER_SEARCH, else DETECTED_STEP
    ns=""
    if [ ${#NUMBER_SEARCH[@]} -gt 0 ]; then
        ns=$(IFS=,; echo "${NUMBER_SEARCH[*]}")
    elif [ -n "$DETECTED_STEP" ]; then
        ns="$DETECTED_STEP"
    fi

    # If we have an effective ns, always include it in the final reproducible args
    if [ -n "$ns" ]; then
        FINAL_ARGS+=("--number-search" "$ns")
    fi

    # Only include an explicit --number-override if the user provided one and it's different
    # from the effective ns (and the effective ns is non-empty). This avoids redundant
    # --number-override when it would be identical to the --number-search used above.
    if [ -n "$NUMBER_OVERRIDE" ]; then
        no_norm=$(normalize_step "$NUMBER_OVERRIDE")
        include_override=true
        if [ -n "$ns" ]; then
            # If ns contains multiple values (comma), treat override as different.
            if echo "$ns" | grep -q ','; then
                include_override=true
            else
                ns_norm=$(normalize_step "$ns")
                if [ "$no_norm" = "$ns_norm" ]; then
                    include_override=false
                fi
            fi
        fi
        if [ "$include_override" = true ]; then
            FINAL_ARGS+=("--number-override" "$no_norm")
        fi
    fi
    if [ -n "$BATCH_MESSAGE" ]; then
        if [ -n "$MESSAGE_B64" ]; then
            FINAL_ARGS+=("--message-base64" "$MESSAGE_B64")
        else
            FINAL_ARGS+=("-m" "$BATCH_MESSAGE")
        fi
    fi
    if [ "$DRY_RUN" = true ]; then
        FINAL_ARGS+=("--dry-run")
    fi

    # Do not build a printf-escaped FINAL_JOINED as it can produce $'...' for non-ASCII.
    # Use SHELL_FINAL_JOINED / MAKE_FINAL_JOINED below which handle base64 encoding when needed.
    linebreak
    print_info "Final command to reproduce this operation:"
    # Build a shell-friendly final invocation similarly and convert non-ASCII messages to base64 flags
    SHELL_FINAL_JOINED=""
    skip_next=false
    j=0
    while [ $j -lt ${#FINAL_ARGS[@]} ]; do
        a="${FINAL_ARGS[$j]}"
        if [ "$skip_next" = true ]; then
            skip_next=false
            j=$((j+1))
            continue
        fi
        if [ "$a" = "-m" ] || [ "$a" = "--message" ]; then
            val="${FINAL_ARGS[$((j+1))]}"
            if [ "$(is_shell_printable "$val")" -eq 1 ]; then
                esc=$(printf "%q" "-m")
                vesc=$(printf "%q" "$val")
                SHELL_FINAL_JOINED="$SHELL_FINAL_JOINED $esc $vesc"
            else
                b64=$(b64_of "$val")
                esc=$(printf "%q" "--message-base64")
                vesc=$(printf "%q" "$b64")
                SHELL_FINAL_JOINED="$SHELL_FINAL_JOINED $esc $vesc"
                omitted_message=true
            fi
            skip_next=true
        else
            esc=$(printf "%q" "$a")
            SHELL_FINAL_JOINED="$SHELL_FINAL_JOINED $esc"
        fi
        j=$((j+1))
    done

    print_code "$FINAL_CMD_PATH$SHELL_FINAL_JOINED"
    # Build Make-friendly final joined similarly (omit -m if non-ASCII)
    MAKE_FINAL_JOINED=""
    omitted_message=false
    skip_next=false
    j=0
    while [ $j -lt ${#FINAL_ARGS[@]} ]; do
        a="${FINAL_ARGS[$j]}"
        if [ "$skip_next" = true ]; then
            skip_next=false
            j=$((j+1))
            continue
        fi
        if [ "$a" = "-m" ] || [ "$a" = "--message" ]; then
            val="${FINAL_ARGS[$((j+1))]}"
            if [ "$(is_shell_printable "$val")" -eq 1 ]; then
                esc=$(printf "%q" "-m")
                vesc=$(printf "%q" "$val")
                MAKE_FINAL_JOINED="$MAKE_FINAL_JOINED $esc $vesc"
                skip_next=true
            else
                b64=$(b64_of "$val")
                esc=$(printf "%q" "--message-base64")
                vesc=$(printf "%q" "$b64")
                MAKE_FINAL_JOINED="$MAKE_FINAL_JOINED $esc $vesc"
                omitted_message=true
                skip_next=true
            fi
        else
            esc=$(printf "%q" "$a")
            MAKE_FINAL_JOINED="$MAKE_FINAL_JOINED $esc"
        fi
        j=$((j+1))
    done

    print_info "Or via make (positional shortcuts supported):"
    if [ -n "$MAKE_FINAL_JOINED" ]; then
        print_code "make fix-commits --$MAKE_FINAL_JOINED"
    else
        print_code "make fix-commits"
    fi
    if [ "$omitted_message" = true ]; then
        print_warning "Note: message contained non-ASCII characters and was omitted from the make invocation; use the 'Safe (Unicode) reproducible command' shown above to run exactly."
    fi
    linebreak
else
    # Restore the original core.editor on failure as well
    if [ -n "$ORIGINAL_CORE_EDITOR" ]; then
        git config core.editor "$ORIGINAL_CORE_EDITOR"
    else
        git config --unset core.editor
    fi
    print_error "Rebase failed or was aborted"
    print_info "You can continue with: git rebase --continue"
    print_info "Or abort with: git rebase --abort"
    print_info "To recover to the state before rebase: git reset --hard $RECOVERY_TAG"
    exit 1
fi
