"""Game recorder for saving match data as JSONL for LLM training."""

from __future__ import annotations

import json
import logging
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path

logger = logging.getLogger(__name__)


@dataclass
class GameRecord:
    """Complete record of a single game for LLM training data."""

    timestamp: str = ""
    room_code: str = ""
    bot_name: str = ""
    bot_strategy: str = ""
    opponent_name: str = ""
    opponent_uid: str = ""
    level: int = 0
    secret: str = ""
    rounds: list[dict] = field(default_factory=list)
    winner: str = ""
    reason: str = ""
    total_rounds: int = 0


class GameRecorder:
    """Appends game records to daily JSONL files."""

    def __init__(self, record_dir: str) -> None:
        self._record_dir = Path(record_dir)

    def record(self, game: GameRecord) -> None:
        """Append one game as a JSON line to the daily JSONL file."""
        self._record_dir.mkdir(parents=True, exist_ok=True)
        date_str = datetime.now().strftime("%Y-%m-%d")
        filepath = self._record_dir / f"games-{date_str}.jsonl"
        line = json.dumps(asdict(game), ensure_ascii=False)
        with open(filepath, "a", encoding="utf-8") as f:
            f.write(line + "\n")
        logger.info("Recorded game to %s", filepath)

    @staticmethod
    def extract_rounds(room_data: dict) -> list[dict]:
        """Extract per-round data from Firebase room_data['rounds']."""
        raw_rounds = room_data.get("rounds", {})

        # Handle Firebase NSArray conversion (sequential keys -> list)
        if isinstance(raw_rounds, list):
            converted = {}
            for i, v in enumerate(raw_rounds):
                if v is not None:
                    converted[str(i)] = v
            raw_rounds = converted

        if not isinstance(raw_rounds, dict):
            return []

        result = []
        for round_key in sorted(raw_rounds.keys(), key=lambda k: int(k)):
            rd = raw_rounds[round_key]
            if not isinstance(rd, dict):
                continue

            guess_from = rd.get("guessFrom", {}) or {}
            result_for = rd.get("resultFor", {}) or {}

            p1_guess = guess_from.get("p1", {}) or {}
            p1_result = result_for.get("p1", {}) or {}
            p2_guess = guess_from.get("p2", {}) or {}
            p2_result = result_for.get("p2", {}) or {}

            result.append({
                "round": int(round_key),
                "bot_guess": p1_guess.get("value"),
                "bot_strike": p1_result.get("strike"),
                "bot_ball": p1_result.get("ball"),
                "opponent_guess": p2_guess.get("value"),
                "opponent_strike": p2_result.get("strike"),
                "opponent_ball": p2_result.get("ball"),
            })

        return result
