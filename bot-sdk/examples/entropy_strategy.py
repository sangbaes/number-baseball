"""Entropy Strategy (Hard)

Chooses the guess that maximizes information gain.
For each possible guess, computes how evenly it splits
the remaining candidates — picks the best splitter.
Average: ~4-5 guesses to solve.
"""

import math
import random
from collections import Counter

from sdk import (
    Strategy, GuessResult,
    ALL_CANDIDATES, filter_candidates, strike_ball,
)


class EntropyStrategy(Strategy):

    @property
    def name(self) -> str:
        return "Entropy (Hard)"

    def reset(self) -> None:
        pass

    def next_guess(self, history: list[GuessResult]) -> str:
        candidates = list(ALL_CANDIDATES)
        for gr in history:
            candidates = filter_candidates(
                candidates, gr.guess, gr.strike, gr.ball
            )

        if not candidates:
            return random.choice(ALL_CANDIDATES)
        if len(candidates) <= 2:
            return random.choice(candidates)

        # Evaluate candidates + a sample of non-candidates
        guesses_to_eval = list(candidates)
        others = [g for g in ALL_CANDIDATES if g not in set(candidates)]
        if len(others) > 100:
            others = random.sample(others, 100)
        guesses_to_eval.extend(others)

        best_guess = None
        best_score = (-1.0, False)

        for guess in guesses_to_eval:
            entropy = self._compute_entropy(guess, candidates)
            is_candidate = guess in candidates
            score = (entropy, is_candidate)
            if score > best_score:
                best_score = score
                best_guess = guess

        return best_guess or random.choice(candidates)

    @staticmethod
    def _compute_entropy(guess: str, candidates: list[str]) -> float:
        counter: Counter[tuple[int, int]] = Counter()
        for candidate in candidates:
            result = strike_ball(candidate, guess)
            counter[result] += 1

        total = len(candidates)
        entropy = 0.0
        for count in counter.values():
            if count > 0:
                p = count / total
                entropy -= p * math.log2(p)
        return entropy
