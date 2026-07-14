"""Client for the team's EXISTING RAG service. This app does NOT implement RAG.

The RAG system (ingestion, chunking, embeddings, vector store, hybrid retrieval,
citations) is already built and lives outside this repo. Here we only *consume*
it, over MCP, through the two tools the live lecture needs:

    search_book(query, top_k) -> [{text, page, score}, ...]
    get_pages(from_page, to_page) -> [{page, text}, ...]

Point RAG_MCP_COMMAND at the team's MCP server in .env, e.g.
    RAG_MCP_COMMAND=python ../their-rag/server.py
    RAG_MCP_COMMAND=npx -y @univai/rag-mcp

If the tool names differ on their side, change TOOL_SEARCH / TOOL_PAGES only —
nothing else in this repo touches RAG.
"""

from __future__ import annotations

import os
import shlex
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

RAG_MCP_COMMAND = os.getenv("RAG_MCP_COMMAND", "").strip()
TOOL_SEARCH = os.getenv("RAG_TOOL_SEARCH", "search_book")
TOOL_PAGES = os.getenv("RAG_TOOL_PAGES", "get_pages")


class RagUnavailable(RuntimeError):
    """The RAG service is not configured or not reachable."""


async def _call_tool(tool: str, arguments: dict) -> list[dict]:
    if not RAG_MCP_COMMAND:
        raise RagUnavailable(
            "RAG_MCP_COMMAND is not set in .env — point it at the team's RAG MCP server"
        )

    # Imported lazily so the app runs even before the RAG server is wired up.
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client

    parts = shlex.split(RAG_MCP_COMMAND)
    params = StdioServerParameters(command=parts[0], args=parts[1:])

    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool(tool, arguments)

    hits: list[dict] = []
    for item in result.content:
        text = getattr(item, "text", None)
        if not text:
            continue
        import json

        try:
            payload = json.loads(text)
        except json.JSONDecodeError:
            hits.append({"text": text, "page": None})
            continue
        if isinstance(payload, list):
            hits.extend(payload)
        elif isinstance(payload, dict):
            hits.append(payload)
    return hits


async def search_book(query: str, top_k: int = 5) -> list[dict]:
    """Retrieve cited passages for a student question. Empty list = not in the book."""
    return await _call_tool(TOOL_SEARCH, {"query": query, "top_k": top_k})


async def get_pages(from_page: int, to_page: int) -> list[dict]:
    return await _call_tool(TOOL_PAGES, {"from_page": from_page, "to_page": to_page})
