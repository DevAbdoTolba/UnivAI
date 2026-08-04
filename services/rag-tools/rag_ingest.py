"""CLI bridge: hand an uploaded book to the team's RAG service for indexing.

The Next.js /upload route spawns this. The RAG service ingests by absolute file
path over MCP (ingest_file), so there is no HTTP upload endpoint to POST to.

    python services/rag-tools/rag_ingest.py "D:/path/to/book.pdf" [student_id]

The optional student_id namespaces the book to one learner in the RAG service
(multi-tenant). Omit it for the single-tenant fallback (RAG_USER_ID).

Prints one line of JSON: {"ok": true, "message": "..."} or {"ok": false, "error": "..."}
"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

# The CLI is executed by filename, so Python otherwise exposes only
# services/rag-tools on sys.path. `common.*` needs services/, while the shared
# observability/security imports inside it need the campus repository root.
CAMPUS_ROOT = Path(__file__).resolve().parents[2]
SERVICES_ROOT = CAMPUS_ROOT / "services"
for import_root in (SERVICES_ROOT, CAMPUS_ROOT):
    value = str(import_root)
    if value not in sys.path:
        sys.path.insert(0, value)

from common.rag_client import ingest_file, RagUnavailable  # noqa: E402


async def main() -> int:
    if len(sys.argv) < 2:
        print(json.dumps({"ok": False, "error": "usage: rag_ingest.py <absolute_pdf_path>"}))
        return 2

    path = Path(sys.argv[1]).resolve()
    user_id = sys.argv[2] if len(sys.argv) > 2 else None
    if not path.exists():
        print(json.dumps({"ok": False, "error": f"file not found: {path}"}))
        return 2

    try:
        message = await ingest_file(str(path), user_id)
    except RagUnavailable as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 1
    except Exception as exc:  # server down, tool renamed, protocol error
        print(json.dumps({"ok": False, "error": f"{type(exc).__name__}: {exc}"}))
        return 1

    # Their tool reports failures in the message text rather than by raising.
    ok = "Error" not in message and "Failed" not in message
    print(json.dumps({"ok": ok, "message": message}))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
