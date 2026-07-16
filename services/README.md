# services/ — the campus plumbing (Python)

The shared bits every cave leans on. The heavy lifting lives in the caves
themselves: generation in `UnivAI-Agent/generation/` (Brain), the live voice
class in `UnivAI-live/` (Mouth + ears).

| Folder | What it is |
|---|---|
| `common/` | shared plumbing: virtual clock, Postgres access, LLM adapter (primary → fallback), RAG MCP client, sentence splitting. Imported by the caves — never run directly. |
| `rag-tools/` | small CLIs the app shells out to: `rag_ingest.py` (index a book into the Brain), `rag_admin.py clear` (wipe before a book replacement). One JSON line out. |

`requirements.txt` — the repo `.venv` that runs everything Python here and in
the caves (`make setup` builds it).

Logs land in `logs/` at the repo root.
