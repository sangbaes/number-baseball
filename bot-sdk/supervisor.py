"""Bot Worker Supervisor - monitors and restarts workers when they die.

Usage:
    python supervisor.py                     # Run all config-*.yaml workers
    python supervisor.py config-A.yaml config-B.yaml  # Run specific configs
    python supervisor.py --check-interval 10 # Custom health check interval
"""

from __future__ import annotations

import argparse
import glob
import logging
import signal
import subprocess
import sys
import time
from dataclasses import dataclass, field

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] supervisor: %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("supervisor")


@dataclass
class Worker:
    config: str
    name: str
    process: subprocess.Popen | None = None
    restart_count: int = 0
    last_start: float = 0.0


def extract_bot_name(config_path: str) -> str:
    """Extract bot name from config YAML without importing yaml."""
    try:
        with open(config_path) as f:
            for line in f:
                stripped = line.strip()
                if stripped.startswith("name:"):
                    name = stripped.split(":", 1)[1].strip().strip('"').strip("'")
                    return name
    except Exception:
        pass
    return config_path


def start_worker(worker: Worker) -> None:
    """Start or restart a worker process."""
    log_file = f"/tmp/bot-{worker.name}.log"
    fh = open(log_file, "a")
    worker.process = subprocess.Popen(
        [sys.executable, "run.py", worker.config],
        stdout=fh,
        stderr=subprocess.STDOUT,
    )
    worker.last_start = time.time()
    tag = "Started" if worker.restart_count == 0 else f"Restarted (#{worker.restart_count})"
    logger.info("%s [%s] PID=%d, config=%s", tag, worker.name, worker.process.pid, worker.config)


def main() -> None:
    parser = argparse.ArgumentParser(description="Bot Worker Supervisor")
    parser.add_argument("configs", nargs="*", help="Config YAML files (default: all config-*.yaml)")
    parser.add_argument("--check-interval", type=int, default=5, help="Health check interval in seconds")
    parser.add_argument("--restart-delay", type=int, default=3, help="Delay before restarting a dead worker")
    args = parser.parse_args()

    configs = args.configs
    if not configs:
        configs = sorted(glob.glob("config-*.yaml"))

    if not configs:
        logger.error("No config files found. Pass config files as arguments or create config-*.yaml files.")
        sys.exit(1)

    workers: list[Worker] = [
        Worker(config=c, name=extract_bot_name(c)) for c in configs
    ]

    shutting_down = False

    def handle_signal(signum, frame):
        nonlocal shutting_down
        if shutting_down:
            return
        shutting_down = True
        logger.info("Shutting down all workers...")
        for w in workers:
            if w.process and w.process.poll() is None:
                w.process.terminate()
        # Give workers time to clean up
        deadline = time.time() + 5
        for w in workers:
            if w.process and w.process.poll() is None:
                remaining = max(0, deadline - time.time())
                try:
                    w.process.wait(timeout=remaining)
                except subprocess.TimeoutExpired:
                    w.process.kill()
        logger.info("All workers stopped.")
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    logger.info("Supervisor starting with %d worker(s)", len(workers))
    for w in workers:
        logger.info("  - %s (%s)", w.name, w.config)
    print()

    # Start all workers (staggered to avoid cleanup conflicts)
    for i, w in enumerate(workers):
        if i > 0:
            time.sleep(args.restart_delay)
        start_worker(w)

    # Monitor loop
    while not shutting_down:
        time.sleep(args.check_interval)
        for w in workers:
            if w.process and w.process.poll() is not None:
                exit_code = w.process.returncode
                logger.warning("[%s] died (exit=%d). Restarting in %ds...", w.name, exit_code, args.restart_delay)
                time.sleep(args.restart_delay)
                w.restart_count += 1
                start_worker(w)


if __name__ == "__main__":
    main()
