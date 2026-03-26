"""Random Strategy (Easy)

Picks a random valid number every turn.
Ignores all previous results — pure luck!
Average: ~100+ guesses to solve.
"""

import random
from sdk import Strategy, GuessResult, ALL_CANDIDATES


class RandomStrategy(Strategy):

    @property
    def name(self) -> str:
        return "Random (Easy)"

    def reset(self) -> None:
        pass

    def next_guess(self, history: list[GuessResult]) -> str:
        return random.choice(ALL_CANDIDATES)
