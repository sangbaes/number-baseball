from __future__ import annotations

import random

from ..baseball import ALL_CANDIDATES
from .base import GuessResult, Strategy


class RandomStrategy(Strategy):
    """Easy difficulty: picks a random valid guess each time (no filtering)."""

    @property
    def name(self) -> str:
        return "Random (Easy)"

    def reset(self) -> None:
        pass  # no state to reset

    def next_guess(self, history: list[GuessResult]) -> str:
        return random.choice(ALL_CANDIDATES)
