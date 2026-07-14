-- UnivAI MVP-1 schema. Idempotent: safe to re-run.
CREATE EXTENSION IF NOT EXISTS vector;

-- The virtual clock. Exactly one row (id = 1). Nothing else in the system
-- may read the wall clock; see ClockService (app/lib/clock.ts, services/common/clock.py).
CREATE TABLE IF NOT EXISTS clock_state (
  id         SMALLINT PRIMARY KEY DEFAULT 1,
  offset_ms  BIGINT   NOT NULL DEFAULT 0,
  CONSTRAINT clock_singleton CHECK (id = 1)
);
INSERT INTO clock_state (id, offset_ms) VALUES (1, 0) ON CONFLICT (id) DO NOTHING;

-- MVP-1 has exactly one book at a time.
CREATE TABLE IF NOT EXISTS books (
  id          SERIAL PRIMARY KEY,
  filename    TEXT NOT NULL,
  title       TEXT,
  pages       INTEGER NOT NULL DEFAULT 0,
  status      TEXT NOT NULL DEFAULT 'pending',   -- pending | ingesting | ready | failed
  error       TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL               -- virtual time
);

CREATE TABLE IF NOT EXISTS chunks (
  id        SERIAL PRIMARY KEY,
  book_id   INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  page      INTEGER NOT NULL,
  text      TEXT NOT NULL,
  embedding VECTOR(384)                           -- all-MiniLM-L6-v2
);
CREATE INDEX IF NOT EXISTS chunks_book_idx ON chunks (book_id);
CREATE INDEX IF NOT EXISTS chunks_text_idx ON chunks USING GIN (to_tsvector('english', text));

CREATE TABLE IF NOT EXISTS lectures (
  id         SERIAL PRIMARY KEY,
  book_id    INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  week       INTEGER NOT NULL,
  title      TEXT NOT NULL,
  starts_at  TIMESTAMPTZ NOT NULL,                -- virtual time
  status     TEXT NOT NULL DEFAULT 'draft',       -- draft | ready
  UNIQUE (book_id, week)
);

-- Attendance: TRACKING ONLY in MVP-1. No penalties, no enforcement.
-- 'absent' is never written eagerly: it is derived at read time (see clock rules).
CREATE TABLE IF NOT EXISTS attendance (
  id           SERIAL PRIMARY KEY,
  lecture_id   INTEGER NOT NULL REFERENCES lectures(id) ON DELETE CASCADE,
  joined_at    TIMESTAMPTZ NOT NULL,              -- virtual time
  status       TEXT NOT NULL,                     -- on_time | late
  late_minutes INTEGER NOT NULL DEFAULT 0,
  UNIQUE (lecture_id)
);

-- TODO(exam-system): grades are seeded/stubbed in MVP-1. Integrating
-- Ahmed Samir's UnivAI-exam_system APIs is a separate later task.
CREATE TABLE IF NOT EXISTS grades (
  id       SERIAL PRIMARY KEY,
  kind     TEXT NOT NULL,                         -- quiz | midterm
  week     INTEGER,                               -- NULL for midterm
  score    NUMERIC(5,2) NOT NULL,
  max_score NUMERIC(5,2) NOT NULL DEFAULT 100,
  feedback TEXT,
  taken_at TIMESTAMPTZ NOT NULL                   -- virtual time
);

CREATE TABLE IF NOT EXISTS qa_log (
  id         SERIAL PRIMARY KEY,
  lecture_id INTEGER REFERENCES lectures(id) ON DELETE SET NULL,
  question   TEXT NOT NULL,
  answer     TEXT NOT NULL,
  citations  JSONB NOT NULL DEFAULT '[]'::jsonb,
  model_used TEXT,
  asked_at   TIMESTAMPTZ NOT NULL                 -- virtual time
);
