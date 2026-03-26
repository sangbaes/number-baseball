"""My custom Number Baseball strategy.

Edit this file to implement your own guessing logic!
The bot will call next_guess() each turn with the history
of previous guesses and their results.

Tip: You can use helper functions from the SDK:
    from sdk import strike_ball, filter_candidates, ALL_CANDIDATES
"""

import random

from sdk import Strategy, GuessResult, ALL_CANDIDATES, filter_candidates


class MyStrategy(Strategy):

    @property
    def name(self) -> str:
        return "My Strategy"

    def reset(self) -> None:
        """Called at the start of each new game."""
        pass

    def next_guess(self, history: list[GuessResult]) -> str:
        """Return a 3-digit guess string (e.g. "152").

        Each digit must be unique (0-9, no repeats).

        Args:
            history: Previous guesses and their results.
                history[i].guess  -> "123" (what was guessed)
                history[i].strike -> 1     (correct position)
                history[i].ball   -> 1     (correct digit, wrong position)

        Returns:
            A string of 3 unique digits.
        """
        # Start with all 720 possible numbers
        candidates = list(ALL_CANDIDATES)

        # Filter out numbers that don't match previous results
        for gr in history:
            candidates = filter_candidates(
                candidates, gr.guess, gr.strike, gr.ball
            )

        # Pick a random candidate from what's left
        if candidates:
            return random.choice(candidates)

        # Fallback (should never happen)
        return random.choice(ALL_CANDIDATES)
