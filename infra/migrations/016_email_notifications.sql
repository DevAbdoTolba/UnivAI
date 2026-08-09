-- Durable, preference-aware transactional email delivery.
-- Messages are plain text and recipient addresses are resolved only at send time.

CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id       uuid NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  category      text NOT NULL
                  CHECK (category IN ('course', 'lecture', 'assessment', 'transcript')),
  email_enabled boolean NOT NULL DEFAULT true,
  updated_at    timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, category)
);

CREATE TABLE IF NOT EXISTS notification_email_outbox (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_key     text NOT NULL UNIQUE CHECK (length(event_key) BETWEEN 1 AND 200),
  user_id       uuid NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  category      text NOT NULL
                  CHECK (category IN (
                    'course', 'lecture', 'assessment', 'transcript', 'security', 'billing'
                  )),
  event_type    text NOT NULL CHECK (length(event_type) BETWEEN 1 AND 80),
  subject       text NOT NULL CHECK (length(subject) BETWEEN 1 AND 180),
  text_body     text NOT NULL CHECK (length(text_body) BETWEEN 1 AND 8000),
  status        text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'processing', 'sent', 'failed')),
  attempts      integer NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 8),
  available_at  timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  locked_at     timestamptz,
  locked_by     text,
  last_error    text,
  sent_at       timestamptz,
  created_at    timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (
    (status = 'processing' AND locked_at IS NOT NULL AND locked_by IS NOT NULL)
    OR status <> 'processing'
  )
);

CREATE INDEX IF NOT EXISTS notification_email_outbox_dispatch_idx
  ON notification_email_outbox (available_at, created_at)
  WHERE status IN ('pending', 'processing');

CREATE INDEX IF NOT EXISTS notification_email_outbox_user_idx
  ON notification_email_outbox (user_id, created_at DESC);
