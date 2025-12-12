#!/bin/bash
# Fetch logs from the MagicMirror deployment server

SERVER="brendancf@192.168.1.200"
LOGS_DIR="$(dirname "$0")/../logs"

mkdir -p "$LOGS_DIR"

echo "Fetching pm2 logs..."
ssh "$SERVER" "pm2 logs mm --lines 500 --nostream" > "$LOGS_DIR/mm-latest.log" 2>&1

echo "Fetching error log..."
ssh "$SERVER" "cat ~/.pm2/logs/mm-error.log 2>/dev/null | tail -200" > "$LOGS_DIR/mm-error.log" 2>&1

echo "Fetching pm2 status..."
ssh "$SERVER" "pm2 status" > "$LOGS_DIR/pm2-status.txt" 2>&1

echo "Logs saved to $LOGS_DIR/"
ls -la "$LOGS_DIR/"
