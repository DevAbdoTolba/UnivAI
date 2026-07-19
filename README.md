# UnivAI — "Jamieh" 🎓

**Upload a textbook. Get a university.**

One PDF goes in. Out comes a living four-week semester:

- **Voiced lectures** on a weekly schedule — slides + a lecturer that actually speaks
- **Raise your hand** mid-lecture, ask with your voice, get an answer *from the book* with page citations
- **Quizzes born from the lectures** — 90% of every paper covers what the lecturer taught, 10% pushes you into the book
- **A proctored midterm** with cheating reports the admin can read
- **A virtual clock** — demo a whole month of university in five minutes

## Quick start

```bash
make setup   # one time: installs everything
make up      # Postgres + Qdrant + Mongo containers
make dev     # RAG + app + exams + voice worker, each in its own window
```

Then open **http://localhost:3100** → upload a book on `/upload` → drive time from `/admin`.

No `make` on Windows? Same targets: `./run.ps1 setup ; ./run.ps1 up ; ./run.ps1 dev`

## How it flows

```
book.pdf ──▶ RAG (index it) ──▶ course generator (LLM) ──▶ 4 weeks of
             slides + narration + quizzes ──▶ pre-recorded lecturer voice
             ──▶ live LiveKit lecture room ──▶ exam system ──▶ grades +
             proctoring reports, back on your dashboard
```

## Read more

| Doc | What's inside |
|---|---|
| [docs/running.md](docs/running.md) | **How to run it** — every service by hand, step by step, then the one-command way |
| [docs/architecture.md](docs/architecture.md) | The moving parts, their ports, and how data flows between them |
| [docs/admin.md](docs/admin.md) | The SUDO panel: virtual clock, course-size dial, restart semester |

## Repo layout

```
UnivAI-app/          the Face (submodule): Next.js 16 — all UI + API routes + integration
services/             shared Python plumbing (clock, db, LLM adapter, RAG client) + rag CLIs
lectures/week-N/      GENERATED from your book: slides.md, script.json, quiz.json
UnivAI-Agent/         the Brain (submodule): RAG service + course generation
UnivAI-live/          the Mouth + ears (submodule): LiveKit rooms, TTS, STT, the live class
UnivAI-exam_system/   the Judge (submodule): exams, proctoring, records — port 3200
infra/                docker-compose (Postgres, Qdrant, LiveKit, Mongo) + schema.sql
logs/                 every service and build log lands here
```

> **This repo does not implement RAG.** The team's RAG service lives in the
> `UnivAI-Agent` submodule and is only *called* from here, over MCP.
