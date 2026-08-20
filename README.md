# UnivAI — "Jamieh" 🎓

Standalone development and full integration use different explicit commands.
See [docs/integration-development.md](docs/integration-development.md) for
clean-clone setup, deterministic seed/smoke commands, provider requirements,
production guards, and the required Git submodule pointer workflow.

**Upload a textbook. Get a university.**

One PDF goes in. Out comes a living four-week semester:

- **Voiced lectures** on a weekly schedule — slides + a lecturer that actually speaks
- **Raise your hand** mid-lecture, ask with your voice, get an answer *from the book* with page citations
- **Quizzes born from the lectures** — 90% of every paper covers what the lecturer taught, 10% pushes you into the book
- **A proctored midterm** with cheating reports the admin can read
- **A virtual clock** — demo a whole month of university in five minutes

## Quick start

```bash
make install # system tools
make setup   # project dependencies and .env
make models  # voice files and local LLM
make up      # Postgres + Qdrant + Mongo containers
make dev     # check prerequisites, then start the application services
```

Then open **http://localhost:3100** → upload a book on `/upload` → drive time from `/admin`.

No `make` on Windows? The same target order works through `./run.ps1`.

## How it flows

```
book.pdf ──▶ RAG (index it) ──▶ course generator (LLM) ──▶ PostgreSQL stores
             plans + slides + narration + quizzes + sections ──▶ live LiveKit
             lecture/section rooms ──▶ exam system ──▶ grades +
             proctoring reports, back on your dashboard
```

## Read more

| Doc | What's inside |
|---|---|
| [docs/running.md](docs/running.md) | **How to run it** — every service by hand, step by step, then the one-command way |
| [docs/architecture.md](docs/architecture.md) | The moving parts, their ports, and how data flows between them |
| [Combined logical ERD](UnivAI%20Combined%20Logical%20ERD.md) | One Mermaid ERD covering PostgreSQL, MongoDB, and the reference-contract model |
| [docs/admin.md](docs/admin.md) | The SUDO panel: virtual clock, learner records, controls, and semester recovery |
| [docs/final-exam-recovery-and-retake.md](docs/final-exam-recovery-and-retake.md) | Final-session recovery, two-form retakes, deadlines, grade finalization, and operations |

## Repo layout

```
UnivAI-app/          the Face (submodule): Next.js 16 — all UI + API routes + integration
services/             shared Python plumbing (clock, db, LLM adapter, RAG client) + rag CLIs
lectures/             legacy fixture boundary only; integrated content is in PostgreSQL
UnivAI-Agent/         the Brain (submodule): RAG service + course generation
UnivAI-live/          the Mouth + ears (submodule): LiveKit rooms, TTS, STT, the live class
UnivAI-exam_system/   the Judge (submodule): exams, proctoring, records — port 3200
infra/                docker-compose (Postgres, Qdrant, LiveKit, Mongo) + schema.sql
logs/                 every service and build log lands here
```

> **This repo does not implement RAG.** The team's RAG service lives in the
> `UnivAI-Agent` submodule and is only *called* from here, over MCP.
