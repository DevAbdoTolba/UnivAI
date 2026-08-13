-- Final grades remain provisional through a 14-day retake-request window.
-- A requested retake is scheduled seven days later and uses a reserve paper.

CREATE TABLE IF NOT EXISTS final_exam_cases (
  student_id text NOT NULL,
  curriculum_id text NOT NULL,
  primary_opens_at timestamptz NOT NULL,
  primary_closes_at timestamptz NOT NULL,
  request_deadline timestamptz NOT NULL,
  primary_exam_id text,
  primary_submitted_at timestamptz,
  primary_result jsonb,
  retake_requested_at timestamptz,
  retake_reason text,
  retake_available_at timestamptz,
  retake_closes_at timestamptz,
  retake_exam_id text,
  retake_submitted_at timestamptz,
  retake_result jsonb,
  declined_at timestamptz,
  declined_by uuid REFERENCES "user" ("id") ON DELETE SET NULL,
  decline_reason text,
  finalized_at timestamptz,
  finalization_reason text CHECK (
    finalization_reason IS NULL OR finalization_reason IN (
      'request_window_expired', 'retake_declined',
      'retake_completed', 'retake_not_taken'
    )
  ),
  official_exam_id text,
  official_result jsonb,
  created_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (student_id, curriculum_id),
  CHECK (primary_closes_at > primary_opens_at),
  CHECK (request_deadline > primary_closes_at),
  CHECK (
    (retake_requested_at IS NULL AND retake_available_at IS NULL AND retake_closes_at IS NULL)
    OR
    (retake_requested_at IS NOT NULL AND retake_available_at > retake_requested_at
      AND retake_closes_at > retake_available_at)
  )
);

CREATE INDEX IF NOT EXISTS final_exam_cases_request_queue_idx
  ON final_exam_cases (retake_requested_at, retake_available_at)
  WHERE finalized_at IS NULL AND declined_at IS NULL;

CREATE INDEX IF NOT EXISTS final_exam_cases_reconcile_idx
  ON final_exam_cases (request_deadline, retake_closes_at)
  WHERE finalized_at IS NULL;
