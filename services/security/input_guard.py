"""Validation boundaries for text sent to public AI endpoints.

The guard is intentionally deterministic. It rejects malformed or clearly hostile
instructions before an external model is called; it does not claim to be a full
content-moderation system.
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass

DEFAULT_MAX_INPUT_CHARS = 12_000
DEFAULT_MAX_OUTPUT_CHARS = 24_000


class InputRejected(ValueError):
    """Raised when public AI input violates a documented guardrail."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


class OutputLimitExceeded(ValueError):
    """Raised instead of returning a partial or unexpectedly large AI object."""


@dataclass(frozen=True)
class GuardResult:
    text: str
    matched_rule: str | None = None


_CONTROL_CHARACTERS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")
_INJECTION_RULES: tuple[tuple[str, re.Pattern[str]], ...] = (
    (
        "instruction_override",
        re.compile(
            r"\b(?:ignore|disregard|forget|override)\b.{0,80}"
            r"\b(?:previous|prior|above|system|developer)\b.{0,30}"
            r"\b(?:instruction|message|prompt|rule)s?\b",
            re.IGNORECASE | re.DOTALL,
        ),
    ),
    (
        "prompt_exfiltration",
        re.compile(
            r"\b(?:reveal|show|print|repeat|leak|expose)\b.{0,60}"
            r"\b(?:system|developer|hidden|initial)\b.{0,30}"
            r"\b(?:prompt|message|instruction|secret)s?\b",
            re.IGNORECASE | re.DOTALL,
        ),
    ),
    (
        "role_injection",
        re.compile(
            r"(?:<\/?(?:system|developer|assistant)>|"
            r"\[(?:system|developer|assistant)\]|"
            r"^(?:system|developer)\s*:)",
            re.IGNORECASE | re.MULTILINE,
        ),
    ),
)


def inspect_input(
    value: str,
    *,
    max_chars: int = DEFAULT_MAX_INPUT_CHARS,
    reject_prompt_injection: bool = True,
) -> GuardResult:
    """Normalize and inspect one user-controlled text value."""

    if not isinstance(value, str):
        raise InputRejected("invalid_type", "input must be text")
    if max_chars < 1:
        raise ValueError("max_chars must be positive")

    text = unicodedata.normalize("NFC", value).strip()
    if not text:
        raise InputRejected("empty_input", "input must not be empty")
    if len(text) > max_chars:
        raise InputRejected(
            "input_too_large", f"input exceeds the {max_chars}-character limit"
        )
    if _CONTROL_CHARACTERS.search(text):
        raise InputRejected("control_character", "input contains a control character")

    if reject_prompt_injection:
        for name, pattern in _INJECTION_RULES:
            if pattern.search(text):
                raise InputRejected(
                    "prompt_injection", f"input matched security rule: {name}"
                )
    return GuardResult(text=text)


def validate_input(
    value: str,
    *,
    max_chars: int = DEFAULT_MAX_INPUT_CHARS,
    reject_prompt_injection: bool = True,
) -> str:
    """Return safe normalized input or raise :class:`InputRejected`."""

    return inspect_input(
        value,
        max_chars=max_chars,
        reject_prompt_injection=reject_prompt_injection,
    ).text


def enforce_output_limit(
    value: str, *, max_chars: int = DEFAULT_MAX_OUTPUT_CHARS
) -> str:
    """Reject oversized model output; never silently return truncated JSON."""

    if not isinstance(value, str):
        raise TypeError("output must be text")
    if max_chars < 1:
        raise ValueError("max_chars must be positive")
    if len(value) > max_chars:
        raise OutputLimitExceeded(
            f"model output exceeds the {max_chars}-character limit"
        )
    return value
