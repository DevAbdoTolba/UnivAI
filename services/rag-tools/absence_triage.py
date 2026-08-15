"""CLI bridge from the web app to the Agent absence-triage MCP tool."""

from __future__ import annotations

import asyncio
import base64
import json
import sys
from pathlib import Path

CAMPUS_ROOT = Path(__file__).resolve().parents[2]
SERVICES_ROOT = CAMPUS_ROOT / "services"
for import_root in (SERVICES_ROOT, CAMPUS_ROOT):
    value = str(import_root)
    if value not in sys.path:
        sys.path.insert(0, value)

from common.rag_client import RagUnavailable, triage_absence  # noqa: E402


def decode_payload(value: str) -> dict:
    if len(value) > 32_000:
        raise ValueError("triage payload is too large")
    padded = value + "=" * (-len(value) % 4)
    raw = base64.urlsafe_b64decode(padded.encode("ascii"))
    payload = json.loads(raw.decode("utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("triage payload must be an object")
    return payload


async def main() -> int:
    if len(sys.argv) != 2:
        print(json.dumps({"ok": False, "error": "usage: absence_triage.py <base64url-json>"}))
        return 2
    try:
        payload = decode_payload(sys.argv[1])
        facts = payload.get("case_facts")
        prior = payload.get("prior_answers", "")
        if not isinstance(facts, str) or not isinstance(prior, str):
            raise ValueError("case_facts and prior_answers must be strings")
        raw = await triage_absence(facts, prior)
        result = json.loads(raw)
        if not isinstance(result, dict):
            raise ValueError("Agent returned an invalid triage envelope")
    except (RagUnavailable, ValueError, json.JSONDecodeError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 1
    except Exception as exc:
        print(json.dumps({"ok": False, "error": f"{type(exc).__name__}: {exc}"}))
        return 1
    print(json.dumps({"ok": True, "result": result}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
