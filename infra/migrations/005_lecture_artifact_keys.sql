-- 005_lecture_artifact_keys.sql
-- Migration 004's sibling change moved generated lecture output into
-- content_artifacts, but the lectures columns that point at those rows were
-- never created. Without them lecture_gen.py fails after writing the lecture
-- and the quiz ("column script_artifact_key of relation lectures does not
-- exist"), and lib/lectures.readScript / lib/exams cannot resolve an artifact.
--
-- Nullable on purpose: a lecture row exists from the moment it is scheduled and
-- only gains its artifact keys once generation finishes, so the three columns
-- carry NULL for the whole window in between.
-- Idempotent for existing local and deployed databases.

ALTER TABLE lectures
  ADD COLUMN IF NOT EXISTS script_artifact_key TEXT
    REFERENCES content_artifacts(content_key) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS slides_artifact_key TEXT
    REFERENCES content_artifacts(content_key) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS quiz_artifact_key   TEXT
    REFERENCES content_artifacts(content_key) ON DELETE SET NULL;

-- The app joins content_artifacts from lectures on every script and quiz read.
CREATE INDEX IF NOT EXISTS idx_lectures_script_artifact ON lectures (script_artifact_key);
CREATE INDEX IF NOT EXISTS idx_lectures_slides_artifact ON lectures (slides_artifact_key);
CREATE INDEX IF NOT EXISTS idx_lectures_quiz_artifact   ON lectures (quiz_artifact_key);
