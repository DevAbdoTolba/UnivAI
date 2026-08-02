"""Small, deterministic PII redactor used before data reaches logs or traces."""

from __future__ import annotations

import re

REDACTED_EMAIL = "[EMAIL REDACTED]"
REDACTED_PHONE = "[PHONE REDACTED]"
REDACTED_CARD = "[PAYMENT CARD REDACTED]"
REDACTED_GOVERNMENT_ID = "[GOVERNMENT ID REDACTED]"
REDACTED_IP = "[IP REDACTED]"

_EMAIL = re.compile(r"(?<![\w.+-])[\w.+-]+@[\w-]+(?:\.[\w-]+)+(?![\w.-])")
_PHONE = re.compile(r"(?<!\w)(?:\+?\d[\d .()\-]{7,}\d)(?!\w)")
_CARD_CANDIDATE = re.compile(r"(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)")
_US_SSN = re.compile(r"(?<!\d)\d{3}-\d{2}-\d{4}(?!\d)")
_IPV4 = re.compile(
    r"(?<![\d.])(?:25[0-5]|2[0-4]\d|1?\d?\d)"
    r"(?:\.(?:25[0-5]|2[0-4]\d|1?\d?\d)){3}(?![\d.])"
)


def _passes_luhn(candidate: str) -> bool:
    digits = [int(character) for character in candidate if character.isdigit()]
    if not 13 <= len(digits) <= 19:
        return False
    total = 0
    parity = len(digits) % 2
    for index, digit in enumerate(digits):
        if index % 2 == parity:
            digit *= 2
            if digit > 9:
                digit -= 9
        total += digit
    return total % 10 == 0


def redact_pii(value: str) -> str:
    """Replace common PII forms while leaving non-text values to callers."""

    if not isinstance(value, str):
        raise TypeError("value must be text")
    redacted = _EMAIL.sub(REDACTED_EMAIL, value)
    redacted = _US_SSN.sub(REDACTED_GOVERNMENT_ID, redacted)
    redacted = _IPV4.sub(REDACTED_IP, redacted)
    redacted = _CARD_CANDIDATE.sub(
        lambda match: REDACTED_CARD if _passes_luhn(match.group(0)) else match.group(0),
        redacted,
    )
    return _PHONE.sub(REDACTED_PHONE, redacted)
