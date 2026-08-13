-- Versioned legal acceptance, UI locale, and privacy-rights request records.
-- Legal text still requires counsel approval; this migration provides the
-- auditable product controls needed to publish and enforce approved versions.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

ALTER TABLE "user"
  ADD COLUMN IF NOT EXISTS "uiLocale" TEXT NOT NULL DEFAULT 'en',
  ADD COLUMN IF NOT EXISTS "eulaAccepted" BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS "eulaVersion" TEXT,
  ADD COLUMN IF NOT EXISTS "eulaAcceptedAt" TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS "privacyNoticeAcknowledged" BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS "privacyNoticeVersion" TEXT,
  ADD COLUMN IF NOT EXISTS "privacyNoticeAcknowledgedAt" TIMESTAMPTZ;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'user_ui_locale_check'
       AND conrelid = '"user"'::regclass
  ) THEN
    ALTER TABLE "user"
      ADD CONSTRAINT user_ui_locale_check CHECK ("uiLocale" IN ('en', 'ar'));
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS legal_acceptances (
  id                  BIGSERIAL PRIMARY KEY,
  user_id             UUID NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
  registration_number TEXT,
  document_type       TEXT NOT NULL
                        CHECK (document_type IN ('eula', 'privacy_notice')),
  document_version    TEXT NOT NULL,
  document_hash       TEXT NOT NULL,
  context             TEXT NOT NULL
                        CHECK (context IN ('email_signup', 'oauth_signup', 'upload', 'settings')),
  locale              TEXT NOT NULL CHECK (locale IN ('en', 'ar')),
  accepted_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ip_address          TEXT,
  user_agent          TEXT
);

CREATE INDEX IF NOT EXISTS legal_acceptances_user_created_idx
  ON legal_acceptances(user_id, accepted_at DESC);
CREATE INDEX IF NOT EXISTS legal_acceptances_registration_created_idx
  ON legal_acceptances(registration_number, accepted_at DESC);

CREATE TABLE IF NOT EXISTS privacy_preferences (
  user_id                     UUID PRIMARY KEY REFERENCES "user"("id") ON DELETE CASCADE,
  sale_or_sharing_opt_out     BOOLEAN NOT NULL DEFAULT FALSE,
  limit_sensitive_data_use    BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS privacy_requests (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES "user"("id") ON DELETE CASCADE,
  registration_number TEXT,
  request_type        TEXT NOT NULL CHECK (request_type IN (
                        'access', 'deletion', 'correction', 'portability',
                        'restriction', 'objection', 'sale_share_opt_out',
                        'limit_sensitive_use'
                      )),
  status              TEXT NOT NULL DEFAULT 'received'
                        CHECK (status IN ('received', 'identity_check', 'in_progress', 'completed', 'declined', 'cancelled')),
  detail              TEXT,
  submitted_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  due_at              TIMESTAMPTZ NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '30 days'),
  identity_verified_at TIMESTAMPTZ,
  completed_at        TIMESTAMPTZ,
  admin_note          TEXT,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS privacy_requests_user_created_idx
  ON privacy_requests(user_id, submitted_at DESC);
CREATE INDEX IF NOT EXISTS privacy_requests_queue_idx
  ON privacy_requests(status, due_at, submitted_at);

CREATE INDEX IF NOT EXISTS user_admin_created_idx
  ON "user"("createdAt" DESC, "id" DESC);
CREATE INDEX IF NOT EXISTS user_admin_name_search_idx
  ON "user" USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS user_admin_email_search_idx
  ON "user" USING GIN (email gin_trgm_ops);
CREATE INDEX IF NOT EXISTS user_admin_registration_search_idx
  ON "user" USING GIN ("registrationNumber" gin_trgm_ops);
