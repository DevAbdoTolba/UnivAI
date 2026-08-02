"""Recursive redaction for structured logs and trace attributes."""

from __future__ import annotations

import re
from collections.abc import Mapping
from typing import Any

from services.security.pii_redaction import redact_pii

REDACTED_SECRET = "[SECRET REDACTED]"
REDACTED_MEDIA = "[PRIVATE MEDIA REDACTED]"

_SECRET_KEY = re.compile(
    r"(?:authorization|cookie|credential|password|passwd|secret|api[_-]?key|"
    r"access[_-]?token|refresh[_-]?token|session)",
    re.IGNORECASE,
)
_MEDIA_KEY = re.compile(r"(?:audio|recording|voice[_-]?data|transcript)", re.IGNORECASE)
_BEARER = re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+")
_ASSIGNED_SECRET = re.compile(
    r"(?i)\b(api[_-]?key|access[_-]?token|refresh[_-]?token|password|secret)"
    r"\s*[:=]\s*([^\s,;]+)"
)
_URL_CREDENTIAL = re.compile(r"(?P<scheme>\b[a-z][a-z0-9+.-]*://)[^/@\s]+@", re.I)


def redact_text(value: str) -> str:
    redacted = _BEARER.sub(f"Bearer {REDACTED_SECRET}", value)
    redacted = _ASSIGNED_SECRET.sub(
        lambda match: f"{match.group(1)}={REDACTED_SECRET}", redacted
    )
    redacted = _URL_CREDENTIAL.sub(
        lambda match: f"{match.group('scheme')}{REDACTED_SECRET}@", redacted
    )
    return redact_pii(redacted)


def redact(value: Any, *, field_name: str | None = None) -> Any:
    """Return a safe copy suitable for serialization to a log sink."""

    if field_name and _SECRET_KEY.search(field_name):
        return REDACTED_SECRET
    if field_name and _MEDIA_KEY.search(field_name):
        return REDACTED_MEDIA
    if isinstance(value, (bytes, bytearray, memoryview)):
        return REDACTED_MEDIA
    if isinstance(value, str):
        return redact_text(value)
    if isinstance(value, Mapping):
        return {str(key): redact(item, field_name=str(key)) for key, item in value.items()}
    if isinstance(value, tuple):
        return tuple(redact(item) for item in value)
    if isinstance(value, list):
        return [redact(item) for item in value]
    if isinstance(value, set):
        return sorted((redact(item) for item in value), key=repr)
    return value


def redact_mapping(value: Mapping[str, Any]) -> dict[str, Any]:
    return {str(key): redact(item, field_name=str(key)) for key, item in value.items()}
