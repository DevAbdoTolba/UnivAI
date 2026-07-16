"""Clear the user's knowledge base in the team's RAG service.

    python services/rag_admin.py clear

Used when the book is replaced: the old book's chunks must go, or the lecturer
would keep answering questions from a book the course no longer teaches.
Prints one line of JSON: {"ok": true, "removed": N} or {"ok": false, "error": "..."}.
"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from common.rag_client import _call_tool, RAG_USER_ID, RagUnavailable  # noqa: E402


async def clear() -> dict:
    # Deleting a whole textbook's chunks takes longer than a live-lecture
    # retrieval; don't let the fail-fast default kill a working cleanup.
    listing = await _call_tool("list_documents", {"user_id": RAG_USER_ID}, timeout=120)
    if listing.startswith("No documents"):
        return {"ok": True, "removed": 0}
    if listing.startswith("Error"):
        return {"ok": False, "error": listing}

    documents = json.loads(listing)
    removed = 0
    for document in documents:
        reply = await _call_tool(
            "remove_document",
            {"user_id": RAG_USER_ID, "document_id": document["document_id"]},
            timeout=300,
        )
        if reply.startswith("Error"):
            return {"ok": False, "error": reply, "removed": removed}
        removed += 1
    return {"ok": True, "removed": removed}


async def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] != "clear":
        print(json.dumps({"ok": False, "error": "usage: rag_admin.py clear"}))
        return 2
    try:
        result = await clear()
    except RagUnavailable as exc:
        result = {"ok": False, "error": str(exc)}
    except Exception as exc:  # server down, bad JSON from their tool
        result = {"ok": False, "error": f"{type(exc).__name__}: {exc}"}
    print(json.dumps(result))
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
