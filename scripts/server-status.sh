#!/bin/bash
# Check MagicMirror server status

SERVER="brendancf@magic-mirror"

echo "=== PM2 Status ==="
ssh "$SERVER" "pm2 status"

echo ""
echo "=== Recent Logs (last 30 lines) ==="
ssh "$SERVER" "pm2 logs mm --lines 30 --nostream"

echo ""
echo "=== System Resources ==="
ssh "$SERVER" "free -h && echo '' && df -h / && echo '' && uptime"
