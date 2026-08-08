-- Final course results and issued certificate images.
-- A transcript is a stable snapshot taken when the final result arrives.

CREATE TABLE IF NOT EXISTS course_transcripts (
  id                  TEXT PRIMARY KEY,
  student_id          TEXT NOT NULL,
  course_key          TEXT NOT NULL,
  course_title        TEXT NOT NULL,
  quiz_percentage     NUMERIC(5,2) NOT NULL CHECK (quiz_percentage BETWEEN 0 AND 100),
  attendance_percentage NUMERIC(5,2) NOT NULL CHECK (attendance_percentage BETWEEN 0 AND 100),
  midterm_percentage  NUMERIC(5,2) NOT NULL CHECK (midterm_percentage BETWEEN 0 AND 100),
  final_percentage    NUMERIC(5,2) NOT NULL CHECK (final_percentage BETWEEN 0 AND 100),
  coursework_points   NUMERIC(5,2) NOT NULL CHECK (coursework_points BETWEEN 0 AND 60),
  total_percentage    NUMERIC(5,2) NOT NULL CHECK (total_percentage BETWEEN 0 AND 100),
  letter_grade        TEXT NOT NULL CHECK (letter_grade IN ('F','D','D+','C-','C','C+','B-','B','B+','A-','A','A+','A*')),
  gpa                 NUMERIC(3,2) NOT NULL CHECK (gpa BETWEEN 0 AND 4),
  passed              BOOLEAN NOT NULL,
  completed_at        TIMESTAMPTZ NOT NULL,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (student_id, course_key)
);

CREATE INDEX IF NOT EXISTS course_transcripts_student_idx
  ON course_transcripts (student_id, completed_at DESC);

CREATE TABLE IF NOT EXISTS certificate_artifacts (
  id            TEXT PRIMARY KEY,
  transcript_id TEXT NOT NULL REFERENCES course_transcripts(id) ON DELETE CASCADE,
  student_id    TEXT NOT NULL,
  template_key  TEXT NOT NULL CHECK (template_key IN ('d','c','b','a','a-star')),
  filename      TEXT NOT NULL,
  mime_type     TEXT NOT NULL DEFAULT 'image/png',
  image_data    BYTEA NOT NULL,
  issued_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (transcript_id)
);

CREATE INDEX IF NOT EXISTS certificate_artifacts_student_idx
  ON certificate_artifacts (student_id, issued_at DESC);
