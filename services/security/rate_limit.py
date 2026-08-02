"""Thread-safe sliding-window rate limits for a single-host deployment."""

from __future__ import annotations

import hashlib
import ipaddress
import math
import threading
import time
from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Callable

from services.security.input_guard import DEFAULT_MAX_INPUT_CHARS, validate_input


@dataclass(frozen=True)
class RateLimitDecision:
    allowed: bool
    limit: int
    remaining: int
    retry_after: int
    key: str

    def headers(self) -> dict[str, str]:
        headers = {
            "RateLimit-Limit": str(self.limit),
            "RateLimit-Remaining": str(self.remaining),
        }
        if not self.allowed:
            headers["Retry-After"] = str(self.retry_after)
        return headers


class RateLimitExceeded(RuntimeError):
    def __init__(self, decision: RateLimitDecision) -> None:
        super().__init__(f"rate limit exceeded; retry in {decision.retry_after}s")
        self.decision = decision


class InMemoryRateLimiter:
    """Limit both the authenticated user and source IP when both are known."""

    def __init__(
        self,
        limit: int = 30,
        window_seconds: float = 60,
        *,
        clock: Callable[[], float] = time.monotonic,
        max_keys: int = 10_000,
    ) -> None:
        if limit < 1 or window_seconds <= 0 or max_keys < 1:
            raise ValueError("limit, window_seconds, and max_keys must be positive")
        self.limit = limit
        self.window_seconds = window_seconds
        self.max_keys = max_keys
        self._clock = clock
        self._events: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    @staticmethod
    def _keys(user_id: str | None, ip: str | None) -> list[str]:
        keys: list[str] = []
        if user_id and user_id.strip():
            digest = hashlib.sha256(user_id.strip().encode()).hexdigest()[:32]
            keys.append(f"user:{digest}")
        if ip and ip.strip():
            try:
                normalized_ip = ipaddress.ip_address(ip.strip()).compressed
            except ValueError as exc:
                raise ValueError("ip must be a valid IPv4 or IPv6 address") from exc
            digest = hashlib.sha256(normalized_ip.encode()).hexdigest()[:32]
            keys.append(f"ip:{digest}")
        if not keys:
            raise ValueError("user_id or ip is required")
        return keys

    def _prune(self, events: deque[float], now: float) -> None:
        cutoff = now - self.window_seconds
        while events and events[0] <= cutoff:
            events.popleft()

    def check(
        self, *, user_id: str | None = None, ip: str | None = None
    ) -> RateLimitDecision:
        keys = self._keys(user_id, ip)
        now = self._clock()
        with self._lock:
            for key in keys:
                self._prune(self._events[key], now)

            blocked_key = next(
                (key for key in keys if len(self._events[key]) >= self.limit), None
            )
            if blocked_key is not None:
                retry = max(
                    1,
                    math.ceil(
                        self.window_seconds - (now - self._events[blocked_key][0])
                    ),
                )
                return RateLimitDecision(False, self.limit, 0, retry, blocked_key)

            if len(self._events) > self.max_keys:
                empty = [key for key, events in self._events.items() if not events]
                for key in empty[: len(self._events) - self.max_keys]:
                    del self._events[key]

            for key in keys:
                self._events[key].append(now)
            remaining = min(self.limit - len(self._events[key]) for key in keys)
            return RateLimitDecision(True, self.limit, remaining, 0, keys[0])

    def enforce(
        self, *, user_id: str | None = None, ip: str | None = None
    ) -> RateLimitDecision:
        decision = self.check(user_id=user_id, ip=ip)
        if not decision.allowed:
            raise RateLimitExceeded(decision)
        return decision


RateLimiter = InMemoryRateLimiter


@dataclass(frozen=True)
class ProtectedInput:
    text: str
    rate_limit: RateLimitDecision


def protect_public_ai_input(
    value: str,
    limiter: InMemoryRateLimiter,
    *,
    user_id: str | None = None,
    ip: str | None = None,
    max_chars: int = DEFAULT_MAX_INPUT_CHARS,
) -> ProtectedInput:
    """Apply the endpoint contract in one call: quota first, then input guard."""

    decision = limiter.enforce(user_id=user_id, ip=ip)
    return ProtectedInput(validate_input(value, max_chars=max_chars), decision)
