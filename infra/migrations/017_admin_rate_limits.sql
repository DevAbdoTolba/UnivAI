-- Authenticated, database-backed limits for expensive learner actions.
-- Admin overrides are per learner and scope; absent rows use safe app defaults.

CREATE TABLE IF NOT EXISTS user_rate_limit_policies (
  user_id          uuid NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  scope            text NOT NULL
                     CHECK (scope IN ('upload', 'generation', 'assessment', 'live', 'feedback', 'account')),
  enabled          boolean NOT NULL DEFAULT true,
  blocked          boolean NOT NULL DEFAULT false,
  max_requests     integer NOT NULL CHECK (max_requests BETWEEN 1 AND 10000),
  window_seconds   integer NOT NULL CHECK (window_seconds BETWEEN 1 AND 86400),
  updated_by       uuid REFERENCES "user" ("id") ON DELETE SET NULL,
  updated_at       timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, scope)
);

CREATE TABLE IF NOT EXISTS user_rate_limit_usage (
  user_id          uuid NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  scope            text NOT NULL
                     CHECK (scope IN ('upload', 'generation', 'assessment', 'live', 'feedback', 'account')),
  bucket_start     timestamptz NOT NULL,
  request_count    integer NOT NULL DEFAULT 0 CHECK (request_count >= 0),
  updated_at       timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, scope, bucket_start)
);

CREATE INDEX IF NOT EXISTS user_rate_limit_usage_cleanup_idx
  ON user_rate_limit_usage (bucket_start);

