-- UnivAI MVP-1 schema. Idempotent: safe to re-run.
-- NOTE: RAG owns its own storage (chunks, embeddings, vector index) in the
-- team's existing RAG service. This app never stores or indexes book text.

-- The virtual clock. Exactly one row (id = 1). Nothing else in the system
-- may read the wall clock; see ClockService (app/lib/clock.ts, services/common/clock.py).
CREATE TABLE IF NOT EXISTS clock_state (
  id         SMALLINT PRIMARY KEY DEFAULT 1,
  offset_ms  BIGINT   NOT NULL DEFAULT 0,
  CONSTRAINT clock_singleton CHECK (id = 1)
);
INSERT INTO clock_state (id, offset_ms) VALUES (1, 0) ON CONFLICT (id) DO NOTHING;

-- MVP-1 has exactly one book. We keep only a pointer to it; the RAG service
-- holds the actual content.
CREATE TABLE IF NOT EXISTS books (
  id          SERIAL PRIMARY KEY,
  filename    TEXT NOT NULL,
  title       TEXT,
  pages       INTEGER NOT NULL DEFAULT 0,
  status      TEXT NOT NULL DEFAULT 'pending',   -- pending | ingesting | ready | failed
  error       TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL               -- virtual time
);

CREATE TABLE IF NOT EXISTS lectures (
  id         SERIAL PRIMARY KEY,
  book_id    INTEGER REFERENCES books(id) ON DELETE CASCADE,
  week       INTEGER NOT NULL,
  title      TEXT NOT NULL,
  starts_at  TIMESTAMPTZ NOT NULL,                -- virtual time
  status     TEXT NOT NULL DEFAULT 'ready',
  UNIQUE (week)
);

-- Attendance: TRACKING ONLY in MVP-1. No penalties, no enforcement.
-- 'absent' is never stored: it is derived at read time from the virtual clock.
CREATE TABLE IF NOT EXISTS attendance (
  id           SERIAL PRIMARY KEY,
  lecture_id   INTEGER NOT NULL REFERENCES lectures(id) ON DELETE CASCADE,
  joined_at    TIMESTAMPTZ NOT NULL,              -- virtual time
  status       TEXT NOT NULL,                     -- on_time | late
  late_minutes INTEGER NOT NULL DEFAULT 0,
  UNIQUE (lecture_id)
);

-- TODO(exam-system): stubbed in MVP-1. Integrating the UnivAI-exam_system
-- submodule (Ahmed Samir's APIs) is a separate later task.
CREATE TABLE IF NOT EXISTS grades (
  id        SERIAL PRIMARY KEY,
  kind      TEXT NOT NULL,                        -- quiz | midterm
  week      INTEGER,                              -- NULL for midterm
  score     NUMERIC(5,2) NOT NULL,
  max_score NUMERIC(5,2) NOT NULL DEFAULT 100,
  feedback  TEXT,
  taken_at  TIMESTAMPTZ NOT NULL                  -- virtual time
);

-- Questions asked during a live lecture, answered by the tiny LLM via the RAG MCP.
CREATE TABLE IF NOT EXISTS qa_log (
  id         SERIAL PRIMARY KEY,
  lecture_id INTEGER REFERENCES lectures(id) ON DELETE SET NULL,
  question   TEXT NOT NULL,
  answer     TEXT NOT NULL,
  citations  JSONB NOT NULL DEFAULT '[]'::jsonb,
  model_used TEXT,
  asked_at   TIMESTAMPTZ NOT NULL                 -- virtual time
);

-- The student finished watching this lecture (the Lecturer agent reached the end).
-- A finished lecture cannot be re-opened.
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- Exam results arriving from the exam system's webhook carry a proctoring
-- report; we keep it so the admin can judge whether an attempt has a problem.
ALTER TABLE grades ADD COLUMN IF NOT EXISTS exam_id TEXT UNIQUE;
ALTER TABLE grades ADD COLUMN IF NOT EXISTS flagged BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE grades ADD COLUMN IF NOT EXISTS report JSONB;

-- Where lecture generation currently is ("Writing lecture 2 of 4…"), shown on
-- the upload page while the course is being built from the book.
ALTER TABLE books ADD COLUMN IF NOT EXISTS progress TEXT;

-- Small key/value admin settings (e.g. course_size: XS | S | M | L | XL).
CREATE TABLE IF NOT EXISTS settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
