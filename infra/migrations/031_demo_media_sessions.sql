-- Durable state for the server-controlled, no-LiveKit final-demo transport.

ALTER TABLE attendance
  ADD COLUMN IF NOT EXISTS demo_media_script_digest text,
  ADD COLUMN IF NOT EXISTS demo_media_current_cue integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS demo_media_checkpoint_version integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS demo_media_active_session_id uuid,
  ADD COLUMN IF NOT EXISTS demo_media_last_heartbeat_at timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'attendance_demo_media_checkpoint_valid'
       AND conrelid = 'attendance'::regclass
  ) THEN
    ALTER TABLE attendance
      ADD CONSTRAINT attendance_demo_media_checkpoint_valid CHECK (
        (demo_media_script_digest IS NULL OR demo_media_script_digest ~ '^[a-f0-9]{64}$')
        AND demo_media_current_cue >= 0
        AND demo_media_checkpoint_version >= 0
      );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS demo_media_lecture_events (
  student_id       text NOT NULL,
  lecture_id       integer NOT NULL REFERENCES lectures(id) ON DELETE CASCADE,
  event_id         uuid NOT NULL,
  session_id       uuid NOT NULL,
  event_type       text NOT NULL CHECK (
    event_type IN ('start', 'checkpoint', 'heartbeat', 'pause', 'leave', 'complete')
  ),
  request_hash     text NOT NULL CHECK (request_hash ~ '^[a-f0-9]{64}$'),
  response_payload jsonb NOT NULL,
  created_at       timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (student_id, lecture_id, event_id)
);

CREATE INDEX IF NOT EXISTS demo_media_lecture_events_created_idx
  ON demo_media_lecture_events (student_id, lecture_id, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS section_session_one_pack_per_learner_idx
  ON section_session_state (tenant_id, learner_id, section_pack_id);
