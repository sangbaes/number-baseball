from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path

import yaml


@dataclass
class FirebaseConfig:
    service_account: str = "./service-account.json"
    database_url: str = "https://number-baseball-28392-default-rtdb.firebaseio.com"


@dataclass
class BotConfig:
    name: str = "Bot-Medium"
    group_code: str = "B07"
    strategy: str = "elimination"
    restart_delay_seconds: int = 3
    guess_delay_seconds: float = 2.0
    heartbeat_interval: int = 15
    level: int = 1
    worker_id: str = ""
    error_rate: float = 0.0


@dataclass
class Config:
    firebase: FirebaseConfig = field(default_factory=FirebaseConfig)
    bot: BotConfig = field(default_factory=BotConfig)

    @classmethod
    def load(cls, path: str | None = None) -> Config:
        if path is None:
            # Look for config.yaml relative to this file (worker/ directory)
            path = str(Path(__file__).parent / "config.yaml")

        if not os.path.exists(path):
            return cls()

        with open(path) as f:
            raw = yaml.safe_load(f) or {}

        fb = raw.get("firebase", {})
        bot = raw.get("bot", {})

        return cls(
            firebase=FirebaseConfig(
                service_account=fb.get("service_account", FirebaseConfig.service_account),
                database_url=fb.get("database_url", FirebaseConfig.database_url),
            ),
            bot=BotConfig(
                name=bot.get("name", BotConfig.name),
                group_code=bot.get("group_code", BotConfig.group_code),
                strategy=bot.get("strategy", BotConfig.strategy),
                restart_delay_seconds=bot.get("restart_delay_seconds", BotConfig.restart_delay_seconds),
                guess_delay_seconds=bot.get("guess_delay_seconds", BotConfig.guess_delay_seconds),
                heartbeat_interval=bot.get("heartbeat_interval", BotConfig.heartbeat_interval),
                level=bot.get("level", BotConfig.level),
                worker_id=bot.get("worker_id", BotConfig.worker_id),
                error_rate=bot.get("error_rate", BotConfig.error_rate),
            ),
        )
