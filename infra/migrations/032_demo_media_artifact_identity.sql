-- Bind durable demo checkpoints to the exact lecture artifact and plan.

ALTER TABLE attendance
  ADD COLUMN IF NOT EXISTS demo_media_artifact_id uuid,
  ADD COLUMN IF NOT EXISTS demo_media_plan_version integer;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'attendance_demo_media_identity_valid'
       AND conrelid = 'attendance'::regclass
  ) THEN
    ALTER TABLE attendance
      ADD CONSTRAINT attendance_demo_media_identity_valid CHECK (
        demo_media_plan_version IS NULL OR demo_media_plan_version > 0
      );
  END IF;
END $$;
