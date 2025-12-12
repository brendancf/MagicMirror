#!/bin/bash
# Deploy MagicMirror to the Raspberry Pi server

SERVER="brendancf@192.168.1.200"
REMOTE_DIR="Documents/code/MagicMirror"

set -e

echo "=== MagicMirror Deployment ==="

# Sync files (excluding node_modules, logs, etc.)
echo "Syncing files to server..."
rsync -avz --delete \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude 'logs' \
    --exclude '*.log' \
    --exclude 'config/config.js' \
    "$(dirname "$0")/../" \
    "$SERVER:$REMOTE_DIR/"

echo "Restarting MagicMirror..."
ssh "$SERVER" "cd $REMOTE_DIR && pm2 restart mm"

echo "Checking status..."
ssh "$SERVER" "pm2 status"

echo "=== Deployment complete ==="
