"""Strategy interface for Number Baseball bots.

Implement the Strategy abstract class to create your own bot.
Your strategy only needs to decide what number to guess next,
based on the history of previous guesses and their results.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class GuessResult:
    """A single guess and its strike/ball result.

    Attributes:
        guess: The 3-digit number that was guessed (e.g. "152")
        strike: Number of digits in the correct position
        ball: Number of correct digits in the wrong position
    """
    guess: str
    strike: int
    ball: int


class Strategy(ABC):
    """Abstract base class for number-baseball guessing strategies.

    To create a bot, subclass this and implement:
      - reset(): called at the start of each new game
      - next_guess(history): return your next 3-digit guess
      - name: a display name for your bot's strategy
    """

    @abstractmethod
    def reset(self) -> None:
        """Reset internal state for a new game."""

    @abstractmethod
    def next_guess(self, history: list[GuessResult]) -> str:
        """Given history of previous guesses and results, return next 3-digit guess.

        Args:
            history: List of previous GuessResult objects for this game.
                     Empty list on the first guess.

        Returns:
            A string of 3 unique digits (e.g. "407").
        """

    @property
    @abstractmethod
    def name(self) -> str:
        """Human-readable strategy name for display."""
