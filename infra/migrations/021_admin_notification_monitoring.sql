-- Preserve opted-out notification events for privacy-safe delivery monitoring.
-- Message bodies and provider/worker data remain internal to the dispatcher.

ALTER TABLE notification_email_outbox
  DROP CONSTRAINT IF EXISTS notification_email_outbox_status_check;

ALTER TABLE notification_email_outbox
  ADD CONSTRAINT notification_email_outbox_status_check
  CHECK (status IN ('pending', 'processing', 'sent', 'failed', 'skipped'));

CREATE INDEX IF NOT EXISTS notification_email_outbox_monitor_idx
  ON notification_email_outbox (user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS notification_email_outbox_global_feed_idx
  ON notification_email_outbox (created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS notification_email_outbox_filter_idx
  ON notification_email_outbox (status, category, event_type, created_at DESC, id DESC);

-- Time-critical auth emails remain direct, but their delivery metadata is
-- recorded without recipient addresses, bodies, links, tokens, or provider data.
CREATE TABLE IF NOT EXISTS notification_email_delivery_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  category    text NOT NULL
                CHECK (category IN (
                  'course', 'lecture', 'assessment', 'transcript', 'security', 'billing'
                )),
  event_type  text NOT NULL CHECK (length(event_type) BETWEEN 1 AND 80),
  subject     text NOT NULL CHECK (length(subject) BETWEEN 1 AND 180),
  status      text NOT NULL DEFAULT 'queued'
                CHECK (status IN ('queued', 'sent', 'failed', 'skipped')),
  attempts    integer NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 1),
  last_error  text,
  sent_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS notification_email_delivery_log_monitor_idx
  ON notification_email_delivery_log (user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS notification_email_delivery_log_global_feed_idx
  ON notification_email_delivery_log (created_at DESC, id DESC);
CREATE INDEX IF NOT EXISTS notification_email_delivery_log_filter_idx
  ON notification_email_delivery_log (status, category, event_type, created_at DESC, id DESC);
