# Running UnivAI

Two ways to do it: [by hand, service by service](#run-it-by-hand-service-by-service)
(so you understand what exists), or [the one-command way](#the-one-command-way).

## Before anything — what must be on your machine

| Thing | Why | Check |
|---|---|---|
| Docker Desktop | Postgres, Qdrant and Mongo run as containers | `docker ps` works |
| Node.js 20+ | the app, the exam system, the slide builder | `node -v` |
| Python 3.12 + `uv` | voice worker + course generator; the RAG submodule uses uv | `python --version`, `uv --version` |
| Ollama + 2 models | the local LLM that writes lectures and answers questions | `ollama pull llama3.2:3b` and `ollama pull qwen2.5:7b` |
| Voice models | gitignored binaries, download once into `models/` | see below |
| `.env` | copy `.env.example`; **LIVEKIT_\*** keys are the only must-fill | file exists |

**Voice models (one-time download):**

- `models/kokoro/kokoro-v1.0.onnx` + `models/kokoro/voices-v1.0.bin`
  — from the [kokoro-onnx releases](https://github.com/thewh1teagle/kokoro-onnx/releases)
- `models/piper/en_US-lessac-medium.onnx` (+ its `.json`)
  — from [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices)

Then install everything once:

```bash
make setup        # or: ./run.ps1 setup
```

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
cd app
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

Builds the Slidev decks into `app/public/slides/`. Course generation runs
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
  Indexing a 600-page book ≈ 12 min; generating the course on the local 3B ≈ 25 min
  (size M). Progress shows live on `/upload` and `/admin`.
- **Time is virtual.** Lectures schedule themselves starting "tomorrow 10:00" —
  drive the clock from `/admin` ("jump to next lecture start") instead of waiting.
- **No sound in a lecture?** The voice worker isn't running, or the LiveKit keys
  are missing.
- **Quiz/midterm buttons dead?** The exam system (`:3200`) or Mongo isn't up.
- **Ollama must be running before generating a course** — the generator fails
  fast without it and `books.status` turns `failed` with the reason.
