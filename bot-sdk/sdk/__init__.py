"""Number Baseball Bot SDK.

Create your own bot by implementing a Strategy subclass.
See my_strategy.py for a template.
"""

from .strategy import Strategy, GuessResult
from .baseball import (
    strike_ball,
    filter_candidates,
    random_secret,
    is_valid_guess,
    ALL_CANDIDATES,
)

__all__ = [
    "Strategy",
    "GuessResult",
    "strike_ball",
    "filter_candidates",
    "random_secret",
    "is_valid_guess",
    "ALL_CANDIDATES",
]
