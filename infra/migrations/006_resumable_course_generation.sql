-- Durable, resumable course generation. A book may expose completed weeks
-- while later content or audio remains pending, deferred, or failed.

ALTER TABLE books ADD COLUMN IF NOT EXISTS source_sha256 TEXT;
ALTER TABLE books ADD COLUMN IF NOT EXISTS generation_stage TEXT;
ALTER TABLE books ADD COLUMN IF NOT EXISTS generation_total_weeks INTEGER NOT NULL DEFAULT 0;
ALTER TABLE books ADD COLUMN IF NOT EXISTS generation_ready_weeks INTEGER NOT NULL DEFAULT 0;
ALTER TABLE books ADD COLUMN IF NOT EXISTS generation_audio_ready_weeks INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS course_generation_milestones (
  id            BIGSERIAL PRIMARY KEY,
  book_id       INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  student_id    TEXT NOT NULL,
  week          INTEGER NOT NULL CHECK (week >= 0),
  stage         TEXT NOT NULL CHECK (stage IN ('plan', 'lecture', 'quiz', 'slides', 'audio')),
  status        TEXT NOT NULL CHECK (status IN ('pending', 'running', 'ready', 'failed', 'deferred')),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  progress      TEXT,
  error         TEXT,
  artifact_ref  TEXT,
  started_at    TIMESTAMPTZ,
  completed_at  TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (book_id, week, stage)
);

CREATE INDEX IF NOT EXISTS course_generation_milestones_book_idx
  ON course_generation_milestones (book_id, week, stage);
CREATE INDEX IF NOT EXISTS course_generation_milestones_student_status_idx
  ON course_generation_milestones (student_id, status, updated_at);

