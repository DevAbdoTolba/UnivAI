"""CLI bridge from the web app to the Agent programme-planning tool."""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

CAMPUS_ROOT = Path(__file__).resolve().parents[2]
SERVICES_ROOT = CAMPUS_ROOT / "services"
for import_root in (SERVICES_ROOT, CAMPUS_ROOT):
    value = str(import_root)
    if value not in sys.path:
        sys.path.insert(0, value)

from common.rag_client import RagUnavailable, create_programme_plan  # noqa: E402


async def main() -> int:
    if len(sys.argv) < 5:
        print(json.dumps({"ok": False, "error": "usage: rag_plan.py <title> <collection_id> <student_id> <seed_query> [...]"}))
        return 2

    title, collection_id, student_id = sys.argv[1:4]
    try:
        seed_queries = sys.argv[4:]
        raw = await create_programme_plan(title, collection_id, student_id, seed_queries)
        if raw.startswith("Error") or raw.startswith("REFUSED"):
            raise RuntimeError(raw)
        result = json.loads(raw)
        if not result.get("plan"):
            reasons = [item.get("reason", "") for item in result.get("refusals", [])]
            raise RuntimeError("; ".join(filter(None, reasons)) or "The Agent could not create a grounded curriculum.")
    except (RagUnavailable, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 1
    except Exception as exc:
        print(json.dumps({"ok": False, "error": f"{type(exc).__name__}: {exc}"}))
        return 1

    print(json.dumps({"ok": True, "result": result}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
