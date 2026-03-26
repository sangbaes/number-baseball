#!/bin/bash
# Start bot workers as daemon processes that survive shell exit
# Usage: bash start-bots-daemon.sh

cd "$(dirname "$0")"

# Kill any existing bots
pkill -f "python3 -m worker worker/config" 2>/dev/null
sleep 1

echo "Starting bot daemons..."

# Use trap to ignore SIGHUP so children survive parent exit
trap '' HUP

nohup /usr/local/bin/python3 -m worker worker/config-easy.yaml > /tmp/bot-easy.log 2>&1 &
EASY_PID=$!
echo "  Easy   PID=$EASY_PID"

sleep 1

nohup /usr/local/bin/python3 -m worker worker/config-medium.yaml > /tmp/bot-medium.log 2>&1 &
MED_PID=$!
echo "  Medium PID=$MED_PID"

sleep 1

nohup /usr/local/bin/python3 -m worker worker/config-hard.yaml > /tmp/bot-hard.log 2>&1 &
HARD_PID=$!
echo "  Hard   PID=$HARD_PID"

# Save PIDs
echo "$EASY_PID" > .bot-pids
echo "$MED_PID" >> .bot-pids
echo "$HARD_PID" >> .bot-pids

echo ""
echo "All bots started. PIDs saved to .bot-pids"
echo "Logs: /tmp/bot-easy.log, /tmp/bot-medium.log, /tmp/bot-hard.log"
echo "Stop: pkill -f 'python3 -m worker worker/config'"
