-- Fixed weekly schedules, absence review, admin work items, and provider-aware
-- email delivery. All changes are additive except the honest sent->submitted
-- status rename; existing records keep their timestamps and event keys.

ALTER TABLE programmes
  ADD COLUMN IF NOT EXISTS schedule_timezone text,
  ADD COLUMN IF NOT EXISTS lecture_weekday smallint,
  ADD COLUMN IF NOT EXISTS lecture_local_time time,
  ADD COLUMN IF NOT EXISTS section_weekday smallint,
  ADD COLUMN IF NOT EXISTS section_local_time time,
  ADD COLUMN IF NOT EXISTS schedule_locked_at timestamptz,
  ADD COLUMN IF NOT EXISTS first_lecture_at timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'programmes_schedule_weekdays_valid'
       AND conrelid = 'programmes'::regclass
  ) THEN
    ALTER TABLE programmes
      ADD CONSTRAINT programmes_schedule_weekdays_valid CHECK (
        (lecture_weekday IS NULL OR lecture_weekday BETWEEN 0 AND 6)
        AND (section_weekday IS NULL OR section_weekday BETWEEN 0 AND 6)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'programmes_schedule_all_or_none'
       AND conrelid = 'programmes'::regclass
  ) THEN
    ALTER TABLE programmes
      ADD CONSTRAINT programmes_schedule_all_or_none CHECK (
        (
          schedule_timezone IS NULL
          AND lecture_weekday IS NULL
          AND lecture_local_time IS NULL
          AND section_weekday IS NULL
          AND section_local_time IS NULL
        ) OR (
          schedule_timezone IS NOT NULL
          AND lecture_weekday IS NOT NULL
          AND lecture_local_time IS NOT NULL
          AND section_weekday IS NOT NULL
          AND section_local_time IS NOT NULL
        )
      );
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS programmes_schedule_owner_idx
  ON programmes (student_id, status, schedule_locked_at);

CREATE OR REPLACE FUNCTION prevent_locked_programme_schedule_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF (OLD.status = 'approved' OR OLD.schedule_locked_at IS NOT NULL)
     AND ROW(
       NEW.schedule_timezone,
       NEW.lecture_weekday,
       NEW.lecture_local_time,
       NEW.section_weekday,
       NEW.section_local_time,
       NEW.schedule_locked_at,
       NEW.first_lecture_at
     ) IS DISTINCT FROM ROW(
       OLD.schedule_timezone,
       OLD.lecture_weekday,
       OLD.lecture_local_time,
       OLD.section_weekday,
       OLD.section_local_time,
       OLD.schedule_locked_at,
       OLD.first_lecture_at
     ) THEN
    RAISE EXCEPTION 'An approved programme schedule is immutable.'
      USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS programmes_schedule_immutable ON programmes;
CREATE TRIGGER programmes_schedule_immutable
BEFORE UPDATE ON programmes
FOR EACH ROW
EXECUTE FUNCTION prevent_locked_programme_schedule_change();

-- Absence cases are itemized so one explanation may cover both a lecture and
-- its quiz while every grade remedy stays explicit.
CREATE TABLE IF NOT EXISTS absence_cases (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id            text NOT NULL,
  status                text NOT NULL CHECK (status IN (
                          'needs_clarification', 'evidence_required',
                          'pending_admin', 'approved', 'rejected',
                          'expired', 'withdrawn'
                        )),
  reason                text NOT NULL CHECK (length(reason) BETWEEN 20 AND 2000),
  waiting_on            text NOT NULL CHECK (waiting_on IN ('learner', 'admin', 'none')),
  clarification_rounds  integer NOT NULL DEFAULT 0 CHECK (clarification_rounds BETWEEN 0 AND 2),
  question_code         text,
  recommendation        text CHECK (recommendation IS NULL OR recommendation IN (
                          'recommend_excused', 'recommend_access_only',
                          'recommend_unexcused', 'human_review'
                        )),
  policy_clause_ids     text[] NOT NULL DEFAULT '{}',
  sensitivity_flags     text[] NOT NULL DEFAULT '{}',
  admin_summary         text,
  ai_confidence         numeric(4,3) CHECK (
                          ai_confidence IS NULL OR ai_confidence BETWEEN 0 AND 1
                        ),
  outcome               text CHECK (outcome IS NULL OR outcome IN (
                          'excused', 'access_only', 'unexcused'
                        )),
  decision_reason       text,
  submitted_at          timestamptz NOT NULL,
  decided_at            timestamptz,
  decided_by            uuid REFERENCES "user" ("id") ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (
    (status IN ('approved', 'rejected') AND outcome IS NOT NULL AND decided_at IS NOT NULL)
    OR status NOT IN ('approved', 'rejected')
  )
);

CREATE INDEX IF NOT EXISTS absence_cases_student_idx
  ON absence_cases (student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS absence_cases_admin_queue_idx
  ON absence_cases (status, submitted_at)
  WHERE status = 'pending_admin';

CREATE TABLE IF NOT EXISTS absence_case_items (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id            uuid NOT NULL REFERENCES absence_cases(id) ON DELETE CASCADE,
  student_id         text NOT NULL,
  item_type          text NOT NULL CHECK (item_type IN ('lecture', 'quiz')),
  week               integer NOT NULL CHECK (week >= 1),
  lecture_public_id  uuid,
  remedy             text NOT NULL DEFAULT 'pending' CHECK (remedy IN (
                       'pending', 'none', 'exclude_from_denominator', 'replay'
                     )),
  created_at         timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (case_id, item_type, week)
);

CREATE INDEX IF NOT EXISTS absence_case_items_grade_idx
  ON absence_case_items (student_id, item_type, week, remedy);
CREATE UNIQUE INDEX IF NOT EXISTS absence_case_items_active_unique
  ON absence_case_items (student_id, item_type, week)
  WHERE remedy = 'pending';

CREATE TABLE IF NOT EXISTS absence_case_messages (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id       uuid NOT NULL REFERENCES absence_cases(id) ON DELETE CASCADE,
  actor         text NOT NULL CHECK (actor IN ('system', 'learner', 'admin')),
  question_code text,
  message       text NOT NULL CHECK (length(message) BETWEEN 1 AND 2000),
  created_at    timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS absence_case_messages_case_idx
  ON absence_case_messages (case_id, created_at ASC);

-- Evidence is a normalized image, never a public file path. The application
-- re-encodes it through Sharp before insertion and serves it only to admins.
CREATE TABLE IF NOT EXISTS absence_evidence (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id           uuid NOT NULL REFERENCES absence_cases(id) ON DELETE CASCADE,
  student_id        text NOT NULL,
  mime_type         text NOT NULL CHECK (mime_type IN ('image/jpeg', 'image/png')),
  original_filename text NOT NULL CHECK (length(original_filename) BETWEEN 1 AND 180),
  byte_length       integer NOT NULL CHECK (byte_length BETWEEN 1 AND 5242880),
  sha256            text NOT NULL CHECK (sha256 ~ '^[a-f0-9]{64}$'),
  image_data        bytea NOT NULL,
  expires_at        timestamptz NOT NULL,
  created_at        timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (case_id, sha256)
);

CREATE INDEX IF NOT EXISTS absence_evidence_expiry_idx
  ON absence_evidence (expires_at);

CREATE TABLE IF NOT EXISTS absence_ai_runs (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id           uuid NOT NULL REFERENCES absence_cases(id) ON DELETE CASCADE,
  prompt_id         text NOT NULL,
  prompt_version    text NOT NULL,
  model_label       text,
  input_digest      text NOT NULL CHECK (input_digest ~ '^[a-f0-9]{64}$'),
  structured_output jsonb,
  validation_status text NOT NULL CHECK (validation_status IN ('valid', 'fallback', 'rejected')),
  created_at        timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS absence_ai_runs_case_idx
  ON absence_ai_runs (case_id, created_at DESC);

CREATE TABLE IF NOT EXISTS admin_action_items (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  action_type  text NOT NULL CHECK (length(action_type) BETWEEN 1 AND 80),
  entity_type  text NOT NULL CHECK (length(entity_type) BETWEEN 1 AND 80),
  entity_id    uuid NOT NULL,
  student_id   text,
  title        text NOT NULL CHECK (length(title) BETWEEN 1 AND 180),
  safe_summary text NOT NULL CHECK (length(safe_summary) BETWEEN 1 AND 500),
  priority     text NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal', 'high', 'urgent')),
  status       text NOT NULL DEFAULT 'pending' CHECK (status IN (
                 'pending', 'assigned', 'resolved', 'dismissed'
               )),
  assigned_to  uuid REFERENCES "user" ("id") ON DELETE SET NULL,
  due_at       timestamptz,
  resolved_at  timestamptz,
  resolved_by  uuid REFERENCES "user" ("id") ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (action_type, entity_type, entity_id)
);

CREATE INDEX IF NOT EXISTS admin_action_items_queue_idx
  ON admin_action_items (status, priority, due_at, created_at);

-- Provider receipt and delivery state. Keep email content out of this ledger.
ALTER TABLE notification_email_outbox
  DROP CONSTRAINT IF EXISTS notification_email_outbox_status_check;
UPDATE notification_email_outbox SET status = 'submitted' WHERE status = 'sent';
ALTER TABLE notification_email_outbox
  ADD CONSTRAINT notification_email_outbox_status_check CHECK (
    status IN ('pending', 'processing', 'submitted', 'failed', 'skipped')
  );
ALTER TABLE notification_email_outbox
  ADD COLUMN IF NOT EXISTS provider_message_id text,
  ADD COLUMN IF NOT EXISTS provider_status text NOT NULL DEFAULT 'unknown',
  ADD COLUMN IF NOT EXISTS provider_event_at timestamptz,
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz;

ALTER TABLE notification_email_delivery_log
  DROP CONSTRAINT IF EXISTS notification_email_delivery_log_status_check;
UPDATE notification_email_delivery_log SET status = 'submitted' WHERE status = 'sent';
ALTER TABLE notification_email_delivery_log
  ADD CONSTRAINT notification_email_delivery_log_status_check CHECK (
    status IN ('queued', 'submitted', 'failed', 'skipped')
  );
ALTER TABLE notification_email_delivery_log
  ADD COLUMN IF NOT EXISTS provider_message_id text,
  ADD COLUMN IF NOT EXISTS provider_status text NOT NULL DEFAULT 'unknown',
  ADD COLUMN IF NOT EXISTS provider_event_at timestamptz,
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz;

DO $$
BEGIN
  ALTER TABLE notification_email_outbox
    DROP CONSTRAINT IF EXISTS notification_email_outbox_provider_status_check;
  ALTER TABLE notification_email_outbox
    ADD CONSTRAINT notification_email_outbox_provider_status_check CHECK (
      provider_status IN ('unknown', 'sent', 'delivered', 'delayed', 'bounced', 'failed', 'suppressed')
    );
  ALTER TABLE notification_email_delivery_log
    DROP CONSTRAINT IF EXISTS notification_email_delivery_log_provider_status_check;
  ALTER TABLE notification_email_delivery_log
    ADD CONSTRAINT notification_email_delivery_log_provider_status_check CHECK (
      provider_status IN ('unknown', 'sent', 'delivered', 'delayed', 'bounced', 'failed', 'suppressed')
    );
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS notification_outbox_provider_message_idx
  ON notification_email_outbox (provider_message_id)
  WHERE provider_message_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS notification_direct_provider_message_idx
  ON notification_email_delivery_log (provider_message_id)
  WHERE provider_message_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS email_provider_events (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_event_id   text NOT NULL UNIQUE CHECK (length(provider_event_id) BETWEEN 1 AND 180),
  provider_message_id text NOT NULL CHECK (length(provider_message_id) BETWEEN 1 AND 180),
  event_type          text NOT NULL CHECK (event_type IN (
                        'sent', 'delivered', 'delayed', 'bounced', 'failed', 'suppressed'
                      )),
  payload_digest      text NOT NULL CHECK (payload_digest ~ '^[a-f0-9]{64}$'),
  occurred_at         timestamptz NOT NULL,
  received_at         timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS email_provider_events_message_idx
  ON email_provider_events (provider_message_id, occurred_at DESC);

-- Admin-directed notices use the same durable outbox while remaining visibly
-- distinct from learner academic mail.
ALTER TABLE notification_email_outbox
  DROP CONSTRAINT IF EXISTS notification_email_outbox_category_check;
ALTER TABLE notification_email_outbox
  ADD CONSTRAINT notification_email_outbox_category_check CHECK (
    category IN ('course', 'lecture', 'assessment', 'transcript', 'security', 'billing', 'admin')
  );
ALTER TABLE notification_email_delivery_log
  DROP CONSTRAINT IF EXISTS notification_email_delivery_log_category_check;
ALTER TABLE notification_email_delivery_log
  ADD CONSTRAINT notification_email_delivery_log_category_check CHECK (
    category IN ('course', 'lecture', 'assessment', 'transcript', 'security', 'billing', 'admin')
  );
