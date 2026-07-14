"""ClockService (Python side).

The ONLY place in the Python services allowed to read the system clock
(Ground Rule 4 of the MVP-1 prompt). Virtual time = wall clock + offset_ms,
with offset_ms stored in Postgres so the Next.js app and these services share
one clock.

Never call time.time() / datetime.now() anywhere else.
"""

from __future__ import annotations

import time
from datetime import datetime, timezone

from .db import fetch_one, execute


def _wall_clock_ms() -> int:
    """The one sanctioned wall-clock read in the Python codebase."""
    return int(time.time() * 1000)


def get_offset_ms() -> int:
    row = fetch_one("SELECT offset_ms FROM clock_state WHERE id = 1")
    return int(row["offset_ms"]) if row else 0


def now() -> datetime:
    """Current virtual time (timezone-aware, UTC)."""
    ms = _wall_clock_ms() + get_offset_ms()
    return datetime.fromtimestamp(ms / 1000, tz=timezone.utc)


def set_offset_ms(offset_ms: int) -> datetime:
    execute(
        "INSERT INTO clock_state (id, offset_ms) VALUES (1, %s) "
        "ON CONFLICT (id) DO UPDATE SET offset_ms = EXCLUDED.offset_ms",
        (int(offset_ms),),
    )
    return now()
