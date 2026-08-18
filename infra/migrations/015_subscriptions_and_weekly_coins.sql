-- Fair subscriptions: every learner keeps the complete academic product.
-- Paid plans grant additive Credits for optional learning actions.

CREATE TABLE IF NOT EXISTS user_subscriptions (
  user_id                   uuid PRIMARY KEY REFERENCES "user" ("id") ON DELETE CASCADE,
  plan_code                 text NOT NULL DEFAULT 'free'
                              CHECK (plan_code IN ('free', 'supporter', 'patron')),
  pending_plan_code         text
                              CHECK (pending_plan_code IS NULL OR pending_plan_code IN ('supporter', 'patron')),
  status                    text NOT NULL DEFAULT 'active'
                              CHECK (status IN ('active', 'approval_pending', 'suspended', 'cancelled', 'expired')),
  provider                  text NOT NULL DEFAULT 'none'
                              CHECK (provider IN ('none', 'paypal')),
  provider_subscription_id  text UNIQUE,
  provider_plan_id          text,
  created_at                timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at                timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS credit_wallets (
  user_id              uuid PRIMARY KEY REFERENCES "user" ("id") ON DELETE CASCADE,
  balance              integer NOT NULL DEFAULT 100 CHECK (balance >= 0),
  reserved_balance     integer NOT NULL DEFAULT 0 CHECK (reserved_balance >= 0 AND reserved_balance <= balance),
  weekly_grant_amount  integer NOT NULL DEFAULT 100 CHECK (weekly_grant_amount >= 0),
  next_grant_at        timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP + INTERVAL '7 days',
  updated_at           timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS credit_transactions (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  amount           integer NOT NULL,
  balance_after    integer NOT NULL CHECK (balance_after >= 0),
  reason           text NOT NULL CHECK (reason IN ('signup', 'weekly_grant', 'subscription_payment', 'spend', 'adjustment')),
  idempotency_key  text NOT NULL UNIQUE,
  reference_type  text,
  reference_id    text,
  metadata        jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at       timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS credit_transactions_user_created_idx
  ON credit_transactions (user_id, created_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS payment_webhook_events (
  event_id                 text PRIMARY KEY,
  event_type               text NOT NULL,
  provider_subscription_id text,
  received_at              timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION initialize_student_subscription()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO user_subscriptions (user_id)
  VALUES (NEW."id")
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO credit_wallets
    (user_id, balance, reserved_balance, weekly_grant_amount, next_grant_at)
  VALUES (NEW."id", 100, 0, 100, CURRENT_TIMESTAMP + INTERVAL '7 days')
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO credit_transactions (user_id, amount, balance_after, reason, idempotency_key)
  VALUES (NEW."id", 100, 100, 'signup', 'signup:' || NEW."id"::text)
  ON CONFLICT (idempotency_key) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS user_initialize_subscription ON "user";
CREATE TRIGGER user_initialize_subscription
  AFTER INSERT ON "user"
  FOR EACH ROW
  EXECUTE FUNCTION initialize_student_subscription();

-- Existing learners begin on Free. Nothing academic is removed or gated.
INSERT INTO user_subscriptions (user_id)
SELECT "id" FROM "user"
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO credit_wallets
  (user_id, balance, reserved_balance, weekly_grant_amount, next_grant_at)
SELECT "id", 100, 0, 100, CURRENT_TIMESTAMP + INTERVAL '7 days' FROM "user"
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO credit_transactions (user_id, amount, balance_after, reason, idempotency_key)
SELECT "id", 100, 100, 'signup', 'signup:' || "id"::text FROM "user"
ON CONFLICT (idempotency_key) DO NOTHING;
