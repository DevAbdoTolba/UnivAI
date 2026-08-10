-- A final transcript is created immediately for reviewers, but learners wait
-- at most seven virtual days. Admins may release early or hold it for review.

ALTER TABLE course_transcripts
  ADD COLUMN IF NOT EXISTS review_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS release_at timestamptz,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS reviewed_by uuid REFERENCES "user" ("id") ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS review_note text,
  ADD COLUMN IF NOT EXISTS notification_queued_at timestamptz;

UPDATE course_transcripts AS transcript
   SET release_at = transcript.completed_at + INTERVAL '7 days',
       review_status = CASE
         WHEN EXISTS (
           SELECT 1 FROM certificate_artifacts AS certificate
            WHERE certificate.transcript_id = transcript.id
         ) THEN 'released'
         ELSE transcript.review_status
       END,
       notification_queued_at = CASE
         WHEN EXISTS (
           SELECT 1 FROM certificate_artifacts AS certificate
            WHERE certificate.transcript_id = transcript.id
         ) THEN CURRENT_TIMESTAMP
         ELSE transcript.notification_queued_at
       END
 WHERE transcript.release_at IS NULL;

ALTER TABLE course_transcripts
  ALTER COLUMN release_at SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'course_transcripts_review_status_check'
       AND conrelid = 'course_transcripts'::regclass
  ) THEN
    ALTER TABLE course_transcripts
      ADD CONSTRAINT course_transcripts_review_status_check
      CHECK (review_status IN ('pending', 'held', 'released'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS course_transcripts_review_queue_idx
  ON course_transcripts (review_status, release_at, completed_at DESC);

CREATE INDEX IF NOT EXISTS course_transcripts_release_notification_idx
  ON course_transcripts (notification_queued_at, completed_at)
  WHERE review_status = 'released';
