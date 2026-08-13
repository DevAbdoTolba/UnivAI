-- Membership lifecycle dates used by the learner-facing subscription monitor.

ALTER TABLE user_subscriptions
  ADD COLUMN IF NOT EXISTS subscribed_at timestamptz,
  ADD COLUMN IF NOT EXISTS current_period_ends_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;

UPDATE user_subscriptions
   SET subscribed_at = COALESCE(subscribed_at, updated_at),
       current_period_ends_at = COALESCE(
         current_period_ends_at,
         updated_at + INTERVAL '1 month'
       )
 WHERE plan_code IN ('supporter', 'patron');

UPDATE user_subscriptions
   SET cancelled_at = COALESCE(cancelled_at, updated_at)
 WHERE status IN ('cancelled', 'expired');
