"""CLI bridge from the web app to the Agent practice-assessment MCP tool."""

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

from common.rag_client import RagUnavailable, generate_practice_assessment  # noqa: E402


def decode_payload(value: str) -> dict:
    if len(value) > 64_000:
        raise ValueError("practice payload is too large")
    padded = value + "=" * (-len(value) % 4)
    payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("practice payload must be an object")
    return payload


async def main() -> int:
    if len(sys.argv) != 2:
        print(json.dumps({"ok": False, "error": "usage: generate_practice.py <base64url-json>"}))
        return 2
    try:
        payload = decode_payload(sys.argv[1])
        raw = await generate_practice_assessment(
            topic_id=str(payload.get("topic_id") or ""),
            topic_title=str(payload.get("topic_title") or ""),
            topic_summary=str(payload.get("topic_summary") or ""),
            collection_id=str(payload.get("collection_id") or ""),
            user_id=str(payload.get("user_id") or ""),
            document_ids=[str(value) for value in payload.get("document_ids") or []],
        )
        result = json.loads(raw)
        if not isinstance(result, dict):
            raise ValueError("Agent returned an invalid practice envelope")
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
