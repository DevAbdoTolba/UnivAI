-- Generated learning content is database-owned. Filesystem paths are not an
-- artifact contract and sequential row ids are never exposed to learners.
-- Existing local files can be imported once with
-- scripts/migrate-legacy-lecture-artifacts.py after this schema is applied.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE books
  ADD COLUMN IF NOT EXISTS semester_plan JSONB,
  ADD COLUMN IF NOT EXISTS generation_manifest JSONB;

ALTER TABLE lectures ADD COLUMN IF NOT EXISTS public_id UUID;
UPDATE lectures SET public_id = gen_random_uuid() WHERE public_id IS NULL;
ALTER TABLE lectures ALTER COLUMN public_id SET DEFAULT gen_random_uuid();
ALTER TABLE lectures ALTER COLUMN public_id SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS lectures_public_id_key ON lectures (public_id);

CREATE TABLE IF NOT EXISTS lecture_artifacts (
  artifact_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  book_id          INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  student_id       TEXT NOT NULL,
  week             INTEGER NOT NULL CHECK (week > 0),
  title            TEXT NOT NULL,
  lecture_payload  JSONB NOT NULL,
  script_payload   JSONB NOT NULL,
  slides_payload   JSONB NOT NULL,
  quiz_payload     JSONB,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (book_id, week)
);
CREATE INDEX IF NOT EXISTS lecture_artifacts_student_week_idx
  ON lecture_artifacts (student_id, week, updated_at DESC);

ALTER TABLE lectures
  ADD COLUMN IF NOT EXISTS lecture_artifact_id UUID
    REFERENCES lecture_artifacts(artifact_id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS lectures_lecture_artifact_idx
  ON lectures (lecture_artifact_id);

-- section_packs predates the app's programme table and originally referenced a
-- separate prototype plan table. The production source of truth is the exact
-- approved programmes row/version.
ALTER TABLE section_packs
  DROP CONSTRAINT IF EXISTS section_packs_approved_plan_id_approved_plan_version_fkey;
ALTER TABLE section_packs
  ALTER COLUMN section_pack_id SET DEFAULT gen_random_uuid()::text;
CREATE INDEX IF NOT EXISTS section_packs_programme_version_idx
  ON section_packs (tenant_id, programme_id, approved_plan_version, week);

ALTER TABLE course_generation_milestones
  DROP CONSTRAINT IF EXISTS course_generation_milestones_stage_check;
ALTER TABLE course_generation_milestones
  ADD CONSTRAINT course_generation_milestones_stage_check
    CHECK (stage IN ('plan', 'lecture', 'quiz', 'slides', 'section', 'audio'));
