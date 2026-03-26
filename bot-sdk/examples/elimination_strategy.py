"""Elimination Strategy (Medium)

Filters out impossible numbers after each guess.
Picks randomly from remaining candidates.
Average: ~5-6 guesses to solve.
"""

import random
from sdk import Strategy, GuessResult, ALL_CANDIDATES, filter_candidates


class EliminationStrategy(Strategy):

    @property
    def name(self) -> str:
        return "Elimination (Medium)"

    def reset(self) -> None:
        pass

    def next_guess(self, history: list[GuessResult]) -> str:
        candidates = list(ALL_CANDIDATES)
        for gr in history:
            candidates = filter_candidates(
                candidates, gr.guess, gr.strike, gr.ball
            )

        if candidates:
            return random.choice(candidates)
        return random.choice(ALL_CANDIDATES)
