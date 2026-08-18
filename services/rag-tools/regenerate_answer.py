"""Regenerate one recorded raised-hand answer against the same bounded context."""

from __future__ import annotations

import asyncio
import base64
import json
import sys
from pathlib import Path

CAMPUS_ROOT = Path(__file__).resolve().parents[2]
LIVE_ROOT = CAMPUS_ROOT / "UnivAI-live"
SERVICES_ROOT = CAMPUS_ROOT / "services"
for import_root in (LIVE_ROOT, SERVICES_ROOT, CAMPUS_ROOT):
    value = str(import_root)
    if value not in sys.path:
        sys.path.insert(0, value)

from qa import answer_question  # noqa: E402
from qa_context import context_from_dict  # noqa: E402


def decode_payload(value: str) -> dict:
    if len(value) > 64_000:
        raise ValueError("regeneration payload is too large")
    padded = value + "=" * (-len(value) % 4)
    payload = json.loads(base64.urlsafe_b64decode(padded).decode("utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("regeneration payload must be an object")
    return payload


async def main() -> int:
    if len(sys.argv) != 2:
        print(json.dumps({"ok": False, "error": "usage: regenerate_answer.py <base64url-json>"}))
        return 2
    try:
        payload = decode_payload(sys.argv[1])
        question = payload.get("question")
        sid = payload.get("student_id")
        if not isinstance(question, str) or not question.strip() or not isinstance(sid, str):
            raise ValueError("question and student_id are required")
        result = await answer_question(
            question.strip(),
            lecture_id=payload.get("lecture_internal_id"),
            sid=sid,
            programme_id=str(payload.get("programme_id") or ""),
            course_id=str(payload.get("course_id") or ""),
            plan_version=payload.get("plan_version")
            if isinstance(payload.get("plan_version"), int)
            else None,
            lecture_id_str=str(payload.get("lecture_public_id") or ""),
            context=context_from_dict(payload.get("context_snapshot")),
            persist=False,
        )
    except Exception as exc:
        print(json.dumps({"ok": False, "error": f"{type(exc).__name__}: {exc}"}))
        return 1
    print(json.dumps({"ok": True, "result": result}, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
