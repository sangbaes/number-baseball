"""Number baseball core logic.

Utility functions for computing strike/ball, generating secrets,
filtering candidates, etc. You can use these in your strategy.
"""

from __future__ import annotations

import random
from itertools import permutations

# All valid 3-digit guesses: digits 0-9, no repeats -> 10P3 = 720
ALL_CANDIDATES: list[str] = [
    "".join(map(str, p)) for p in permutations(range(10), 3)
]

# Room code characters (excludes I, O, 0, 1 to avoid confusion)
ROOM_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


def strike_ball(secret: str, guess: str) -> tuple[int, int]:
    """Compute (strike, ball) count.

    Strike: correct digit in the correct position.
    Ball: correct digit in the wrong position.

    Example:
        strike_ball("123", "132") -> (1, 2)
        strike_ball("123", "456") -> (0, 0)
    """
    strike = 0
    ball = 0
    for i in range(3):
        if guess[i] == secret[i]:
            strike += 1
        elif guess[i] in secret:
            ball += 1
    return strike, ball


def random_secret() -> str:
    """Generate a random 3-digit secret with unique digits."""
    digits = list(range(10))
    random.shuffle(digits)
    return "".join(map(str, digits[:3]))


def is_valid_guess(s: str) -> bool:
    """Validate that string is 3 unique digits."""
    return len(s) == 3 and s.isdigit() and len(set(s)) == 3


def filter_candidates(
    candidates: list[str], guess: str, strike: int, ball: int
) -> list[str]:
    """Filter candidates that would produce the same (strike, ball) for the given guess.

    This is the core of elimination-based strategies:
    after each guess, only keep candidates that are consistent with the feedback.
    """
    return [c for c in candidates if strike_ball(c, guess) == (strike, ball)]


def gen_room_code(length: int = 5) -> str:
    """Generate a random room code."""
    return "".join(random.choice(ROOM_CHARS) for _ in range(length))
