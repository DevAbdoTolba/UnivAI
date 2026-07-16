# Architecture — the moving parts

Six processes, three containers, one virtual clock.

## The map

| Piece | Where | Port | Job |
|---|---|---|---|
| **app** (Next.js 16) | `app/` | **3100** | every page + API route; owns Postgres |
| **voice worker** | `services/voice-agent/` | — | the Lecturer: joins LiveKit rooms, plays the pre-recorded voice, answers raised hands |
| **course generator** | `services/course-builder/` | — | book PDF → 4 weeks of slides + narration + quizzes (spawned by the app, watch `logs/lecture-gen.log`) |
| **RAG server** (team's, submodule) | `UnivAI-Agent/` | 8000 | indexes the book, answers retrieval queries over MCP |
| **exam system** (team's, submodule) | `UnivAI-exam_system/` | 3200 | runs quizzes + midterm with proctoring, webhooks results back |
| Postgres | container `univai-db` | 5433 | books, lectures, attendance, grades, qa_log, **clock_state** |
| Qdrant | container `univai-qdrant` | 6333 | the RAG's vectors |
| Mongo | container `univai-mongo` | 27017 | the exam system's world |
| Ollama | host service | 11434 | the local LLM (`llama3.2:3b`, fallback `qwen2.5:7b`) |

## How data flows

```
 /upload (PDF)
    │  1. clear old course (RAG index, Postgres, exam world)
    │  2. RAG ingests the book          → Qdrant
    │  3. lecture_gen.py writes         → lectures/week-N/{slides.md, script.json, quiz.json}
    │  4. prerender_audio.py records    → lectures/week-N/audio/*.npy   (the lecturer's voice)
    │  5. build-slides.mjs builds decks → app/public/slides/week-N/
    ▼
 /schedule ── /lecture/[id] ──▶ LiveKit room ◀── voice worker
    │                              │  raise hand → STT → RAG → LLM → spoken answer
    ▼                              ▼
 /exams ──▶ exam system (:3200) — draws questions from Mongo question_banks
    ▲              │  (synced from quiz.json on every exam start)
    │              ▼
    └── webhook: score + proctoring report → grades table → /dashboard, /exams, /admin
```

## Rules the code lives by

- **The virtual clock is law.** Nothing reads the wall clock except
  `app/lib/clock.ts` and `services/common/clock.py`. Everything else asks the
  ClockService (wall clock + `clock_state.offset_ms` in Postgres). That's why
  `/admin` can time-travel and attendance/exam windows follow.
- **The 90/10 quiz rule.** Every generated question is tagged `lecture` or
  `self_study`. The exam system's sampler fills ≥90% of any paper from
  lecture-taught questions; self-study is capped at 10%. Questions cover
  topics the lecturer explained — never verbatim quotes of the narration.
- **The lecture voice is pre-recorded.** `prerender_audio.py` renders every
  script sentence to disk (Kokoro voice); lectures never wait on a TTS model.
  Only live Q&A answers are synthesized on the fly (Piper — ~10x realtime).
- **LLM failover.** Every LLM call goes through `services/common/llm.py`:
  try `LLM_PRIMARY`, retry once, then `LLM_FALLBACK`. Generation calls get
  600s and JSON repair + retries; live Q&A gets 30s and a hard token cap.
- **RAG is consumed, never built here.** The `UnivAI-Agent` submodule is the
  team's separate service; this repo only calls its MCP tools
  (`retrieve_context`, `ingest_file`).
- **Results come home.** The exam system never shows a score at submit time —
  results + proctoring reports live in the app (`/exams`, `/dashboard`, `/admin`).
