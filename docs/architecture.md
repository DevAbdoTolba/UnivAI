# Architecture — the moving parts

Six processes, three containers, one virtual clock.

## The map

| Piece | Where | Port | Job |
|---|---|---|---|
| **UnivAI-app** (Next.js 16) | `UnivAI-app/` | **3100** | every page + API route; owns Postgres |
| **voice worker** (Mouth + ears) | `UnivAI-live/` | — | the Lecturer: joins LiveKit rooms, synthesizes database-backed narration, answers raised hands, and runs sections |
| **course generator** (Brain) | `UnivAI-Agent/generation/` | — | book PDF → database-backed plans, slides, narration, quizzes, and section packs (spawned by the app, watch `logs/lecture-gen.log`) |
| **RAG server** (Brain) | `UnivAI-Agent/` | 8000 | indexes the book, answers retrieval queries over MCP |
| **exam system** (Judge) | `UnivAI-exam_system/` | 3200 | runs quizzes + midterm with proctoring, webhooks results back |
| Postgres | container `univai-db` | 5433 | books, lectures, attendance, grades, qa_log, **clock_state** |
| Qdrant | container `univai-qdrant` | 6333 | the RAG's vectors |
| Mongo | container `univai-mongo` | 27018 (host) / 27017 (container) | the exam system's world |
| Ollama | host service | 11434 | the one local LLM (`gemma3:1b` — light and fast; cloud providers plug in via `.env`) |

## How data flows

```
 /upload (PDF)
    │  1. clear old course (RAG index, Postgres, exam world)
    │  2. RAG ingests the book          → Qdrant
    │  3. lecture_gen.py stores         → Postgres lecture_artifacts + section_packs
    │  4. Postgres generates UUIDs      → public lecture and section identifiers
    │  5. voice worker synthesizes      → narration from the stored script on demand
    ▼
 /schedule ── /lecture/[id] ──▶ LiveKit room ◀── voice worker
    │                              │  raise hand → STT → RAG → LLM → spoken answer
    ▼                              ▼
 /exams ──▶ exam system (:3200) — draws questions from Mongo question_banks
    ▲              │  (synced from PostgreSQL quiz payloads on every exam start)
    │              ▼
    └── webhook: score + proctoring report → grades table → /dashboard, /exams, /admin
```

## MVP-2 programme planning boundary

A learner's one-or-many uploaded books form a versioned SourceCollection.
Ingestion completes per document before Core accepts a schema-validated,
source-grounded ProgrammePlan. Plan edits create new versions; approval names
the exact latest version and makes it immutable. A tracked generation job then
moves through `queued -> ingesting -> planning -> awaiting_approval ->
generating -> ready`. See `docs/contracts/final-mvp-contracts.md` for the
versioned fields, API boundaries, fixtures, idempotency and error contract.

## Rules the code lives by

- **The virtual clock is law.** Nothing reads the wall clock except
  `UnivAI-app/lib/clock.ts` and `services/common/clock.py`. Everything else asks the
  ClockService (wall clock + `clock_state.offset_ms` in Postgres). That's why
  `/admin` can time-travel and attendance/exam windows follow.
- **The 90/10 quiz rule.** Every generated question is tagged `lecture` or
  `self_study`. The exam system's sampler fills ≥90% of any paper from
  lecture-taught questions; self-study is capped at 10%. Questions cover
  topics the lecturer explained — never verbatim quotes of the narration.
- **Generated learning artifacts live in PostgreSQL.** Plans, lecture scripts,
  slides, quizzes, and section packs are stored as JSONB and exposed through
  database-generated UUIDs. Slidev compiles a disposable render cache from the
  database deck, served only through the authenticated presentation endpoint;
  the worker synthesizes narration on demand.
- **LLM failover.** Every LLM call goes through `services/common/llm.py`:
  try `LLM_PRIMARY`, retry once, then `LLM_FALLBACK`. Generation calls get
  600s and JSON repair + retries; live Q&A gets 30s and a hard token cap.
- **RAG is consumed, never built here.** The `UnivAI-Agent` submodule is the
  team's separate service; this repo only calls its MCP tools
  (`retrieve_context`, `ingest_file`).
- **Results come home.** The exam system never shows a score at submit time —
  results + proctoring reports live in the app (`/exams`, `/dashboard`, `/admin`).
