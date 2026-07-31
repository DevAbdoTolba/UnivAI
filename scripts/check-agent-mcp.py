"""Call Agent server_info through the real MCP streamable-HTTP client."""

from __future__ import annotations

import asyncio

from mcp import ClientSession
from mcp.client.streamable_http import streamable_http_client


async def main() -> None:
    async with streamable_http_client("http://127.0.0.1:8000/mcp") as streams:
        async with ClientSession(streams[0], streams[1]) as session:
            await session.initialize()
            result = await session.call_tool("server_info", {})
            text = "\n".join(
                getattr(block, "text", "") for block in result.content
            )
            if "RAG MCP server is running" not in text:
                raise RuntimeError(f"unexpected server_info response: {text}")
            print("PASS Agent MCP server_info")


asyncio.run(main())
