#!/bin/bash
# Update forked repos from their upstream sources
#
# Usage:
#   ./update-from-upstream.sh           # Show status only
#   ./update-from-upstream.sh --merge   # Merge upstream changes

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Upstream mappings (repo_path:upstream_url)
# Only includes repos that are forks (origin = brendancf)
UPSTREAMS=(
    ".:https://github.com/MagicMirrorOrg/MagicMirror.git"
    "modules/MMM-GoogleCalendar:https://github.com/randomBrainstormer/MMM-GoogleCalendar.git"
    "modules/MMM-GooglePhotos:https://github.com/hermanho/MMM-GooglePhotos.git"
    "modules/MMM-GoogleTrafficTimes:https://github.com/Jacopo1891/MMM-GoogleTrafficTimes.git"
    "modules/MMM-Sonos:https://github.com/Snille/MMM-Sonos.git"
    "modules/MMM-Wallpaper:https://github.com/kolbyjack/MMM-Wallpaper.git"
    "modules/MMM-WeatherGraph:https://github.com/FlatPepsi17/MMM-WeatherGraph.git"
    "modules/MMM-WyzeBridge:https://github.com/angeldeejay/MMM-WyzeBridge.git"
)

DO_MERGE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --merge)
            DO_MERGE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--merge]"
            echo ""
            echo "Check forked repos for upstream updates."
            echo ""
            echo "Options:"
            echo "  --merge    Merge upstream changes into local branch"
            echo "  -h, --help Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=== Checking Upstream Updates ==="
echo ""

REPOS_BEHIND=0
REPOS_UPDATED=0
REPOS_FAILED=0

for mapping in "${UPSTREAMS[@]}"; do
    # Split mapping into path and URL
    repo_path="${mapping%%:*}"
    upstream_url="${mapping#*:}"

    # Get display name
    if [ "$repo_path" = "." ]; then
        display_name="MagicMirror (root)"
        full_path="$PROJECT_DIR"
    else
        display_name=$(basename "$repo_path")
        full_path="$PROJECT_DIR/$repo_path"
    fi

    # Extract upstream owner/repo for display
    upstream_name=$(echo "$upstream_url" | sed 's|https://github.com/||' | sed 's|\.git$||')

    echo -e "${BLUE}$display_name${NC}"
    echo "  upstream: $upstream_name"

    # Check if directory exists
    if [ ! -d "$full_path" ]; then
        echo -e "  status: ${YELLOW}directory not found${NC}"
        echo ""
        continue
    fi

    # Check if it's a git repo
    if [ ! -d "$full_path/.git" ]; then
        echo -e "  status: ${YELLOW}not a git repository${NC}"
        echo ""
        continue
    fi

    cd "$full_path"

    # Add upstream remote if not present
    if ! git remote get-url upstream &>/dev/null; then
        echo "  adding upstream remote..."
        git remote add upstream "$upstream_url"
    fi

    # Fetch upstream
    echo "  fetching upstream..."
    if ! git fetch upstream --quiet 2>/dev/null; then
        echo -e "  status: ${RED}failed to fetch upstream${NC}"
        ((REPOS_FAILED++))
        echo ""
        continue
    fi

    # Detect upstream default branch (master or main)
    upstream_branch=""
    if git rev-parse --verify upstream/master &>/dev/null; then
        upstream_branch="master"
    elif git rev-parse --verify upstream/main &>/dev/null; then
        upstream_branch="main"
    else
        echo -e "  status: ${YELLOW}could not detect upstream branch${NC}"
        echo ""
        continue
    fi

    # Count commits behind
    behind_count=$(git rev-list --count HEAD..upstream/$upstream_branch 2>/dev/null || echo "0")
    ahead_count=$(git rev-list --count upstream/$upstream_branch..HEAD 2>/dev/null || echo "0")

    if [ "$behind_count" -eq 0 ]; then
        echo -e "  status: ${GREEN}up to date${NC}"
    else
        echo -e "  status: ${YELLOW}$behind_count commits behind${NC} upstream/$upstream_branch"
        if [ "$ahead_count" -gt 0 ]; then
            echo -e "          ${BLUE}$ahead_count commits ahead${NC} (local changes)"
        fi

        if [ "$DO_MERGE" = true ]; then
            echo "  merging upstream/$upstream_branch..."
            if git merge upstream/$upstream_branch -m "Merge upstream/$upstream_branch into $(git branch --show-current)"; then
                echo -e "  ${GREEN}merged successfully${NC}"
                ((REPOS_UPDATED++))
            else
                echo -e "  ${RED}merge failed - resolve conflicts manually${NC}"
                ((REPOS_FAILED++))
            fi
        else
            ((REPOS_BEHIND++))
        fi
    fi

    echo ""
done

# Summary
echo "=== Summary ==="
if [ "$DO_MERGE" = true ]; then
    echo "$REPOS_UPDATED repos updated"
    if [ "$REPOS_FAILED" -gt 0 ]; then
        echo -e "${RED}$REPOS_FAILED repos failed${NC}"
    fi
else
    if [ "$REPOS_BEHIND" -gt 0 ]; then
        echo -e "${YELLOW}$REPOS_BEHIND repos have upstream updates available${NC}"
        echo "Run with --merge to apply updates"
    else
        echo -e "${GREEN}All repos are up to date${NC}"
    fi
    if [ "$REPOS_FAILED" -gt 0 ]; then
        echo -e "${RED}$REPOS_FAILED repos failed to fetch${NC}"
    fi
fi
