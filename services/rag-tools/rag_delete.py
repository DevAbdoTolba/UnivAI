"""Delete one uploaded collection source from the learner's RAG namespace.

    python services/rag-tools/rag_delete.py <student_id> <collection_id> <source_filename>

The MCP server derives the deterministic Qdrant document ID. The caller never
supplies an index ID, and the server filters deletion by both document and
tenant. One JSON line is printed for the Next.js route.
"""

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

from common.rag_client import (  # noqa: E402
    RagUnavailable,
    remove_collection_document,
)


async def main() -> int:
    if len(sys.argv) != 4:
        print(
            json.dumps(
                {
                    "ok": False,
                    "error": (
                        "usage: rag_delete.py <student_id> <collection_id> "
                        "<source_filename>"
                    ),
                }
            )
        )
        return 2

    user_id, collection_id, source_filename = sys.argv[1:4]
    try:
        message = await remove_collection_document(
            user_id,
            collection_id,
            source_filename,
        )
        if message.startswith("Error"):
            raise RuntimeError(message)
    except (RagUnavailable, RuntimeError) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 1
    except Exception as exc:
        print(json.dumps({"ok": False, "error": f"{type(exc).__name__}: {exc}"}))
        return 1

    print(json.dumps({"ok": True, "message": message}))
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
