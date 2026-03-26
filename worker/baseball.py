"""Number baseball core logic.

Must produce identical results to BaseballLogic.swift.
"""

from __future__ import annotations

import random
from itertools import permutations

# All valid 3-digit guesses: digits 0-9, no repeats → 10P3 = 720
ALL_CANDIDATES: list[str] = [
    "".join(map(str, p)) for p in permutations(range(10), 3)
]

# Room code characters (matches RoomService.swift genCode — excludes I, O, 0, 1)
ROOM_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
GROUP_CHARS = "0123456789ABCDEF"


def strike_ball(secret: str, guess: str) -> tuple[int, int]:
    """Compute (strike, ball) count.

    Matches BaseballLogic.strikeBall(secret:guess:) in Swift exactly.
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
    """Generate a random 3-digit secret with unique digits.

    Matches BaseballLogic.randomSecret() in Swift.
    """
    digits = list(range(10))
    random.shuffle(digits)
    return "".join(map(str, digits[:3]))


def is_valid_guess(s: str) -> bool:
    """Validate that string is 3 unique digits.

    Matches BaseballLogic.validate3UniqueDigits() in Swift.
    """
    return len(s) == 3 and s.isdigit() and len(set(s)) == 3


def filter_candidates(
    candidates: list[str], guess: str, strike: int, ball: int
) -> list[str]:
    """Filter candidates that would produce the same (strike, ball) for the given guess."""
    return [c for c in candidates if strike_ball(c, guess) == (strike, ball)]


def gen_room_code(length: int = 5) -> str:
    """Generate a room code matching RoomService.swift genCode()."""
    return "".join(random.choice(ROOM_CHARS) for _ in range(length))


def gen_group_code(length: int = 3) -> str:
    """Generate a group code matching RoomService.swift genGroupCode()."""
    return "".join(random.choice(GROUP_CHARS) for _ in range(length))
