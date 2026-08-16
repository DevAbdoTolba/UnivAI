-- Make absence clarification a repeatable admin-led conversation. AI triage
-- remains advisory: only an explicit admin message can request learner input
-- or authorize one protected image upload for that request.

ALTER TABLE absence_cases
  DROP CONSTRAINT IF EXISTS absence_cases_clarification_rounds_check;
ALTER TABLE absence_cases
  DROP CONSTRAINT IF EXISTS absence_cases_clarification_rounds_nonnegative;
ALTER TABLE absence_cases
  ADD CONSTRAINT absence_cases_clarification_rounds_nonnegative
  CHECK (clarification_rounds >= 0);

ALTER TABLE absence_case_messages
  ADD COLUMN IF NOT EXISTS actor_user_id uuid REFERENCES "user" ("id") ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS response_requested boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS attachment_requested boolean NOT NULL DEFAULT false;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'absence_case_messages_response_actor_check'
       AND conrelid = 'absence_case_messages'::regclass
  ) THEN
    ALTER TABLE absence_case_messages
      ADD CONSTRAINT absence_case_messages_response_actor_check
      CHECK (NOT response_requested OR actor = 'admin');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'absence_case_messages_attachment_request_check'
       AND conrelid = 'absence_case_messages'::regclass
  ) THEN
    ALTER TABLE absence_case_messages
      ADD CONSTRAINT absence_case_messages_attachment_request_check
      CHECK (NOT attachment_requested OR response_requested);
  END IF;
END $$;

ALTER TABLE absence_evidence
  ADD COLUMN IF NOT EXISTS request_message_id uuid
    REFERENCES absence_case_messages (id) ON DELETE SET NULL;

CREATE UNIQUE INDEX IF NOT EXISTS absence_evidence_request_unique
  ON absence_evidence (request_message_id)
  WHERE request_message_id IS NOT NULL;

-- Legacy AI-created learner waits must return to the human queue. The admin
-- can reuse the recorded AI suggestion, edit it, or decide without asking.
UPDATE absence_cases
   SET status = 'pending_admin', waiting_on = 'admin', updated_at = CURRENT_TIMESTAMP
 WHERE status IN ('needs_clarification', 'evidence_required');

INSERT INTO admin_action_items
  (action_type, entity_type, entity_id, student_id, title, safe_summary, priority, status)
SELECT 'absence_review', 'absence_case', absence_case.id, absence_case.student_id,
       'Absence case requires review',
       'A learner is waiting for a human absence decision or information request.',
       CASE
         WHEN absence_case.sensitivity_flags && ARRAY['legal', 'personal_safety']::text[]
           THEN 'high'
         ELSE 'normal'
       END,
       'pending'
  FROM absence_cases AS absence_case
 WHERE absence_case.status = 'pending_admin'
   AND absence_case.outcome IS NULL
ON CONFLICT (action_type, entity_type, entity_id) DO UPDATE
  SET status = 'pending',
      title = EXCLUDED.title,
      safe_summary = EXCLUDED.safe_summary,
      priority = EXCLUDED.priority,
      resolved_at = NULL,
      resolved_by = NULL,
      updated_at = CURRENT_TIMESTAMP;
