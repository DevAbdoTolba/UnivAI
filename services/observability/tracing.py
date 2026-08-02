"""W3C trace propagation and redacted structured JSON logging."""

from __future__ import annotations

import contextvars
import json
import logging
import re
import secrets
import time
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Iterator, Mapping

from services.observability.redaction import redact_mapping, redact_text

_TRACEPARENT = re.compile(
    r"^00-(?P<trace>[0-9a-f]{32})-(?P<span>[0-9a-f]{16})-(?P<flags>[0-9a-f]{2})$"
)
_REQUEST_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$")


@dataclass(frozen=True)
class TraceContext:
    request_id: str
    trace_id: str
    span_id: str
    trace_flags: str = "01"

    @property
    def traceparent(self) -> str:
        return f"00-{self.trace_id}-{self.span_id}-{self.trace_flags}"


_current_context: contextvars.ContextVar[TraceContext | None] = contextvars.ContextVar(
    "univai_trace_context", default=None
)


def _header(headers: Mapping[str, str] | None, name: str) -> str | None:
    if not headers:
        return None
    target = name.lower()
    for key, value in headers.items():
        if key.lower() == target:
            return value.strip()
    return None


def new_trace_context(request_id: str | None = None) -> TraceContext:
    if request_id is not None and not _REQUEST_ID.fullmatch(request_id):
        raise ValueError("request_id contains unsupported characters")
    return TraceContext(
        request_id=request_id or secrets.token_hex(16),
        trace_id=secrets.token_hex(16),
        span_id=secrets.token_hex(8),
    )


def extract_trace_context(headers: Mapping[str, str] | None = None) -> TraceContext:
    request_id = _header(headers, "x-request-id")
    if request_id and not _REQUEST_ID.fullmatch(request_id):
        request_id = None
    traceparent = (_header(headers, "traceparent") or "").lower()
    match = _TRACEPARENT.fullmatch(traceparent)
    if not match or match.group("trace") == "0" * 32 or match.group("span") == "0" * 16:
        return new_trace_context(request_id)
    return TraceContext(
        request_id=request_id or secrets.token_hex(16),
        trace_id=match.group("trace"),
        span_id=secrets.token_hex(8),
        trace_flags=match.group("flags"),
    )


def current_trace_context() -> TraceContext:
    context = _current_context.get()
    if context is None:
        context = new_trace_context()
        _current_context.set(context)
    return context


def trace_headers() -> dict[str, str]:
    context = current_trace_context()
    return {"X-Request-ID": context.request_id, "traceparent": context.traceparent}


@contextmanager
def trace_scope(
    headers: Mapping[str, str] | None = None, *, request_id: str | None = None
) -> Iterator[TraceContext]:
    context = (
        new_trace_context(request_id)
        if request_id is not None
        else extract_trace_context(headers)
    )
    token = _current_context.set(context)
    try:
        yield context
    finally:
        _current_context.reset(token)


class JsonFormatter(logging.Formatter):
    """One-line JSON formatter that never serializes raw secret/media fields."""

    def format(self, record: logging.LogRecord) -> str:
        context = _current_context.get()
        payload: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": redact_text(record.getMessage()),
        }
        if context:
            payload.update(
                request_id=context.request_id,
                trace_id=context.trace_id,
                span_id=context.span_id,
            )
        fields = getattr(record, "event_fields", None)
        if isinstance(fields, Mapping):
            payload["fields"] = redact_mapping(fields)
        if record.exc_info:
            payload["exception"] = redact_text(self.formatException(record.exc_info))
        return json.dumps(payload, ensure_ascii=False, separators=(",", ":"), default=str)


def configure_json_logging(level: int | str = logging.INFO) -> None:
    handler = logging.StreamHandler()
    handler.setFormatter(JsonFormatter())
    root = logging.getLogger()
    root.handlers.clear()
    root.addHandler(handler)
    root.setLevel(level)


def log_event(
    logger: logging.Logger, level: int, message: str, **fields: Any
) -> None:
    logger.log(level, message, extra={"event_fields": fields})


@contextmanager
def span(
    name: str, *, logger: logging.Logger | None = None, **attributes: Any
) -> Iterator[TraceContext]:
    """Emit start/end/error events while preserving the correlated trace ID."""

    active_logger = logger or logging.getLogger("univai.trace")
    parent = current_trace_context()
    child = TraceContext(
        request_id=parent.request_id,
        trace_id=parent.trace_id,
        span_id=secrets.token_hex(8),
        trace_flags=parent.trace_flags,
    )
    token = _current_context.set(child)
    started = time.monotonic()
    log_event(active_logger, logging.INFO, "span.start", span=name, **attributes)
    try:
        yield child
    except Exception:
        log_event(
            active_logger,
            logging.ERROR,
            "span.error",
            span=name,
            duration_ms=round((time.monotonic() - started) * 1000, 3),
        )
        raise
    else:
        log_event(
            active_logger,
            logging.INFO,
            "span.end",
            span=name,
            duration_ms=round((time.monotonic() - started) * 1000, 3),
        )
    finally:
        _current_context.reset(token)
