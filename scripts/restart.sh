#!/bin/bash
# Restart MagicMirror on the server

SERVER="brendancf@magic-mirror"

echo "Restarting MagicMirror..."
ssh "$SERVER" "pm2 restart mm"

echo ""
echo "Status:"
ssh "$SERVER" "pm2 status"
