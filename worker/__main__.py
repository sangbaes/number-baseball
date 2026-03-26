"""Entry point: python -m worker [config.yaml] [--instance N] [--mode worker|lobby]"""

from __future__ import annotations

import argparse
import logging
import signal
import socket
import sys

from .config import Config
from .firebase_client import init_firebase
from .strategy import get_strategy


def main() -> None:
    parser = argparse.ArgumentParser(description="Number Baseball bot worker")
    parser.add_argument("config", nargs="?", help="Path to YAML config file")
    parser.add_argument("--instance", type=int, default=1,
                        help="Worker instance number (for multi-worker)")
    parser.add_argument("--mode", choices=["worker", "lobby"], default="worker",
                        help="Engine mode: 'worker' (passive) or 'lobby' (active, creates room)")
    args = parser.parse_args()

    config = Config.load(args.config)

    # Auto-generate worker_id if not set
    if not config.bot.worker_id:
        hostname = socket.gethostname().split(".")[0]
        suffix = f"lobby-{args.instance}" if args.mode == "lobby" else str(args.instance)
        config.bot.worker_id = f"{config.bot.group_code}-{hostname}-{suffix}"

    # Setup logging
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )

    logger = logging.getLogger("worker")
    logger.info("Mode: %s | strategy=%s, name=%s, level=%d",
                args.mode, config.bot.strategy, config.bot.name, config.bot.level)

    # Initialize Firebase
    root = init_firebase(config.firebase.service_account, config.firebase.database_url)
    logger.info("Firebase connected: %s", config.firebase.database_url)

    strategy = get_strategy(config.bot.strategy, config.bot.error_rate)
    logger.info("Strategy: %s", strategy.name)

    if args.mode == "lobby":
        from .lobby_engine import LobbyEngine
        from .room_manager import LobbyCleanup

        cleanup = LobbyCleanup(root, config.bot)
        cleanup.cleanup_stale_lobby_rooms()

        engine = LobbyEngine(config.bot, strategy, root)

        def handle_signal(sig, frame):
            logger.info("Signal %s received, shutting down...", signal.Signals(sig).name)
            engine.shutdown()
            sys.exit(0)

        signal.signal(signal.SIGINT, handle_signal)
        signal.signal(signal.SIGTERM, handle_signal)

        logger.info("Lobby bot started (room will be created). Press Ctrl+C to stop.")
        engine.run()

    else:
        from .game_engine import GameEngine
        from .room_manager import WorkerPool

        pool = WorkerPool(root, config.bot)
        pool.cleanup_stale_assignment()
        pool.cleanup_stale_rooms()

        engine = GameEngine(config.bot, strategy, root)

        def handle_signal(sig, frame):
            logger.info("Signal %s received, shutting down...", signal.Signals(sig).name)
            engine.shutdown()
            sys.exit(0)

        signal.signal(signal.SIGINT, handle_signal)
        signal.signal(signal.SIGTERM, handle_signal)

        logger.info("Bot worker started. Press Ctrl+C to stop.")
        engine.run()


if __name__ == "__main__":
    main()
