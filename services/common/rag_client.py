"""Client for the team's EXISTING RAG service. This app does NOT implement RAG.

The RAG system (loading, chunking, embeddings, Qdrant, hybrid search + RRF,
cross-encoder reranking, citations) is owned by the team and lives in its own
repo. Here we only *consume* it over MCP.

Their server (UnivAI-Agent/mcp_server.py) speaks **streamable-http**, not stdio,
and exposes:

    retrieve_context(query, user_id, limit, use_reranking, use_query_transform)
        -> a formatted string, one block per hit:
           "[1] Source: book.pdf | Page: 2 | Chunk: 4/5 | Score: 0.0000\nContent: ..."
    ingest_file(file_path, user_id) -> str
    list_documents(user_id) / remove_document(user_id, document_id)

Two things their contract forces on us:
  * every call needs a user_id — MVP-1 is single-student, so we send RAG_USER_ID.
  * retrieval NEVER returns empty: a vector search always yields nearest
    neighbours, even for a question the book does not cover. So "not in the book"
    cannot be decided by an empty result. We keep only hits at or above
    RAG_MIN_SCORE and let the LLM refuse from the passages it is given.
"""

from __future__ import annotations

import os
import re
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

RAG_MCP_URL = os.getenv("RAG_MCP_URL", "").strip()
RAG_USER_ID = os.getenv("RAG_USER_ID", "student")
RAG_TOOL_SEARCH = os.getenv("RAG_TOOL_SEARCH", "retrieve_context")
RAG_TOOL_INGEST = os.getenv("RAG_TOOL_INGEST", "ingest_file")
# Reranked cross-encoder scores; below this we treat a hit as noise, not evidence.
RAG_MIN_SCORE = float(os.getenv("RAG_MIN_SCORE", "0"))

# Their citation header, e.g.
#   "[1] Source: book.pdf | Page: 12 | Chunk: 4/5 | Score: 0.9812"
# The Page field is absent for non-paginated sources, so we read the fields by
# name rather than by position.
_HEADER = re.compile(r"^\[\d+\]\s*(?P<fields>.+)$", re.MULTILINE)


def _parse_header(block: str) -> dict[str, str] | None:
    match = _HEADER.search(block)
    if not match:
        return None
    fields: dict[str, str] = {}
    for part in match.group("fields").split("|"):
        key, sep, value = part.partition(":")
        if sep:
            fields[key.strip().lower()] = value.strip()
    return fields


class RagUnavailable(RuntimeError):
    """The RAG service is not configured or not reachable."""


async def _call_tool(tool: str, arguments: dict) -> str:
    if not RAG_MCP_URL:
        raise RagUnavailable("RAG_MCP_URL is not set — point it at the team's RAG MCP server")

    # Imported lazily so the app runs before the RAG server is wired up.
    from mcp import ClientSession
    from mcp.client.streamable_http import streamablehttp_client

    async with streamablehttp_client(RAG_MCP_URL) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool(tool, arguments)

    return "\n".join(getattr(item, "text", "") for item in result.content).strip()


def parse_hits(formatted: str) -> list[dict]:
    """Turn their formatted string back into {page, text, score, source} records."""
    if not formatted or formatted.startswith("No relevant documents"):
        return []

    hits: list[dict] = []
    for block in re.split(r"\n-{3,}\n", formatted):
        fields = _parse_header(block)
        if not fields:
            continue

        _, _, content = block.partition("Content:")
        page = fields.get("page")
        try:
            score = float(fields.get("score", 0))
        except ValueError:
            score = 0.0

        hits.append(
            {
                "source": fields.get("source", ""),
                "page": int(page) if page and page.isdigit() else None,
                "score": score,
                "text": content.strip() or block.strip(),
            }
        )
    return hits


async def search_book(query: str, top_k: int = 5) -> list[dict]:
    """Retrieve cited passages for a student's question."""
    formatted = await _call_tool(
        RAG_TOOL_SEARCH,
        {
            "query": query,
            "user_id": RAG_USER_ID,
            "limit": top_k,
            "use_reranking": True,
        },
    )
    hits = parse_hits(formatted)
    return [hit for hit in hits if hit["score"] >= RAG_MIN_SCORE]


async def ingest_file(absolute_path: str) -> str:
    """Hand a saved book to the RAG service for indexing. It reads the path itself."""
    return await _call_tool(RAG_TOOL_INGEST, {"file_path": absolute_path, "user_id": RAG_USER_ID})
