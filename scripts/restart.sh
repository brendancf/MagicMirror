#!/bin/bash
# Restart MagicMirror on the server

SERVER="brendancf@192.168.1.200"

echo "Restarting MagicMirror..."
ssh "$SERVER" "pm2 restart mm"

echo ""
echo "Status:"
ssh "$SERVER" "pm2 status"
