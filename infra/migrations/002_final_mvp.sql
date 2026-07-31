-- UAI-M2-S1-01: versioned multi-book programme contracts.
-- Idempotent for local and CI application.

CREATE TABLE IF NOT EXISTS source_collections (
  collection_id TEXT PRIMARY KEY,
  schema_version TEXT NOT NULL CHECK (schema_version = 'source-collection-v1'),
  owner_id       TEXT NOT NULL,
  status         TEXT NOT NULL CHECK (status IN ('draft', 'ingesting', 'ready', 'failed')),
  error          TEXT,
  created_at     TIMESTAMPTZ NOT NULL,
  updated_at     TIMESTAMPTZ NOT NULL,
  CONSTRAINT source_collection_error_state CHECK (
    (status = 'failed' AND error IS NOT NULL)
    OR (status <> 'failed' AND error IS NULL)
  )
);
CREATE INDEX IF NOT EXISTS source_collections_owner_idx
  ON source_collections (owner_id, created_at DESC);

CREATE TABLE IF NOT EXISTS source_documents (
  document_id  TEXT PRIMARY KEY,
  collection_id TEXT NOT NULL REFERENCES source_collections(collection_id) ON DELETE CASCADE,
  filename     TEXT NOT NULL,
  title        TEXT NOT NULL,
  media_type   TEXT NOT NULL,
  page_count   INTEGER NOT NULL CHECK (page_count > 0),
  status       TEXT NOT NULL CHECK (status IN ('registered', 'ingesting', 'ready', 'failed')),
  error        TEXT,
  created_at   TIMESTAMPTZ NOT NULL,
  updated_at   TIMESTAMPTZ NOT NULL,
  CONSTRAINT source_document_error_state CHECK (
    (status = 'failed' AND error IS NOT NULL)
    OR (status <> 'failed' AND error IS NULL)
  )
);
CREATE INDEX IF NOT EXISTS source_documents_collection_idx
  ON source_documents (collection_id);

CREATE TABLE IF NOT EXISTS ingestion_jobs (
  job_id          TEXT PRIMARY KEY,
  schema_version  TEXT NOT NULL CHECK (schema_version = 'source-collection-v1'),
  collection_id   TEXT NOT NULL REFERENCES source_collections(collection_id) ON DELETE CASCADE,
  document_id     TEXT NOT NULL REFERENCES source_documents(document_id) ON DELETE CASCADE,
  owner_id        TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  status          TEXT NOT NULL CHECK (status IN ('queued', 'ingesting', 'ready', 'failed')),
  error           TEXT,
  created_at      TIMESTAMPTZ NOT NULL,
  updated_at      TIMESTAMPTZ NOT NULL,
  UNIQUE (owner_id, idempotency_key),
  CONSTRAINT ingestion_job_error_state CHECK (
    (status = 'failed' AND error IS NOT NULL)
    OR (status <> 'failed' AND error IS NULL)
  )
);
CREATE INDEX IF NOT EXISTS ingestion_jobs_collection_idx
  ON ingestion_jobs (collection_id, created_at DESC);

CREATE TABLE IF NOT EXISTS programme_plans (
  plan_id             TEXT NOT NULL,
  plan_version        INTEGER NOT NULL CHECK (plan_version > 0),
  parent_plan_version INTEGER,
  schema_version      TEXT NOT NULL CHECK (schema_version = 'programme-plan-v1'),
  collection_id       TEXT NOT NULL REFERENCES source_collections(collection_id),
  owner_id            TEXT NOT NULL,
  status              TEXT NOT NULL CHECK (status IN ('proposed', 'approved')),
  plan_payload        JSONB NOT NULL,
  approved_by         TEXT,
  approved_at         TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL,
  updated_at          TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (plan_id, plan_version),
  UNIQUE (collection_id, plan_version),
  CONSTRAINT programme_plan_parent_version CHECK (
    (plan_version = 1 AND parent_plan_version IS NULL)
    OR (plan_version > 1 AND parent_plan_version = plan_version - 1)
  ),
  CONSTRAINT programme_plan_approval_state CHECK (
    (status = 'approved' AND approved_by IS NOT NULL AND approved_at IS NOT NULL)
    OR (status = 'proposed' AND approved_by IS NULL AND approved_at IS NULL)
  )
);
CREATE INDEX IF NOT EXISTS programme_plans_owner_idx
  ON programme_plans (owner_id, collection_id, plan_version DESC);
CREATE UNIQUE INDEX IF NOT EXISTS programme_plans_one_approved_version_idx
  ON programme_plans (plan_id)
  WHERE status = 'approved';

CREATE TABLE IF NOT EXISTS programme_generation_jobs (
  job_id          TEXT PRIMARY KEY,
  schema_version  TEXT NOT NULL CHECK (schema_version = 'programme-generation-job-v1'),
  collection_id   TEXT NOT NULL REFERENCES source_collections(collection_id),
  owner_id        TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  state           TEXT NOT NULL CHECK (
    state IN (
      'queued',
      'ingesting',
      'planning',
      'awaiting_approval',
      'generating',
      'ready',
      'failed'
    )
  ),
  plan_id         TEXT,
  plan_version    INTEGER,
  error           TEXT,
  created_at      TIMESTAMPTZ NOT NULL,
  updated_at      TIMESTAMPTZ NOT NULL,
  UNIQUE (owner_id, idempotency_key),
  FOREIGN KEY (plan_id, plan_version)
    REFERENCES programme_plans(plan_id, plan_version),
  CONSTRAINT generation_job_plan_reference CHECK (
    (plan_id IS NULL AND plan_version IS NULL)
    OR (plan_id IS NOT NULL AND plan_version IS NOT NULL)
  ),
  CONSTRAINT generation_job_plan_state CHECK (
    state NOT IN ('awaiting_approval', 'generating', 'ready')
    OR plan_id IS NOT NULL
  ),
  CONSTRAINT generation_job_error_state CHECK (
    (state = 'failed' AND error IS NOT NULL)
    OR (state <> 'failed' AND error IS NULL)
  )
);
CREATE INDEX IF NOT EXISTS programme_generation_jobs_owner_idx
  ON programme_generation_jobs (owner_id, created_at DESC);

-- Every production mutation reserves one owner-scoped key in the same
-- transaction as its state change. The request hash prevents key reuse with a
-- different payload; the stored response supports a deterministic retry.
CREATE TABLE IF NOT EXISTS core_mutation_idempotency (
  owner_id       TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  operation      TEXT NOT NULL,
  request_hash   TEXT NOT NULL,
  response_payload JSONB NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (owner_id, idempotency_key)
);

CREATE OR REPLACE FUNCTION prevent_approved_programme_plan_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.status = 'approved' THEN
    RAISE EXCEPTION 'approved plan %.% is immutable', OLD.plan_id, OLD.plan_version
      USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'programme_plans_approved_immutable_update'
  ) THEN
    CREATE TRIGGER programme_plans_approved_immutable_update
      BEFORE UPDATE ON programme_plans
      FOR EACH ROW
      EXECUTE FUNCTION prevent_approved_programme_plan_changes();
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'programme_plans_approved_immutable_delete'
  ) THEN
    CREATE TRIGGER programme_plans_approved_immutable_delete
      BEFORE DELETE ON programme_plans
      FOR EACH ROW
      WHEN (OLD.status = 'approved')
      EXECUTE FUNCTION prevent_approved_programme_plan_changes();
  END IF;
END;
$$;
