#!/bin/bash
# Run all league bot workers
# Level 1: 3 workers, Level 2: 2, Level 3: 2, Level 4: 1, Level 5: 1
# Total: 9 workers

set -e
cd "$(dirname "$0")"

case "${1:-start}" in
  stop)
    echo "Stopping all bot workers..."
    pkill -9 -f "Python -m worker" 2>/dev/null || true
    pkill -9 -f "python3 -m worker" 2>/dev/null || true
    echo "Done."
    exit 0
    ;;
  status)
    echo "Running bot workers:"
    ps aux | grep "[P]ython.*-m worker" || echo "  (none)"
    exit 0
    ;;
esac

# Kill any existing bots
pkill -9 -f "Python -m worker" 2>/dev/null || true
pkill -9 -f "python3 -m worker" 2>/dev/null || true
sleep 1

LOG_DIR="/tmp"
echo "Starting league bot workers... (logs in $LOG_DIR/worker-*.log)"
echo ""

PIDS=""

# Level 1 - Beginner (3 workers)
for i in 1 2 3; do
  python3 -m worker worker/config-level1.yaml --instance $i > "$LOG_DIR/worker-l1-$i.log" 2>&1 &
  PIDS="$PIDS $!"
  echo "  Level 1 Beginner  #$i (PID $!) → $LOG_DIR/worker-l1-$i.log"
  sleep 0.5
done

# Level 2 - Intermediate (2 workers)
for i in 1 2; do
  python3 -m worker worker/config-level2.yaml --instance $i > "$LOG_DIR/worker-l2-$i.log" 2>&1 &
  PIDS="$PIDS $!"
  echo "  Level 2 Intermediate #$i (PID $!) → $LOG_DIR/worker-l2-$i.log"
  sleep 0.5
done

# Level 3 - Advanced (2 workers)
for i in 1 2; do
  python3 -m worker worker/config-level3.yaml --instance $i > "$LOG_DIR/worker-l3-$i.log" 2>&1 &
  PIDS="$PIDS $!"
  echo "  Level 3 Advanced  #$i (PID $!) → $LOG_DIR/worker-l3-$i.log"
  sleep 0.5
done

# Level 4 - Expert (1 worker)
python3 -m worker worker/config-level4.yaml --instance 1 > "$LOG_DIR/worker-l4-1.log" 2>&1 &
PIDS="$PIDS $!"
echo "  Level 4 Expert    #1 (PID $!) → $LOG_DIR/worker-l4-1.log"
sleep 0.5

# Level 5 - Master (1 worker)
python3 -m worker worker/config-level5.yaml --instance 1 > "$LOG_DIR/worker-l5-1.log" 2>&1 &
PIDS="$PIDS $!"
echo "  Level 5 Master    #1 (PID $!) → $LOG_DIR/worker-l5-1.log"

echo ""
echo "All 9 workers started."
echo "Stop:   ./run-league-bots.sh stop"
echo "Status: ./run-league-bots.sh status"
echo ""

# Save PIDs
echo $PIDS | tr ' ' '\n' > .bot-pids

# Wait for all children
wait
