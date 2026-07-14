# UnivAI — MVP-1 ("One Book, One Month")

Upload one textbook, get a four-week semester: weekly slide-and-voice lectures you
can interrupt to ask questions, attendance tracking, and a dashboard.

**This repo does not implement RAG.** The team's RAG service already exists and lives
elsewhere; here it is only *consumed* (see [RAG integration](#rag-integration)).

## Layout

```
app/                     Next.js 16 (App Router, TypeScript) — all UI + API routes.
                         Frontend is pure MUI: no sx, no styled(), no CSS files.
services/
  common/                shared clock, db, LLM adapter (primary + fallback), RAG client
  voice-agent/           the live lecture: Lecturer (TTS) + Listener (STT) agents
infra/                   docker-compose (Postgres) + schema.sql
lectures/week-N/         PREMADE content: slides.md (Slidev) + script.json (narration)
scripts/build-slides.mjs builds the decks to app/public/slides/week-N/
```

## Run it

```bash
cp .env.example .env          # then fill in the values below
docker compose -f infra/docker-compose.yml up -d
docker exec -i univai-db psql -U univai -d univai < infra/schema.sql

node scripts/build-slides.mjs # build the Slidev decks once

cd app && npm install && npm run dev        # http://localhost:3000

python -m venv .venv                        # the voice worker
.venv/Scripts/pip install -r services/requirements.txt
.venv/Scripts/python services/voice-agent/worker.py dev
```

Postgres is published on **5433**, not 5432, because 5432 is commonly already taken.

## Configuration (`.env`)

| Variable | What it does |
|---|---|
| `LLM_PRIMARY`, `LLM_FALLBACK` | `provider:model` — `gemini:…`, `openai:…` or `ollama:…`. Any error on the primary (auth, 429, 5xx, timeout, bad response) retries once, then switches to the fallback. Every call logs which model served it. |
| `GEMINI_API_KEY` / `OPENAI_API_KEY` / `OLLAMA_BASE_URL` | credentials for whichever providers you name above |
| `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, `NEXT_PUBLIC_LIVEKIT_URL` | LiveKit Cloud (free tier) |
| `RAG_INGEST_URL` | where `/upload` forwards the book for indexing |
| `RAG_MCP_COMMAND` | the RAG MCP server the live Q&A calls, e.g. `python ../their-rag/server.py` |
| `TTS_ENGINE`, `STT_MODEL_SIZE` | `coqui` (XTTS-v2) or `piper`; whisper model size |
| `DATABASE_URL` | Postgres |

## The pages

| Route | What it does |
|---|---|
| `/upload` | Upload the one book (PDF). Validates it, then hands it to the RAG service. |
| `/schedule` | The four lectures. Click one for details and your attendance for it. |
| `/lecture/[id]` | The live lecture: LiveKit room, Slidev slides, **mute button**, agent status. |
| `/dashboard` | Attendance (on time / late + minutes / absent) and grades. |
| `/admin` | **SUDO, no auth.** Move the virtual clock, and see every row of your data. |

## The live lecture

One worker process joins the room as two agents:

- **Lecturer** — speaks the premade `script.json` through local streaming TTS and sends
  slide-sync messages that flip the Slidev iframe.
- **Listener** — subscribes to the student's mic, runs VAD, and on ≥300 ms of speech
  **interrupts the Lecturer mid-sentence**.

Then: the question is transcribed (faster-whisper) → retrieved from the book (the team's
RAG, over MCP) → answered by the small LLM in ≤3 sentences **with page citations** →
spoken back → the lecture resumes from the interrupted sentence.

If RAG returns nothing, the agent says the book does not cover it. It never invents an
answer. Every question, answer, citation and the model used lands in `qa_log`.

**Mute** stops the mic publishing entirely, so VAD cannot fire and the lecture is never
interrupted.

**TTS latency gate:** XTTS-v2 on CPU can be too slow for real time. The worker measures
time-to-first-audio at startup; if it exceeds `TTS_LATENCY_GATE_S` (default 2s) it reports
the measurement and falls back to Piper. It never swaps silently.

## The virtual clock (why attendance is demoable)

Nothing in this codebase reads the wall clock except one function in `app/lib/clock.ts`
and one in `services/common/clock.py`. Everything else — lecture state, attendance
stamping, "absent" — asks the ClockService, which is wall clock + an offset stored in
Postgres.

So `/admin` can jump the world forward: land 7 minutes after a lecture starts and join,
and the dashboard records **late, 7 min** (grace window is 5 minutes). Skip a lecture and
jump a week; it becomes **absent**.

## RAG integration

Set `RAG_INGEST_URL` (upload path) and `RAG_MCP_COMMAND` (Q&A path) in `.env`. If the
tool names on the RAG side are not `search_book` / `get_pages`, change `RAG_TOOL_SEARCH`
and `RAG_TOOL_PAGES` — that is the only place this repo cares.

## Not in MVP-1

Attendance **enforcement** (penalties, dismissal, certificates), the TA chatbot, the CV
track, labs and sections, and quiz/exam *generation* — grades are stubbed until the
`UnivAI-exam_system` submodule is wired in (`TODO(exam-system)` marks the seam).
