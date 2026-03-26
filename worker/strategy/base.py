from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class GuessResult:
    """A single guess and its strike/ball result."""
    guess: str
    strike: int
    ball: int


class Strategy(ABC):
    """Abstract base class for number-baseball guessing strategies."""

    @abstractmethod
    def reset(self) -> None:
        """Reset internal state for a new game."""

    @abstractmethod
    def next_guess(self, history: list[GuessResult]) -> str:
        """Given history of previous guesses and results, return next 3-digit guess."""

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable strategy name for display."""
