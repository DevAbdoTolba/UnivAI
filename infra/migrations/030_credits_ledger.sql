-- Credits are additive benefits and consumable learning actions.
-- Preserve every existing wallet/transaction while replacing the old "coins"
-- naming and calendar-week top-up behavior.

DO $$
BEGIN
  IF to_regclass('public.credit_wallets') IS NULL
     AND to_regclass('public.coin_wallets') IS NOT NULL THEN
    ALTER TABLE coin_wallets RENAME TO credit_wallets;
  END IF;
  IF to_regclass('public.credit_transactions') IS NULL
     AND to_regclass('public.coin_transactions') IS NOT NULL THEN
    ALTER TABLE coin_transactions RENAME TO credit_transactions;
  END IF;
END;
$$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'credit_wallets'
       AND column_name = 'weekly_allowance'
  ) THEN
    ALTER TABLE credit_wallets RENAME COLUMN weekly_allowance TO weekly_grant_amount;
  END IF;
END;
$$;

ALTER TABLE credit_wallets
  ADD COLUMN IF NOT EXISTS reserved_balance integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS next_grant_at timestamptz;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'credit_wallets'
       AND column_name = 'week_started_at'
  ) THEN
    UPDATE credit_wallets
       SET next_grant_at = COALESCE(
         next_grant_at,
         (week_started_at::timestamp AT TIME ZONE 'UTC') + INTERVAL '7 days'
       );
    ALTER TABLE credit_wallets DROP COLUMN week_started_at;
  END IF;
END;
$$;

UPDATE credit_wallets
   SET next_grant_at = COALESCE(next_grant_at, CURRENT_TIMESTAMP + INTERVAL '7 days');
ALTER TABLE credit_wallets ALTER COLUMN next_grant_at SET NOT NULL;

ALTER TABLE credit_wallets DROP CONSTRAINT IF EXISTS credit_wallets_reserved_balance_check;
ALTER TABLE credit_wallets
  ADD CONSTRAINT credit_wallets_reserved_balance_check
  CHECK (reserved_balance >= 0 AND reserved_balance <= balance);

DO $$
DECLARE
  constraint_name text;
BEGIN
  FOR constraint_name IN
    SELECT conname
      FROM pg_constraint
     WHERE conrelid = 'credit_transactions'::regclass
       AND contype = 'c'
       AND pg_get_constraintdef(oid) ILIKE '%reason%'
  LOOP
    EXECUTE format('ALTER TABLE credit_transactions DROP CONSTRAINT %I', constraint_name);
  END LOOP;
END;
$$;

UPDATE credit_transactions
   SET reason = CASE reason
     WHEN 'weekly_refill' THEN 'weekly_grant'
     WHEN 'plan_change' THEN 'subscription_payment'
     ELSE reason
   END;

ALTER TABLE credit_transactions
  ADD COLUMN IF NOT EXISTS reference_type text,
  ADD COLUMN IF NOT EXISTS reference_id text,
  ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE credit_transactions
  ADD CONSTRAINT credit_transactions_reason_check
  CHECK (reason IN ('signup', 'weekly_grant', 'subscription_payment', 'spend', 'adjustment'));

DROP INDEX IF EXISTS coin_transactions_user_created_idx;
CREATE INDEX IF NOT EXISTS credit_transactions_user_created_idx
  ON credit_transactions (user_id, created_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS credit_reservations (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  amount           integer NOT NULL CHECK (amount > 0),
  purpose          text NOT NULL
                     CHECK (purpose IN ('raise_hand', 'answer_regeneration', 'practice_quiz', 'appeal')),
  status           text NOT NULL DEFAULT 'reserved'
                     CHECK (status IN ('reserved', 'settled', 'released', 'expired')),
  idempotency_key  text NOT NULL UNIQUE CHECK (length(idempotency_key) BETWEEN 8 AND 200),
  reference_type   text,
  reference_id     text,
  expires_at       timestamptz NOT NULL,
  settled_at       timestamptz,
  released_at      timestamptz,
  created_at       timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS credit_reservations_user_status_idx
  ON credit_reservations (user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS credit_reservations_expiry_idx
  ON credit_reservations (expires_at)
  WHERE status = 'reserved';

CREATE OR REPLACE FUNCTION release_expired_credit_reservations(p_user_id uuid DEFAULT NULL)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  released_count integer := 0;
BEGIN
  WITH expired AS (
    UPDATE credit_reservations
       SET status = 'expired', released_at = CURRENT_TIMESTAMP,
           updated_at = CURRENT_TIMESTAMP
     WHERE status = 'reserved'
       AND expires_at <= CURRENT_TIMESTAMP
       AND (p_user_id IS NULL OR user_id = p_user_id)
     RETURNING user_id, amount
  ), totals AS (
    SELECT user_id, SUM(amount)::integer AS amount, COUNT(*)::integer AS item_count
      FROM expired GROUP BY user_id
  ), wallets AS (
    UPDATE credit_wallets AS wallet
       SET reserved_balance = GREATEST(0, wallet.reserved_balance - totals.amount),
           updated_at = CURRENT_TIMESTAMP
      FROM totals
     WHERE wallet.user_id = totals.user_id
     RETURNING totals.item_count
  )
  SELECT COALESCE(SUM(item_count), 0)::integer INTO released_count FROM wallets;
  RETURN released_count;
END;
$$;

CREATE OR REPLACE FUNCTION catch_up_credit_grants(
  p_user_id uuid,
  p_now timestamptz DEFAULT CURRENT_TIMESTAMP
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
  wallet credit_wallets%ROWTYPE;
  grant_at timestamptz;
  inserted_id uuid;
  granted_total integer := 0;
BEGIN
  PERFORM release_expired_credit_reservations(p_user_id);
  SELECT * INTO wallet FROM credit_wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    INSERT INTO credit_wallets
      (user_id, balance, reserved_balance, weekly_grant_amount, next_grant_at)
    VALUES (p_user_id, 100, 0, 100, p_now + INTERVAL '7 days')
    RETURNING * INTO wallet;
    INSERT INTO credit_transactions
      (user_id, amount, balance_after, reason, idempotency_key)
    VALUES (p_user_id, 100, 100, 'signup', 'signup:' || p_user_id::text)
    ON CONFLICT (idempotency_key) DO NOTHING;
  END IF;

  grant_at := wallet.next_grant_at;
  WHILE grant_at <= p_now LOOP
    inserted_id := NULL;
    INSERT INTO credit_transactions
      (user_id, amount, balance_after, reason, idempotency_key,
       reference_type, reference_id)
    VALUES (
      p_user_id,
      wallet.weekly_grant_amount,
      wallet.balance + granted_total + wallet.weekly_grant_amount,
      'weekly_grant',
      'weekly-grant:' || p_user_id::text || ':' || to_char(grant_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US'),
      'schedule',
      grant_at::text
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING id INTO inserted_id;
    IF inserted_id IS NOT NULL THEN
      granted_total := granted_total + wallet.weekly_grant_amount;
    END IF;
    grant_at := grant_at + INTERVAL '7 days';
  END LOOP;

  IF grant_at <> wallet.next_grant_at OR granted_total > 0 THEN
    UPDATE credit_wallets
       SET balance = balance + granted_total,
           next_grant_at = grant_at,
           updated_at = CURRENT_TIMESTAMP
     WHERE user_id = p_user_id;
  END IF;
  RETURN granted_total;
END;
$$;

CREATE OR REPLACE FUNCTION reserve_credits(
  p_user_id uuid,
  p_amount integer,
  p_purpose text,
  p_idempotency_key text,
  p_reference_type text DEFAULT NULL,
  p_reference_id text DEFAULT NULL,
  p_ttl_seconds integer DEFAULT 900
)
RETURNS credit_reservations
LANGUAGE plpgsql
AS $$
DECLARE
  wallet credit_wallets%ROWTYPE;
  reservation credit_reservations%ROWTYPE;
BEGIN
  IF p_amount <= 0 OR p_ttl_seconds < 30 OR p_ttl_seconds > 86400 THEN
    RAISE EXCEPTION 'INVALID_CREDIT_RESERVATION';
  END IF;
  IF p_purpose NOT IN ('raise_hand', 'answer_regeneration', 'practice_quiz', 'appeal') THEN
    RAISE EXCEPTION 'INVALID_CREDIT_PURPOSE';
  END IF;

  PERFORM catch_up_credit_grants(p_user_id, CURRENT_TIMESTAMP);
  SELECT * INTO wallet FROM credit_wallets WHERE user_id = p_user_id FOR UPDATE;
  SELECT * INTO reservation
    FROM credit_reservations
   WHERE idempotency_key = p_idempotency_key
   FOR UPDATE;
  IF FOUND THEN
    IF reservation.user_id <> p_user_id OR reservation.amount <> p_amount
       OR reservation.purpose <> p_purpose THEN
      RAISE EXCEPTION 'CREDIT_IDEMPOTENCY_CONFLICT';
    END IF;
    RETURN reservation;
  END IF;
  IF wallet.balance - wallet.reserved_balance < p_amount THEN
    RAISE EXCEPTION 'INSUFFICIENT_CREDITS';
  END IF;

  INSERT INTO credit_reservations
    (user_id, amount, purpose, idempotency_key, reference_type, reference_id, expires_at)
  VALUES
    (p_user_id, p_amount, p_purpose, p_idempotency_key,
     p_reference_type, p_reference_id,
     CURRENT_TIMESTAMP + make_interval(secs => p_ttl_seconds))
  RETURNING * INTO reservation;
  UPDATE credit_wallets
     SET reserved_balance = reserved_balance + p_amount,
         updated_at = CURRENT_TIMESTAMP
   WHERE user_id = p_user_id;
  RETURN reservation;
END;
$$;

CREATE OR REPLACE FUNCTION settle_credit_reservation(
  p_user_id uuid,
  p_reservation_id uuid
)
RETURNS credit_reservations
LANGUAGE plpgsql
AS $$
DECLARE
  reservation credit_reservations%ROWTYPE;
  balance_after integer;
BEGIN
  PERFORM release_expired_credit_reservations(p_user_id);
  SELECT * INTO reservation
    FROM credit_reservations
   WHERE id = p_reservation_id AND user_id = p_user_id
   FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CREDIT_RESERVATION_NOT_FOUND'; END IF;
  IF reservation.status = 'settled' THEN RETURN reservation; END IF;
  IF reservation.status <> 'reserved' THEN RAISE EXCEPTION 'CREDIT_RESERVATION_NOT_ACTIVE'; END IF;

  UPDATE credit_wallets
     SET balance = balance - reservation.amount,
         reserved_balance = reserved_balance - reservation.amount,
         updated_at = CURRENT_TIMESTAMP
   WHERE user_id = p_user_id
   RETURNING balance INTO balance_after;
  UPDATE credit_reservations
     SET status = 'settled', settled_at = CURRENT_TIMESTAMP,
         updated_at = CURRENT_TIMESTAMP
   WHERE id = reservation.id
   RETURNING * INTO reservation;
  INSERT INTO credit_transactions
    (user_id, amount, balance_after, reason, idempotency_key,
     reference_type, reference_id, metadata)
  VALUES (
    p_user_id, -reservation.amount, balance_after, 'spend',
    'reservation-settle:' || reservation.id::text,
    reservation.reference_type, reservation.reference_id,
    jsonb_build_object('purpose', reservation.purpose, 'reservation_id', reservation.id)
  )
  ON CONFLICT (idempotency_key) DO NOTHING;
  RETURN reservation;
END;
$$;

CREATE OR REPLACE FUNCTION release_credit_reservation(
  p_user_id uuid,
  p_reservation_id uuid
)
RETURNS credit_reservations
LANGUAGE plpgsql
AS $$
DECLARE
  reservation credit_reservations%ROWTYPE;
BEGIN
  SELECT * INTO reservation
    FROM credit_reservations
   WHERE id = p_reservation_id AND user_id = p_user_id
   FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'CREDIT_RESERVATION_NOT_FOUND'; END IF;
  IF reservation.status IN ('released', 'expired') THEN RETURN reservation; END IF;
  IF reservation.status = 'settled' THEN RAISE EXCEPTION 'CREDIT_RESERVATION_ALREADY_SETTLED'; END IF;

  UPDATE credit_wallets
     SET reserved_balance = GREATEST(0, reserved_balance - reservation.amount),
         updated_at = CURRENT_TIMESTAMP
   WHERE user_id = p_user_id;
  UPDATE credit_reservations
     SET status = 'released', released_at = CURRENT_TIMESTAMP,
         updated_at = CURRENT_TIMESTAMP
   WHERE id = reservation.id
   RETURNING * INTO reservation;
  RETURN reservation;
END;
$$;

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

  INSERT INTO credit_transactions
    (user_id, amount, balance_after, reason, idempotency_key)
  VALUES (NEW."id", 100, 100, 'signup', 'signup:' || NEW."id"::text)
  ON CONFLICT (idempotency_key) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Focused answer regeneration keeps the previous answer visible and adds a
-- new immutable Q&A row only after grounded generation succeeds.
ALTER TABLE qa_log
  ADD COLUMN IF NOT EXISTS parent_qa_id bigint REFERENCES qa_log(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS context_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS credit_reservation_id uuid REFERENCES credit_reservations(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS qa_log_parent_idx ON qa_log (parent_qa_id, id DESC);
CREATE UNIQUE INDEX IF NOT EXISTS qa_log_credit_reservation_key
  ON qa_log (credit_reservation_id) WHERE credit_reservation_id IS NOT NULL;

-- One paid, resumable five-question practice package per generation request.
CREATE TABLE IF NOT EXISTS practice_attempts (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                uuid NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  student_id             text NOT NULL,
  lecture_public_id      uuid NOT NULL,
  credit_reservation_id  uuid NOT NULL UNIQUE REFERENCES credit_reservations(id),
  package_id             text NOT NULL UNIQUE,
  exam_id                text,
  launch_url             text,
  status                 text NOT NULL DEFAULT 'generating'
                           CHECK (status IN ('generating', 'ready', 'failed')),
  error                  text,
  created_at             timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS practice_attempts_user_created_idx
  ON practice_attempts (user_id, created_at DESC);

CREATE OR REPLACE FUNCTION enforce_one_absence_item_per_case()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM absence_case_items WHERE case_id = NEW.case_id) THEN
    RAISE EXCEPTION 'An appeal may contain exactly one missed item';
  END IF;
  RETURN NEW;
END;
$$;
DO $$
BEGIN
  IF to_regclass('public.absence_case_items') IS NOT NULL THEN
    DROP TRIGGER IF EXISTS absence_case_one_item ON absence_case_items;
    CREATE TRIGGER absence_case_one_item
      BEFORE INSERT ON absence_case_items
      FOR EACH ROW EXECUTE FUNCTION enforce_one_absence_item_per_case();
  END IF;
END $$;
