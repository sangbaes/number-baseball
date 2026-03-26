from .base import Strategy, GuessResult
from .noisy import NoisyStrategy
from .random_strategy import RandomStrategy
from .elimination import EliminationStrategy
from .entropy import EntropyStrategy

STRATEGIES: dict[str, type[Strategy]] = {
    "random": RandomStrategy,
    "elimination": EliminationStrategy,
    "entropy": EntropyStrategy,
}


def get_strategy(name: str, error_rate: float = 0.0) -> Strategy:
    """Get a strategy instance by name, optionally wrapped with noise."""
    cls = STRATEGIES.get(name)
    if cls is None:
        available = ", ".join(STRATEGIES.keys())
        raise ValueError(f"Unknown strategy: {name}. Available: {available}")
    strategy = cls()
    if error_rate > 0:
        return NoisyStrategy(strategy, error_rate)
    return strategy
