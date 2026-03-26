from __future__ import annotations

import math
import random
from collections import Counter

from ..baseball import ALL_CANDIDATES, filter_candidates, strike_ball
from .base import GuessResult, Strategy


class EntropyStrategy(Strategy):
    """Hard difficulty: chooses the guess that maximizes information gain (entropy).

    For each possible guess, computes the distribution of (strike, ball) outcomes
    across remaining candidates. Picks the guess whose outcome distribution has
    the highest entropy (= most evenly splits the candidate space).

    Optimal play: typically solves in 5-6 guesses on average.
    """

    def __init__(self) -> None:
        self._candidates: list[str] = []

    @property
    def name(self) -> str:
        return "Entropy (Hard)"

    def reset(self) -> None:
        self._candidates = list(ALL_CANDIDATES)

    def next_guess(self, history: list[GuessResult]) -> str:
        # Rebuild candidates from full history
        candidates = list(ALL_CANDIDATES)
        for gr in history:
            candidates = filter_candidates(candidates, gr.guess, gr.strike, gr.ball)

        self._candidates = candidates

        if not candidates:
            return random.choice(ALL_CANDIDATES)

        # If only one candidate left, guess it
        if len(candidates) == 1:
            return candidates[0]

        # If two candidates, just pick one
        if len(candidates) <= 2:
            return random.choice(candidates)

        # Evaluate all possible guesses (from ALL_CANDIDATES, not just remaining)
        # Using all candidates as potential guesses can find better information splits
        best_guess = None
        best_entropy = -1.0

        # For performance, evaluate candidates first (they can also be the answer)
        # then a sample of all candidates if the candidate pool is large
        guesses_to_eval = list(candidates)
        if len(candidates) < len(ALL_CANDIDATES):
            # Also consider some non-candidate guesses for better splits
            others = [g for g in ALL_CANDIDATES if g not in set(candidates)]
            # Sample to keep computation manageable
            if len(others) > 100:
                others = random.sample(others, 100)
            guesses_to_eval.extend(others)

        for guess in guesses_to_eval:
            entropy = self._compute_entropy(guess, candidates)
            # Prefer candidates over non-candidates when entropy is equal
            is_candidate = guess in candidates
            score = (entropy, is_candidate)
            if score > (best_entropy, False) or (score[0] > best_entropy):
                best_entropy = entropy
                best_guess = guess

        return best_guess or random.choice(candidates)

    @staticmethod
    def _compute_entropy(guess: str, candidates: list[str]) -> float:
        """Compute the Shannon entropy of the (strike, ball) distribution for a guess."""
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
