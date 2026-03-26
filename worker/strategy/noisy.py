"""Noisy strategy wrapper: injects random errors at a configurable rate."""

from __future__ import annotations

import random

from .base import GuessResult, Strategy
from ..baseball import ALL_CANDIDATES


class NoisyStrategy(Strategy):
    """Wraps another strategy, randomly injecting bad guesses."""

    def __init__(self, inner: Strategy, error_rate: float) -> None:
        self._inner = inner
        self._error_rate = max(0.0, min(1.0, error_rate))

    @property
    def name(self) -> str:
        return f"{self._inner.name} (noise={self._error_rate:.0%})"

    def reset(self) -> None:
        self._inner.reset()

    def next_guess(self, history: list[GuessResult]) -> str:
        if random.random() < self._error_rate:
            return random.choice(ALL_CANDIDATES)
        return self._inner.next_guess(history)
