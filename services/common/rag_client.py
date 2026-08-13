"""Client for the team's EXISTING RAG service. This app does NOT implement RAG.

The RAG system (loading, chunking, embeddings, Qdrant, hybrid search + RRF,
cross-encoder reranking, citations) is owned by the team and lives in its own
repo. Here we only *consume* it over MCP.

Their server (UnivAI-Agent/mcp_server.py) speaks **streamable-http**, not stdio,
and exposes:

    retrieve_context(query, user_id, limit, use_reranking, use_query_transform)
        -> one HTML-escaped JSON ``retrieved-passage`` envelope per hit. Older
           servers returned a plain citation header followed by ``Content:``;
           the parser intentionally accepts both during rolling upgrades.
    ingest_file(file_path, user_id) -> str
    list_documents(user_id) / remove_document(user_id, document_id)
    remove_collection_document(user_id, collection_id, source_filename)

Two things their contract forces on us:
  * every call needs a user_id — MVP-1 is single-student, so we send RAG_USER_ID.
  * retrieval NEVER returns empty: a vector search always yields nearest
    neighbours, even for a question the book does not cover. So "not in the book"
    cannot be decided by an empty result. We preserve the reranked order and
    let the LLM refuse from the passages it is given; only a deliberately
    calibrated non-zero RAG_MIN_SCORE enables an absolute score cutoff.
"""

from __future__ import annotations

import os
import re
import json
from html import unescape
from pathlib import Path

import asyncio

from dotenv import load_dotenv

from services.observability.tracing import trace_headers
from services.security.input_guard import InputRejected, validate_input

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

RAG_MCP_URL = os.getenv("RAG_MCP_URL", "").strip()
RAG_USER_ID = os.getenv("RAG_USER_ID", "student")
RAG_TOOL_SEARCH = os.getenv("RAG_TOOL_SEARCH", "retrieve_context")
RAG_TOOL_INGEST = os.getenv("RAG_TOOL_INGEST", "ingest_file")
RAG_TOOL_INGEST_COLLECTION = os.getenv("RAG_TOOL_INGEST_COLLECTION", "ingest_collection")
RAG_TOOL_PLAN = os.getenv("RAG_TOOL_PLAN", "create_programme_plan")
RAG_TOOL_REMOVE_COLLECTION_DOCUMENT = os.getenv(
    "RAG_TOOL_REMOVE_COLLECTION_DOCUMENT", "remove_collection_document"
)
# Cross-encoder scores are model-specific raw logits, not probabilities: a
# useful top-ranked passage can legitimately have a negative score. Zero is
# therefore the safe default meaning "ranking only, no absolute cutoff". A
# deployment may opt into a calibrated, non-zero cutoff for its exact model.
_RAG_MIN_SCORE_VALUE = float(os.getenv("RAG_MIN_SCORE", "0"))
RAG_MIN_SCORE: float | None = (
    None if _RAG_MIN_SCORE_VALUE == 0 else _RAG_MIN_SCORE_VALUE
)

# Their citation header, e.g.
#   "[1] Source: book.pdf | Page: 12 | Chunk: 4/5 | Score: 0.9812"
# The Page field is absent for non-paginated sources, so we read the fields by
# name rather than by position.
_HEADER = re.compile(r"^\[\d+\]\s*(?P<fields>.+)$", re.MULTILINE)
_QUOTED_PASSAGE = re.compile(
    r'<untrusted-data\s+name="retrieved-passage"\s+encoding="html-escaped">\s*'
    r"(?P<body>.*?)\s*</untrusted-data>",
    re.DOTALL,
)
_NO_HITS_PREFIXES = ("No relevant documents", "No documents found")
_FAILURE_PREFIXES = (
    "Error during retrieval:",
    "Error during grounded retrieval:",
    "REFUSED:",
)


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


# Retrieval during a LIVE lecture must fail fast — a student is waiting.
# Ingesting a whole textbook legitimately takes many minutes of embedding.
RAG_TIMEOUT_S = float(os.getenv("RAG_TIMEOUT_S", "15"))
# Measured: a 600-page textbook took their embedder ~29 minutes on this box,
# and their server kills the whole ingest if the client hangs up early.
RAG_INGEST_TIMEOUT_S = float(os.getenv("RAG_INGEST_TIMEOUT_S", "10800"))


async def _call_tool(tool: str, arguments: dict, timeout: float | None = None) -> str:
    if not RAG_MCP_URL:
        raise RagUnavailable("RAG_MCP_URL is not set — point it at the team's RAG MCP server")
    leash = timeout or RAG_TIMEOUT_S
    try:
        return await asyncio.wait_for(_call_tool_inner(tool, arguments, leash), timeout=leash)
    except asyncio.TimeoutError as exc:
        # The MCP client reconnect-loops forever against a dead server; the
        # student would wait minutes. Fail fast and let the lecture continue.
        raise RagUnavailable(f"RAG did not answer within {leash:.0f}s") from exc


async def _call_tool_inner(tool: str, arguments: dict, leash: float) -> str:

    # Imported lazily so the app runs before the RAG server is wired up.
    from mcp import ClientSession
    from mcp.client.streamable_http import streamablehttp_client

    # The SSE stream must be allowed to stay SILENT for the whole call: their
    # server says nothing while it embeds a book (~29 minutes for 600 pages),
    # and the default 5-minute sse_read_timeout hangs up in the middle — which
    # makes their server abort the whole ingest.
    async with streamablehttp_client(
        RAG_MCP_URL,
        headers=trace_headers(),
        timeout=leash,
        sse_read_timeout=leash,
    ) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool(tool, arguments)

    rendered = "\n".join(getattr(item, "text", "") for item in result.content).strip()
    if getattr(result, "isError", False):
        detail = rendered[:240] or "the MCP tool returned an error"
        raise RagUnavailable(f"RAG tool '{tool}' failed: {detail}")
    return rendered


def _fields_to_hit(fields: dict[str, str], content: str) -> dict:
    page = fields.get("page")
    try:
        score = float(fields.get("score", 0))
    except ValueError:
        score = 0.0
    return {
        "source": fields.get("source", ""),
        "page": int(page) if page and page.isdigit() else None,
        "score": score,
        "text": content.strip(),
        "chunk_id": fields.get("chunk", ""),
    }


def _parse_quoted_hits(formatted: str) -> list[dict]:
    """Decode the MCP's prompt-safe passage envelopes back into data.

    ``quote_untrusted_data`` HTML-escapes a JSON object. Treating that transport
    rendering as the old citation string caused every successful retrieval to
    parse as zero hits, which in turn produced a false "not covered" answer.
    """
    hits: list[dict] = []
    for match in _QUOTED_PASSAGE.finditer(formatted):
        try:
            payload = json.loads(unescape(match.group("body")))
        except (json.JSONDecodeError, TypeError):
            continue
        if not isinstance(payload, dict):
            continue
        citation = payload.get("citation")
        content = payload.get("content")
        if not isinstance(citation, str) or not isinstance(content, str):
            continue
        fields = _parse_header(citation)
        if fields and content.strip():
            hits.append(_fields_to_hit(fields, content))
    return hits


def _parse_grounded_json(formatted: str) -> list[dict] | None:
    """Accept the MCP's structured grounded contract when configured.

    Returning ``None`` means the payload was not that contract; returning an
    empty list means it was a valid, explicit grounded refusal.
    """
    try:
        payload = json.loads(formatted)
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, dict) or "grounded" not in payload:
        return None
    if payload.get("grounded") is not True:
        return []

    hits: list[dict] = []
    for passage in payload.get("passages") or []:
        if not isinstance(passage, dict):
            continue
        citation = passage.get("citation") or {}
        if not isinstance(citation, dict):
            continue
        content = passage.get("content")
        if not isinstance(content, str) or not content.strip():
            continue
        page = citation.get("page")
        chunk_index = citation.get("chunk_index")
        hits.append(
            {
                "source": str(
                    citation.get("source_filename")
                    or citation.get("book_title")
                    or ""
                ).strip(),
                "page": page if isinstance(page, int) and not isinstance(page, bool) else None,
                "score": float(passage.get("score") or 0.0),
                "text": content.strip(),
                "chunk_id": "" if chunk_index is None else str(chunk_index),
            }
        )
    return hits


def _is_explicit_no_hits(formatted: str) -> bool:
    stripped = formatted.strip()
    if any(stripped.startswith(prefix) for prefix in _NO_HITS_PREFIXES):
        return True
    try:
        structured = json.loads(stripped)
    except json.JSONDecodeError:
        return False
    return isinstance(structured, dict) and structured.get("grounded") is False


def parse_hits(formatted: str) -> list[dict]:
    """Turn their formatted string back into {page, text, score, source} records."""
    if not formatted or any(formatted.startswith(prefix) for prefix in _NO_HITS_PREFIXES):
        return []

    structured = _parse_grounded_json(formatted)
    if structured is not None:
        return structured

    quoted = _parse_quoted_hits(formatted)
    if quoted:
        return quoted

    hits: list[dict] = []
    for block in re.split(r"\n-{3,}\n", formatted):
        fields = _parse_header(block)
        if not fields:
            continue

        _, _, content = block.partition("Content:")
        hits.append(_fields_to_hit(fields, content.strip() or block.strip()))
    return hits


async def search_book(query: str, top_k: int = 5, user_id: str | None = None) -> list[dict]:
    """Retrieve cited passages for a student's question, from THEIR namespace.

    user_id is the app's tenant key (user.studentId). It scopes retrieval to
    that one student's book. Falls back to RAG_USER_ID only when a caller has
    not been threaded through yet (single-tenant legacy).
    """
    try:
        query = validate_input(query)
    except InputRejected as exc:
        raise ValueError(f"query rejected ({exc.code}): {exc}") from exc
    if not 1 <= top_k <= 20:
        raise ValueError("top_k must be between 1 and 20")
    formatted = await _call_tool(
        RAG_TOOL_SEARCH,
        {
            "query": query,
            "user_id": user_id or RAG_USER_ID,
            "limit": top_k,
            "use_reranking": True,
        },
    )
    if any(formatted.startswith(prefix) for prefix in _FAILURE_PREFIXES):
        raise RagUnavailable("RAG retrieval failed instead of returning passages")
    hits = parse_hits(formatted)
    if not hits and formatted.strip() and not _is_explicit_no_hits(formatted):
        # An MCP schema change or an operational error must never be presented
        # to the learner as evidence that their book lacks the answer.
        raise RagUnavailable("RAG returned an unrecognized retrieval response")
    if RAG_MIN_SCORE is None:
        return hits
    return [hit for hit in hits if hit["score"] >= RAG_MIN_SCORE]


async def ingest_file(absolute_path: str, user_id: str | None = None) -> str:
    """Hand a saved book to the RAG service, indexed under this student's namespace."""
    return await _call_tool(
        RAG_TOOL_INGEST,
        {"file_path": absolute_path, "user_id": user_id or RAG_USER_ID},
        timeout=RAG_INGEST_TIMEOUT_S,
    )


async def ingest_collection(
    absolute_paths: list[str], collection_id: str, user_id: str
) -> str:
    """Index books with the collection identity required by grounded planning."""
    return await _call_tool(
        RAG_TOOL_INGEST_COLLECTION,
        {
            "file_paths": absolute_paths,
            "collection_id": collection_id,
            "user_id": user_id,
        },
        timeout=RAG_INGEST_TIMEOUT_S,
    )


async def remove_collection_document(
    user_id: str,
    collection_id: str,
    source_filename: str,
) -> str:
    """Remove one learner-owned collection source from the vector index."""
    return await _call_tool(
        RAG_TOOL_REMOVE_COLLECTION_DOCUMENT,
        {
            "user_id": user_id,
            "collection_id": collection_id,
            "source_filename": source_filename,
        },
        timeout=300,
    )


async def create_programme_plan(
    programme_title: str,
    collection_id: str,
    user_id: str,
    seed_queries: list[str],
) -> str:
    """Ask the Agent service to build a grounded plan for one collection."""
    return await _call_tool(
        RAG_TOOL_PLAN,
        {
            "programme_title": programme_title,
            "collection_id": collection_id,
            "user_id": user_id,
            "seed_queries": seed_queries,
        },
        timeout=RAG_INGEST_TIMEOUT_S,
    )
