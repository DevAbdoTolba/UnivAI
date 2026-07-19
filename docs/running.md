# Running UnivAI

Two ways to do it: [by hand, service by service](#run-it-by-hand-service-by-service)
(so you understand what exists), or [the one-command way](#the-one-command-way).

## Bootstrap a brand-new machine (one time)

```bash
make install   # installs missing system tools: node, python, uv, docker, ollama
make setup     # project deps: npm installs, python venv, submodules, RAG uv sync, .env
make models    # downloads the voice models + the one local LLM (gemma3:1b, ~815 MB)
```

(`./run.ps1 install` / `setup` / `models` on Windows without `make`.)

What that covers — and the two honest caveats:

| Piece | Who gets it |
|---|---|
| Node, Python, uv, Docker, Ollama | `make install` (winget on Windows, apt + official scripts on Linux) |
| npm deps, venv, submodules, `.env` | `make setup` — the `.env` defaults run **fully local, zero keys** |
| Kokoro + Piper voice files, `gemma3:1b` | `make models` (idempotent — skips what exists) |
| Whisper (STT) | downloads itself on the worker's first run |

Caveats: Docker Desktop and Ollama may need **one manual first launch** after
installing, and a fresh shell so PATH updates. The local LLM is ONE light
model — no fallback; plug a cloud provider (`groq:` / `gemini:` / `openai:` /
`grok:` / `bedrock:`) into `LLM_PRIMARY` for heavier course generation.

## Run it by hand, service by service

Order matters: containers first, then the brains, then the faces.

### 0. Ollama — the local LLM (`:11434`)

Usually already running as a background service. Check with `ollama list`.

### 1. The containers — Postgres, Qdrant, Mongo

```bash
docker compose -f infra/docker-compose.yml up -d
```

| Container | Port | Holds |
|---|---|---|
| `univai-db` (Postgres) | **5433** | app data + the virtual clock |
| `univai-qdrant` | 6333 | the RAG's vectors (the book's index) |
| `univai-mongo` | 27017 | the exam system's world |

First time only, apply the schema: `make schema` (or `./run.ps1 schema`).

### 2. The team's RAG server (`:8000`)

```bash
cd UnivAI-Agent
uv run python mcp_server.py
```

Ready when the MCP banner prints. The app and the voice worker talk to it
at `http://localhost:8000/mcp`.

### 3. The exam system (`:3200`)

```bash
cd UnivAI-exam_system
npm run dev
```

Needs Mongo up. Serves the exam-taking UI and webhooks every result +
proctoring report back to the app.

### 4. The app (`:3100`)

```bash
cd UnivAI-app
npx next dev -p 3100
```

The whole UI: `/upload`, `/schedule`, `/lecture/[id]`, `/exams`,
`/dashboard`, `/admin`. **Port 3100 matters** — the exam system's
"back to UnivAI" buttons point at it.

### 5. The voice worker — the lecturer itself (UnivAI-live, the Mouth)

```bash
.venv/Scripts/python.exe UnivAI-live/worker.py dev
```

Registers against the LiveKit server from `.env` (the local docker one on
`:7880` by default) and waits. When a student
opens a lecture it joins the room, plays the pre-recorded voice, and handles
raise-hand questions. **The first join after a start takes ~25s** (it loads
Whisper) — the room honestly shows "preparing" until then.

### 6. Slides (only after the course changed)

```bash
node scripts/build-slides.mjs      # or: make slides
```

Builds the Slidev decks into `UnivAI-app/public/slides/`. Course generation runs
this itself — you only need it if you hand-edited `lectures/week-N/slides.md`.

## The one-command way

```bash
make up      # containers + schema
make dev     # RAG + app + worker + exams, each in its own window
```

Windows without `make`: `./run.ps1 up ; ./run.ps1 dev` — same names, same behaviour.

## Is everything up?

```bash
make status      # containers, app, exams, RAG, and the virtual clock
```

## Where things land

| Place | What |
|---|---|
| `logs/` | **every** log: `lecture-gen.log` while a course builds, `worker-out.log` for the lecturer, … |
| `lectures/week-N/` | the generated course: `slides.md`, `script.json`, `quiz.json`, `audio/` |
| `uploads/` | the book PDF you uploaded |

## Notes nobody tells you

- **A fresh system is empty on purpose.** First act: upload a PDF at `/upload`.
  Indexing a 600-page book ≈ 12 min; generating the course on the small local model ≈ 25 min
  (size M). Progress shows live on `/upload` and `/admin`.
- **Time is virtual.** Lectures schedule themselves starting "tomorrow 10:00" —
  drive the clock from `/admin` ("jump to next lecture start") instead of waiting.
- **No sound in a lecture?** The voice worker isn't running, or the LiveKit keys
  are missing.
- **Quiz/midterm buttons dead?** The exam system (`:3200`) or Mongo isn't up.
- **Ollama must be running before generating a course** — the generator fails
  fast without it and `books.status` turns `failed` with the reason.
