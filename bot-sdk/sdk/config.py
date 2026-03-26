"""Configuration loader for bot settings."""

from __future__ import annotations

import os
from dataclasses import dataclass, field

import yaml


@dataclass
class FirebaseConfig:
    service_account: str = "./service-account.json"
    database_url: str = ""


@dataclass
class BotConfig:
    name: str = "MyBot"
    group_code: str = "BOT"
    strategy: str = "my_strategy"
    restart_delay_seconds: int = 5
    guess_delay_seconds: float = 2.0
    heartbeat_interval: int = 15
    level: int = 1
    record_dir: str = ""


@dataclass
class Config:
    firebase: FirebaseConfig = field(default_factory=FirebaseConfig)
    bot: BotConfig = field(default_factory=BotConfig)

    @classmethod
    def load(cls, path: str = "config.yaml") -> "Config":
        if not os.path.exists(path):
            raise FileNotFoundError(
                f"Config file not found: {path}\n"
                "Create a config.yaml file. See README.md for details."
            )

        with open(path) as f:
            raw = yaml.safe_load(f) or {}

        fb = raw.get("firebase", {})
        bot = raw.get("bot", {})

        return cls(
            firebase=FirebaseConfig(
                service_account=fb.get("service_account", FirebaseConfig.service_account),
                database_url=fb.get("database_url", ""),
            ),
            bot=BotConfig(
                name=bot.get("name", BotConfig.name),
                group_code=bot.get("group_code", BotConfig.group_code),
                strategy=bot.get("strategy", BotConfig.strategy),
                restart_delay_seconds=bot.get("restart_delay_seconds", BotConfig.restart_delay_seconds),
                guess_delay_seconds=bot.get("guess_delay_seconds", BotConfig.guess_delay_seconds),
                heartbeat_interval=bot.get("heartbeat_interval", BotConfig.heartbeat_interval),
                level=bot.get("level", BotConfig.level),
                record_dir=bot.get("record_dir", BotConfig.record_dir),
            ),
        )
