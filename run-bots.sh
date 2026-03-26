#!/bin/bash
# Run 3 bot workers with different difficulty levels
# Usage: ./run-bots.sh        (start all)
#        ./run-bots.sh stop   (stop all)

cd "$(dirname "$0")"
PIDS_FILE=".bot-pids"

if [ "$1" = "stop" ]; then
    if [ -f "$PIDS_FILE" ]; then
        echo "Stopping bots..."
        while read pid; do
            kill "$pid" 2>/dev/null && echo "  Stopped PID $pid"
        done < "$PIDS_FILE"
        rm "$PIDS_FILE"
        echo "All bots stopped."
    else
        echo "No running bots found."
    fi
    exit 0
fi

echo "Starting 3 bot workers..."
echo ""

python3 -m worker worker/config-easy.yaml &
echo "  Easy   (PID $!) - Bot-Easy   [random]"
echo $! > "$PIDS_FILE"

sleep 1

python3 -m worker worker/config-medium.yaml &
echo "  Medium (PID $!) - Bot-Medium [elimination]"
echo $! >> "$PIDS_FILE"

sleep 1

python3 -m worker worker/config-hard.yaml &
echo "  Hard   (PID $!) - Bot-Hard   [entropy]"
echo $! >> "$PIDS_FILE"

echo ""
echo "All bots running. Group: B07"
echo "Stop with: ./run-bots.sh stop"
echo ""
wait
