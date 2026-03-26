from __future__ import annotations

import random

from ..baseball import ALL_CANDIDATES, filter_candidates
from .base import GuessResult, Strategy


class EliminationStrategy(Strategy):
    """Medium difficulty: eliminates impossible candidates based on previous results."""

    def __init__(self) -> None:
        self._candidates: list[str] = []

    @property
    def name(self) -> str:
        return "Elimination (Medium)"

    def reset(self) -> None:
        self._candidates = list(ALL_CANDIDATES)

    def next_guess(self, history: list[GuessResult]) -> str:
        # Rebuild candidates from scratch using full history
        candidates = list(ALL_CANDIDATES)
        for gr in history:
            candidates = filter_candidates(candidates, gr.guess, gr.strike, gr.ball)

        self._candidates = candidates

        if not candidates:
            # Fallback (should never happen with correct logic)
            return random.choice(ALL_CANDIDATES)

        return random.choice(candidates)
