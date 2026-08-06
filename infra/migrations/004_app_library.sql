-- App source-library persistence required by the upload and programme flows.
-- Idempotent for existing local and deployed databases.

CREATE TABLE IF NOT EXISTS collections (
  id         SERIAL PRIMARY KEY,
  student_id TEXT NOT NULL,
  name       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_collections_student
  ON collections (student_id);

CREATE TABLE IF NOT EXISTS documents (
  id            SERIAL PRIMARY KEY,
  collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  student_id    TEXT NOT NULL,
  filename      TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'pending',
  error         TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_document_status CHECK (
    status IN ('pending', 'uploading', 'ready', 'failed')
  )
);

CREATE INDEX IF NOT EXISTS idx_documents_collection
  ON documents (collection_id);
CREATE INDEX IF NOT EXISTS idx_documents_student
  ON documents (student_id);

CREATE TABLE IF NOT EXISTS programmes (
  id            SERIAL PRIMARY KEY,
  student_id    TEXT NOT NULL,
  collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'proposed',
  plan_version  INTEGER NOT NULL DEFAULT 1,
  plan          JSONB NOT NULL DEFAULT '{}'::jsonb,
  approved_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_programme_status CHECK (
    status IN ('proposed', 'approved')
  )
);

CREATE INDEX IF NOT EXISTS idx_programmes_student
  ON programmes (student_id);
CREATE INDEX IF NOT EXISTS idx_programmes_collection
  ON programmes (collection_id);
