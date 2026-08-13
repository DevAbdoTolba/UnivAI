-- Versioned, learner-owned feedback for every generated learning artifact.
-- Ratings, likes, and reports are deliberately independent actions. Reports
-- use a fixed taxonomy so the admin queue can be filtered and triaged.

ALTER TABLE qa_log ADD COLUMN IF NOT EXISTS trace_id TEXT;
UPDATE qa_log
   SET trace_id = gen_random_uuid()::text
 WHERE trace_id IS NULL OR btrim(trace_id) = '';
ALTER TABLE qa_log ALTER COLUMN trace_id SET DEFAULT gen_random_uuid()::text;
ALTER TABLE qa_log ALTER COLUMN trace_id SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS qa_log_trace_id_key ON qa_log(trace_id);

-- Retained for the existing course-regeneration retry contract. Generic
-- feedback below points directly at the generated target, not this retry row.
CREATE TABLE IF NOT EXISTS output_versions (
  id           BIGSERIAL PRIMARY KEY,
  student_id   TEXT NOT NULL,
  source_qa_id BIGINT NOT NULL REFERENCES qa_log(id) ON DELETE CASCADE,
  book_id      INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  version      INTEGER NOT NULL CHECK (version > 0),
  trace_id     TEXT NOT NULL UNIQUE,
  status       TEXT NOT NULL CHECK (status IN ('ready', 'generating', 'failed')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (student_id, source_qa_id, version)
);
CREATE INDEX IF NOT EXISTS output_versions_student_source_idx
  ON output_versions(student_id, source_qa_id, version DESC);

CREATE TABLE IF NOT EXISTS ai_output_reactions (
  id             BIGSERIAL PRIMARY KEY,
  student_id     TEXT NOT NULL,
  target_type    TEXT NOT NULL CHECK (target_type IN (
                     'raise_hand_answer', 'lecture', 'section', 'curriculum'
                   )),
  target_id      TEXT NOT NULL CHECK (length(target_id) BETWEEN 1 AND 200),
  target_version TEXT NOT NULL CHECK (length(target_version) BETWEEN 1 AND 200),
  trace_id       TEXT NOT NULL CHECK (length(trace_id) BETWEEN 1 AND 300),
  rating         SMALLINT CHECK (rating BETWEEN 1 AND 5),
  liked          BOOLEAN NOT NULL DEFAULT FALSE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (student_id, target_type, target_id, target_version)
);
CREATE INDEX IF NOT EXISTS ai_output_reactions_target_idx
  ON ai_output_reactions(target_type, target_id, target_version);
CREATE INDEX IF NOT EXISTS ai_output_reactions_student_updated_idx
  ON ai_output_reactions(student_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS ai_output_reports (
  id             BIGSERIAL PRIMARY KEY,
  student_id     TEXT NOT NULL,
  target_type    TEXT NOT NULL CHECK (target_type IN (
                     'raise_hand_answer', 'lecture', 'section', 'curriculum'
                   )),
  target_id      TEXT NOT NULL CHECK (length(target_id) BETWEEN 1 AND 200),
  target_version TEXT NOT NULL CHECK (length(target_version) BETWEEN 1 AND 200),
  trace_id       TEXT NOT NULL CHECK (length(trace_id) BETWEEN 1 AND 300),
  reason         TEXT NOT NULL CHECK (reason IN (
                     'incorrect', 'unsupported_or_uncited', 'irrelevant',
                     'unsafe_or_inappropriate', 'copyright_or_privacy',
                     'technical_issue'
                   )),
  detail         TEXT CHECK (detail IS NULL OR length(detail) <= 2000),
  status         TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
                     'pending', 'reviewing', 'resolved', 'dismissed'
                   )),
  admin_note     TEXT CHECK (admin_note IS NULL OR length(admin_note) <= 2000),
  reviewed_by    UUID REFERENCES "user"("id") ON DELETE SET NULL,
  reviewed_at    TIMESTAMPTZ,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (student_id, target_type, target_id, target_version)
);
CREATE INDEX IF NOT EXISTS ai_output_reports_queue_idx
  ON ai_output_reports(status, created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS ai_output_reports_target_idx
  ON ai_output_reports(target_type, target_id, target_version);

