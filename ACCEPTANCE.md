# MVP-1 acceptance record

Verified on 2026-07-14 against the running app (Next.js dev on :3100, Postgres on :5433).

## Verified working

| # | Check | Result |
|---|---|---|
| 1 | Next.js app builds clean (13 routes, TypeScript strict) | PASS — `npm run build` |
| 2 | **MUI purity**: no `sx=`, no `style=`, no `styled(`, no `.css`, no `createTheme` | PASS — 0 hits in `UnivAI-app/app/` and `UnivAI-app/lib/` |
| 3 | Virtual clock: set / advance / jump-to-next-lecture / reset, persisted in Postgres | PASS |
| 4 | Clock is shared by the app and the Python services (one `clock_state` row) | PASS |
| 5 | Schedule seeds itself: 4 weekly lectures from the premade `lectures/week-N/` | PASS |
| 6 | Lecture state (upcoming / live / done) follows the **virtual** clock | PASS |
| 7 | Join 7 simulated minutes late → recorded `late, 7 min` (grace = 5 min) | PASS |
| 8 | Skip a lecture, jump past +24 h → recorded `absent` | PASS |
| 9 | Jump exactly to a start time and join → recorded `on_time` | PASS |
| 10 | Dashboard totals: on-time / late / absent counts, total + average lateness | PASS |
| 11 | **LLM failover**: primary fails (bad key) → retries once → falls back → logs which model served it | PASS — verified with a broken Gemini key falling back to a local model |
| 12 | Upload: rejects non-PDFs by magic bytes, size cap, replace-book confirm dialog | PASS |
| 13 | Token route refuses to admit anyone when LiveKit is unconfigured (no join → no attendance) | PASS |

## Not yet verified — needs credentials or hardware

| Check | Blocked on |
|---|---|
| Real LiveKit room join, audio in/out | `LIVEKIT_*` keys (free tier). The token path is verified; the room connection is not. |
| Lecturer TTS streaming + slide-flip sync in a real room | LiveKit keys + first Coqui XTTS model download |
| **TTS latency gate** (XTTS too slow on CPU → Piper) | Must be run on the demo machine — that is the whole point of the gate |
| Barge-in: VAD → STT → answer → resume | LiveKit keys + a microphone |
| RAG-cited answers, and "not in the book" refusal | `RAG_INGEST_URL` + `RAG_MCP_COMMAND` — the team's existing RAG service |
| Slidev decks rendering in the iframe | `node scripts/build-slides.mjs` (needs network for the Slidev CLI) |

## To finish the demo

1. Create a LiveKit Cloud project (free) → fill `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `NEXT_PUBLIC_LIVEKIT_URL`.
2. Point `RAG_INGEST_URL` and `RAG_MCP_COMMAND` at the team's RAG service. If its MCP tools are not named `search_book` / `get_pages`, set `RAG_TOOL_SEARCH` / `RAG_TOOL_PAGES`.
3. `node scripts/build-slides.mjs` to build the four decks.
4. `pip install -r services/requirements.txt`, then run `python services/voice-agent/worker.py dev`. Watch the startup line: it prints the measured time-to-first-audio and whether the gate sent it to Piper.
5. Replace the placeholder narration in `lectures/week-N/script.json` with the real premade lecture text.
