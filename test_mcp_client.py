import sys
import asyncio
from pathlib import Path
ROOT = Path(".").resolve()
sys.path.insert(0, str(ROOT / "services"))

from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

async def main():
    print("Starting client...")
    async with streamablehttp_client(
        "http://localhost:8000/mcp",
        timeout=15,
        sse_read_timeout=15,
    ) as (read, write, _):
        print("Connected!")
        async with ClientSession(read, write) as session:
            print("Session init...")
            await session.initialize()
            print("Initialized!")

asyncio.run(main())
