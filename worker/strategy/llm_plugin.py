"""LLM-based strategy stub for future implementation.

To use, implement a callable that accepts a prompt string and returns
the LLM's text response. Then register it in strategy/__init__.py.

Example usage (future):
    from worker.strategy.llm_plugin import LLMStrategy

    def call_llm(prompt: str) -> str:
        import anthropic
        client = anthropic.Anthropic()
        msg = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=100,
            messages=[{"role": "user", "content": prompt}],
        )
        return msg.content[0].text

    strategy = LLMStrategy(llm_fn=call_llm)
"""

from __future__ import annotations

from typing import Callable

from .base import GuessResult, Strategy


PROMPT_TEMPLATE = """You are playing Number Baseball.
The secret is a 3-digit number with unique digits (0-9).
After each guess, you receive Strike (S) and Ball (B) feedback:
- Strike: correct digit in correct position
- Ball: correct digit in wrong position

{history_section}

Based on the feedback above, what is your next guess?
Reply with ONLY the 3-digit number, nothing else."""


class LLMStrategy(Strategy):
    """Strategy that delegates guessing to an LLM API.

    Args:
        llm_fn: A callable that takes a prompt string and returns the LLM response text.
    """

    def __init__(self, llm_fn: Callable[[str], str] | None = None) -> None:
        self._llm_fn = llm_fn

    @property
    def name(self) -> str:
        return "LLM"

    def reset(self) -> None:
        pass

    def next_guess(self, history: list[GuessResult]) -> str:
        if self._llm_fn is None:
            raise NotImplementedError(
                "LLM strategy requires an llm_fn callable. "
                "See llm_plugin.py docstring for usage."
            )

        # Build history section
        if not history:
            history_text = "No guesses yet. Make your first guess."
        else:
            lines = []
            for i, gr in enumerate(history, 1):
                lines.append(f"Guess #{i}: {gr.guess} → {gr.strike}S {gr.ball}B")
            history_text = "Previous guesses:\n" + "\n".join(lines)

        prompt = PROMPT_TEMPLATE.format(history_section=history_text)
        response = self._llm_fn(prompt).strip()

        # Extract 3 digits from response
        digits = "".join(c for c in response if c.isdigit())
        if len(digits) >= 3:
            return digits[:3]

        # Fallback if LLM response is invalid
        from ..baseball import ALL_CANDIDATES
        import random
        return random.choice(ALL_CANDIDATES)
