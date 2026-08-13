-- Durable live-lecture checkpoints, connection presence, and attended time.
-- A learner who was admitted before the join cutoff may reconnect later; the
-- Live worker resumes from this checkpoint and never relies on process memory.

ALTER TABLE attendance
  ADD COLUMN IF NOT EXISTS attended_seconds double precision NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_connected boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS presence_last_seen_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_connected_at timestamptz,
  ADD COLUMN IF NOT EXISTS last_disconnected_at timestamptz,
  ADD COLUMN IF NOT EXISTS disconnect_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_sentence_index integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS total_sentences integer NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'attendance_attended_seconds_nonnegative'
       AND conrelid = 'attendance'::regclass
  ) THEN
    ALTER TABLE attendance
      ADD CONSTRAINT attendance_attended_seconds_nonnegative
      CHECK (attended_seconds >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'attendance_disconnect_count_nonnegative'
       AND conrelid = 'attendance'::regclass
  ) THEN
    ALTER TABLE attendance
      ADD CONSTRAINT attendance_disconnect_count_nonnegative
      CHECK (disconnect_count >= 0);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'attendance_sentence_progress_valid'
       AND conrelid = 'attendance'::regclass
  ) THEN
    ALTER TABLE attendance
      ADD CONSTRAINT attendance_sentence_progress_valid
      CHECK (
        last_sentence_index >= 0
        AND total_sentences >= 0
        AND (total_sentences = 0 OR last_sentence_index <= total_sentences)
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS attendance_connected_learner_idx
  ON attendance (student_id, is_connected)
  WHERE is_connected;
