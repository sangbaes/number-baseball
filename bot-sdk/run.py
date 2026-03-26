"""Number Baseball Bot - Run your custom strategy!

Usage:
    python run.py [config.yaml]
"""

from __future__ import annotations

import importlib
import logging
import signal
import sys

from sdk.config import Config
from sdk.firebase_client import init_firebase
from sdk.cleanup import LobbyCleanup
from sdk.engine import LobbyEngine
from sdk.strategy import Strategy


def load_strategy(module_name: str) -> Strategy:
    """Dynamically load a Strategy subclass from a Python file.

    Example: load_strategy("my_strategy") imports my_strategy.py
    and returns an instance of the first Strategy subclass found.
    """
    try:
        mod = importlib.import_module(module_name)
    except ModuleNotFoundError:
        print(f"Error: Could not find '{module_name}.py'")
        print(f"Make sure the file exists in the current directory.")
        sys.exit(1)

    for attr_name in dir(mod):
        attr = getattr(mod, attr_name)
        if (isinstance(attr, type)
                and issubclass(attr, Strategy)
                and attr is not Strategy):
            return attr()

    print(f"Error: No Strategy subclass found in '{module_name}.py'")
    print(f"Your file must contain a class that extends Strategy.")
    sys.exit(1)


def main() -> None:
    config_path = sys.argv[1] if len(sys.argv) > 1 else "config.yaml"

    # Set up logging
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S",
    )

    # Load config
    config = Config.load(config_path)

    if not config.firebase.database_url:
        print("Error: firebase.database_url is not set in config.yaml")
        sys.exit(1)

    # Load strategy
    strategy = load_strategy(config.bot.strategy)
    print(f"Strategy: {strategy.name}")
    print(f"Bot name: {config.bot.name}")
    print(f"Group: {config.bot.group_code}")
    print()

    # Initialize Firebase
    root = init_firebase(
        config.firebase.service_account,
        config.firebase.database_url,
    )
    print("Firebase connected!")

    # Clean up stale rooms from previous runs
    LobbyCleanup(root, config.bot.group_code).run()

    # Create and run the engine
    engine = LobbyEngine(config.bot, strategy, root)

    def handle_signal(signum, frame):
        print("\nShutting down...")
        engine.shutdown()

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    print("Bot is running! Press Ctrl+C to stop.")
    print()
    engine.run()


if __name__ == "__main__":
    main()
