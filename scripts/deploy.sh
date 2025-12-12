#!/bin/bash
# Deploy MagicMirror to the Raspberry Pi server via git

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load configuration from .env
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo "ERROR: $SCRIPT_DIR/.env not found"
    echo "Create it with SERVER and REMOTE_DIR variables"
    exit 1
fi

set -e

echo "=== MagicMirror Deployment ==="
echo "Server: $SERVER"
echo "Remote: $REMOTE_DIR"
echo ""

# Safety check: ensure no uncommitted changes in main repo
echo "Checking main repo..."
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: You have uncommitted changes in main repo. Commit or stash them first."
    git status --short
    exit 1
fi

# Safety check: ensure main repo is pushed to remote
LOCAL_COMMIT=$(git rev-parse HEAD)
REMOTE_COMMIT=$(git rev-parse @{u} 2>/dev/null || echo "")

if [ -z "$REMOTE_COMMIT" ]; then
    echo "ERROR: No upstream branch configured. Run: git push -u origin master"
    exit 1
fi

if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
    echo "ERROR: Local commits not pushed to remote in main repo."
    echo "Local:  $LOCAL_COMMIT"
    echo "Remote: $REMOTE_COMMIT"
    echo "Run: git push"
    exit 1
fi

# Safety check: ensure no uncommitted changes in module repos
echo "Checking module repos..."
MODULES_WITH_CHANGES=""
for dir in "$PROJECT_DIR"/modules/MMM-*/; do
    if [ -d "$dir/.git" ]; then
        module_name=$(basename "$dir")
        if ! (cd "$dir" && git diff --quiet && git diff --cached --quiet) 2>/dev/null; then
            MODULES_WITH_CHANGES="$MODULES_WITH_CHANGES  $module_name\n"
        fi
    fi
done

if [ -n "$MODULES_WITH_CHANGES" ]; then
    echo "ERROR: The following modules have uncommitted changes:"
    echo -e "$MODULES_WITH_CHANGES"
    echo "Commit or stash changes in each module before deploying."
    exit 1
fi

# Check if any module repos have unpushed commits (ahead of remote)
MODULES_NOT_PUSHED=""
for dir in "$PROJECT_DIR"/modules/MMM-*/; do
    if [ -d "$dir/.git" ]; then
        module_name=$(basename "$dir")
        # Check if there's an upstream and if we're ahead (not just different)
        ahead_count=$(cd "$dir" && git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
        if [ "$ahead_count" -gt 0 ]; then
            MODULES_NOT_PUSHED="$MODULES_NOT_PUSHED  $module_name ($ahead_count commits ahead)\n"
        fi
    fi
done

if [ -n "$MODULES_NOT_PUSHED" ]; then
    echo "ERROR: The following modules have unpushed commits:"
    echo -e "$MODULES_NOT_PUSHED"
    echo "Push changes in each module before deploying."
    exit 1
fi

echo "Pre-deploy checks passed."

# Pull main MagicMirror repo
echo ""
echo "=== Updating main MagicMirror repo ==="
ssh "$SERVER" "cd $REMOTE_DIR && git pull"

# Update all module repos
echo ""
echo "=== Updating module repos ==="
ssh "$SERVER" "cd $REMOTE_DIR/modules && for dir in MMM-*/; do
    if [ -d \"\$dir/.git\" ]; then
        echo \"Updating \$dir...\"
        (cd \"\$dir\" && git pull) || echo \"  WARNING: Failed to update \$dir\"
    fi
done"

# Install dependencies for main and modules
echo ""
echo "=== Installing dependencies ==="
ssh "$SERVER" "cd $REMOTE_DIR && npm install"
ssh "$SERVER" "cd $REMOTE_DIR/modules && for dir in MMM-*/; do
    if [ -f \"\$dir/package.json\" ]; then
        echo \"Installing deps for \$dir...\"
        (cd \"\$dir\" && npm install) || echo \"  WARNING: npm install failed for \$dir\"
    fi
done"

# Restart MagicMirror
echo ""
echo "=== Restarting MagicMirror ==="
ssh "$SERVER" "cd $REMOTE_DIR && pm2 restart mm"

echo ""
echo "Checking status..."
ssh "$SERVER" "pm2 status"

echo ""
echo "=== Deployment complete ==="
