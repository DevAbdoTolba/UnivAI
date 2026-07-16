# services/ — the Python side

Each folder is one concern. All of them read the single root `.env` and share
the plumbing in `common/`.

| Folder | What it is | Entry point |
|---|---|---|
| `common/` | shared plumbing: virtual clock, Postgres access, LLM adapter (primary → fallback), RAG MCP client, sentence splitting | imported, never run |
| `course-builder/` | book PDF → the course: `lecture_gen.py` writes slides + narration + quizzes per week, `prerender_audio.py` records the lecturer's voice to disk | spawned by the app; runnable by hand |
| `voice-agent/` | the live Lecturer: joins the LiveKit room, plays the pre-recorded lecture, listens for raised hands, answers from the book | `python services/voice-agent/worker.py dev` |
| `rag-tools/` | small CLIs the app shells out to for talking to the team's RAG: `rag_ingest.py` (index a book), `rag_admin.py clear` (wipe before a replacement) | one JSON line out |

`requirements.txt` — everything here runs from the repo's `.venv`
(`make setup` builds it).

Logs land in `logs/` at the repo root — `lecture-gen.log` for course builds,
`worker-out.log` for the Lecturer.
