-- UAI-M2-S3-01: grounded multi-book learning flow and reliability evidence.
-- Apply after 002_final_mvp.sql. Idempotent for local and CI application.

CREATE TABLE IF NOT EXISTS content_artifacts (
  content_key          TEXT PRIMARY KEY CHECK (content_key ~ '^sha256:[a-f0-9]{64}\.pipeline:[a-f0-9]{64}$'),
  schema_version       TEXT NOT NULL CHECK (schema_version = 'content-artifact-v1'),
  original_sha256      TEXT NOT NULL CHECK (original_sha256 ~ '^[a-f0-9]{64}$'),
  pipeline_fingerprint JSONB NOT NULL,
  state                TEXT NOT NULL CHECK (state IN ('building', 'ready', 'failed', 'cleanup_eligible')),
  byte_length          BIGINT NOT NULL CHECK (byte_length > 0),
  page_count           INTEGER NOT NULL CHECK (page_count > 0),
  artifact_checksum    TEXT NOT NULL CHECK (artifact_checksum ~ '^[a-f0-9]{64}$'),
  storage_ref          TEXT NOT NULL,
  created_at           TIMESTAMPTZ NOT NULL,
  updated_at           TIMESTAMPTZ NOT NULL,
  UNIQUE (original_sha256, pipeline_fingerprint)
);
CREATE INDEX IF NOT EXISTS content_artifacts_state_idx
  ON content_artifacts (state, updated_at);

-- Access is granted only through this tenant-owned row. Artifact reuse does
-- not imply authorization, and RESTRICT prevents one grant from deleting a
-- shared artifact while another active grant exists.
CREATE TABLE IF NOT EXISTS tenant_document_grants (
  grant_id       TEXT PRIMARY KEY,
  schema_version TEXT NOT NULL CHECK (schema_version = 'tenant-document-grant-v1'),
  tenant_id      TEXT NOT NULL,
  collection_id  TEXT NOT NULL,
  document_id    TEXT NOT NULL,
  content_key    TEXT NOT NULL REFERENCES content_artifacts(content_key) ON DELETE RESTRICT,
  filename       TEXT NOT NULL,
  title          TEXT NOT NULL,
  status         TEXT NOT NULL CHECK (status IN ('active', 'revoked')),
  granted_at     TIMESTAMPTZ NOT NULL,
  revoked_at     TIMESTAMPTZ,
  UNIQUE (tenant_id, document_id),
  CONSTRAINT tenant_document_grant_revocation CHECK (
    (status = 'active' AND revoked_at IS NULL)
    OR (status = 'revoked' AND revoked_at IS NOT NULL)
  )
);
CREATE INDEX IF NOT EXISTS tenant_document_grants_authorization_idx
  ON tenant_document_grants (tenant_id, content_key)
  WHERE status = 'active';

CREATE TABLE IF NOT EXISTS learning_paths (
  path_id             TEXT NOT NULL,
  path_version        INTEGER NOT NULL CHECK (path_version > 0),
  parent_path_version INTEGER,
  schema_version      TEXT NOT NULL CHECK (schema_version = 'learning-path-v1'),
  tenant_id           TEXT NOT NULL,
  collection_id       TEXT NOT NULL,
  status              TEXT NOT NULL CHECK (status IN ('proposed', 'needs_review', 'approved')),
  path_payload        JSONB NOT NULL,
  approved_by         TEXT,
  approved_at         TIMESTAMPTZ,
  override_reason     TEXT,
  created_at          TIMESTAMPTZ NOT NULL,
  updated_at          TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (path_id, path_version),
  CONSTRAINT learning_path_parent_version CHECK (
    (path_version = 1 AND parent_path_version IS NULL)
    OR (path_version > 1 AND parent_path_version = path_version - 1)
  ),
  CONSTRAINT learning_path_approval_state CHECK (
    (status = 'approved' AND approved_by IS NOT NULL AND approved_at IS NOT NULL)
    OR (status <> 'approved' AND approved_by IS NULL AND approved_at IS NULL)
  )
);
CREATE UNIQUE INDEX IF NOT EXISTS learning_paths_one_approved_version_idx
  ON learning_paths (path_id) WHERE status = 'approved';
CREATE INDEX IF NOT EXISTS learning_paths_tenant_idx
  ON learning_paths (tenant_id, collection_id, path_version DESC);

CREATE TABLE IF NOT EXISTS semester_week_plans (
  plan_id               TEXT NOT NULL,
  plan_version          INTEGER NOT NULL CHECK (plan_version > 0),
  schema_version        TEXT NOT NULL CHECK (schema_version = 'semester-week-plan-v1'),
  tenant_id             TEXT NOT NULL,
  learning_path_id      TEXT NOT NULL,
  learning_path_version INTEGER NOT NULL,
  semester_id           TEXT NOT NULL,
  week_count            INTEGER NOT NULL CHECK (week_count > 0),
  plan_payload          JSONB NOT NULL,
  approved_at           TIMESTAMPTZ NOT NULL,
  created_at            TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (plan_id, plan_version),
  FOREIGN KEY (learning_path_id, learning_path_version)
    REFERENCES learning_paths(path_id, path_version)
);
CREATE INDEX IF NOT EXISTS semester_week_plans_tenant_idx
  ON semester_week_plans (tenant_id, semester_id, plan_version DESC);

CREATE TABLE IF NOT EXISTS sprint3_schedule_items (
  schedule_item_id TEXT PRIMARY KEY,
  tenant_id        TEXT NOT NULL,
  plan_id          TEXT NOT NULL,
  plan_version     INTEGER NOT NULL,
  week             INTEGER NOT NULL CHECK (week > 0),
  sequence         INTEGER NOT NULL CHECK (sequence > 0),
  session_type     TEXT NOT NULL CHECK (session_type IN ('lecture', 'section')),
  artifact_id      TEXT NOT NULL,
  starts_at        TIMESTAMPTZ NOT NULL,
  status           TEXT NOT NULL CHECK (status IN ('scheduled', 'ready', 'in_progress', 'completed', 'failed')),
  FOREIGN KEY (plan_id, plan_version)
    REFERENCES semester_week_plans(plan_id, plan_version) ON DELETE RESTRICT,
  UNIQUE (plan_id, plan_version, sequence)
);
CREATE UNIQUE INDEX IF NOT EXISTS sprint3_schedule_one_lecture_per_week_idx
  ON sprint3_schedule_items (plan_id, plan_version, week)
  WHERE session_type = 'lecture';
CREATE UNIQUE INDEX IF NOT EXISTS sprint3_schedule_one_section_per_week_idx
  ON sprint3_schedule_items (plan_id, plan_version, week)
  WHERE session_type = 'section';

CREATE TABLE IF NOT EXISTS section_packs (
  section_pack_id       TEXT PRIMARY KEY,
  schema_version        TEXT NOT NULL CHECK (schema_version = 'section-pack-v1'),
  tenant_id             TEXT NOT NULL,
  programme_id          TEXT NOT NULL,
  course_id             TEXT NOT NULL,
  week                  INTEGER NOT NULL CHECK (week > 0),
  lecture_id            TEXT NOT NULL,
  approved_plan_id      TEXT NOT NULL,
  approved_plan_version INTEGER NOT NULL,
  prompt_id             TEXT NOT NULL,
  prompt_version        TEXT NOT NULL,
  payload_hash          TEXT NOT NULL CHECK (payload_hash ~ '^[a-f0-9]{64}$'),
  pack_payload          JSONB NOT NULL,
  created_at            TIMESTAMPTZ NOT NULL,
  FOREIGN KEY (approved_plan_id, approved_plan_version)
    REFERENCES semester_week_plans(plan_id, plan_version) ON DELETE RESTRICT,
  UNIQUE (tenant_id, approved_plan_id, approved_plan_version, week)
);

CREATE TABLE IF NOT EXISTS section_session_state (
  session_id            TEXT PRIMARY KEY,
  schema_version        TEXT NOT NULL CHECK (schema_version = 'section-session-meta-v1'),
  tenant_id             TEXT NOT NULL,
  learner_id            TEXT NOT NULL,
  section_pack_id       TEXT NOT NULL REFERENCES section_packs(section_pack_id) ON DELETE RESTRICT,
  state                 TEXT NOT NULL CHECK (state IN ('intro', 'example', 'guided_task', 'waiting', 'feedback', 'todo_recap', 'completed', 'interrupted', 'failed')),
  resume_payload        JSONB NOT NULL,
  event_version         INTEGER NOT NULL CHECK (event_version >= 0),
  issued_at             TIMESTAMPTZ NOT NULL,
  expires_at            TIMESTAMPTZ NOT NULL,
  updated_at            TIMESTAMPTZ NOT NULL,
  CONSTRAINT section_session_expiry CHECK (expires_at > issued_at)
);
CREATE INDEX IF NOT EXISTS section_session_tenant_learner_idx
  ON section_session_state (tenant_id, learner_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS assessment_packages (
  package_id            TEXT NOT NULL,
  package_version       INTEGER NOT NULL CHECK (package_version > 0),
  schema_version        TEXT NOT NULL CHECK (schema_version = 'assessment-package-v1'),
  package_contract      TEXT NOT NULL CHECK (package_contract IN ('quiz-package-v1', 'midterm-package-v1', 'final-package-v1')),
  kind                  TEXT NOT NULL CHECK (kind IN ('quiz', 'midterm', 'final')),
  tenant_id             TEXT NOT NULL,
  learner_id            TEXT NOT NULL,
  approved_plan_id      TEXT NOT NULL,
  approved_plan_version INTEGER NOT NULL,
  package_hash          TEXT NOT NULL CHECK (package_hash ~ '^[a-f0-9]{64}$'),
  status                TEXT NOT NULL CHECK (status IN ('received', 'accepted', 'rejected')),
  package_payload       JSONB NOT NULL,
  created_at            TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (package_id, package_version),
  FOREIGN KEY (approved_plan_id, approved_plan_version)
    REFERENCES semester_week_plans(plan_id, plan_version) ON DELETE RESTRICT,
  UNIQUE (tenant_id, package_hash)
);
ALTER TABLE assessment_packages ADD COLUMN IF NOT EXISTS package_contract TEXT;
UPDATE assessment_packages
SET package_contract = kind || '-package-v1'
WHERE package_contract IS NULL;
ALTER TABLE assessment_packages ALTER COLUMN package_contract SET NOT NULL;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'assessment_packages_contract_kind'
  ) THEN
    ALTER TABLE assessment_packages
      ADD CONSTRAINT assessment_packages_contract_kind
      CHECK (package_contract = kind || '-package-v1');
  END IF;
END;
$$;
CREATE INDEX IF NOT EXISTS assessment_packages_tenant_kind_idx
  ON assessment_packages (tenant_id, kind, created_at DESC);

CREATE TABLE IF NOT EXISTS publication_receipts (
  receipt_id              TEXT PRIMARY KEY,
  schema_version          TEXT NOT NULL CHECK (schema_version = 'publication-receipt-v1'),
  package_id              TEXT NOT NULL,
  package_version         INTEGER NOT NULL,
  tenant_id               TEXT NOT NULL,
  status                  TEXT NOT NULL CHECK (status IN ('accepted', 'rejected')),
  published_assessment_id TEXT,
  published_version       INTEGER,
  defects                 JSONB NOT NULL DEFAULT '[]'::jsonb,
  audit_event_id          TEXT NOT NULL,
  processed_at            TIMESTAMPTZ NOT NULL,
  FOREIGN KEY (package_id, package_version)
    REFERENCES assessment_packages(package_id, package_version) ON DELETE RESTRICT,
  UNIQUE (package_id, package_version),
  CONSTRAINT publication_receipt_result CHECK (
    (status = 'accepted' AND published_assessment_id IS NOT NULL AND published_version IS NOT NULL AND jsonb_array_length(defects) = 0)
    OR (status = 'rejected' AND published_assessment_id IS NULL AND published_version IS NULL AND jsonb_array_length(defects) > 0)
  )
);

CREATE TABLE IF NOT EXISTS personalized_prompt_manifests (
  manifest_id             TEXT PRIMARY KEY,
  schema_version          TEXT NOT NULL CHECK (schema_version = 'personalized-prompt-manifest-v1'),
  learner_id              TEXT NOT NULL,
  normalized_name_digest  TEXT NOT NULL CHECK (normalized_name_digest ~ '^[a-f0-9]{64}$'),
  cache_key               TEXT NOT NULL UNIQUE CHECK (cache_key ~ '^prompt-cache/[a-f0-9]{64}$'),
  language                TEXT NOT NULL,
  voice                   TEXT NOT NULL,
  model                   TEXT NOT NULL,
  model_version           TEXT NOT NULL,
  sample_rate_hz          INTEGER NOT NULL CHECK (sample_rate_hz BETWEEN 8000 AND 96000),
  phrase_set_version      TEXT NOT NULL,
  state                   TEXT NOT NULL CHECK (state IN ('building', 'ready', 'repair_queued', 'failed')),
  clips                   JSONB NOT NULL,
  created_at              TIMESTAMPTZ NOT NULL,
  UNIQUE (learner_id, normalized_name_digest, language, voice, model, model_version, sample_rate_hz, phrase_set_version)
);

-- Safe spoken names remain in short-lived signed metadata and are not stored
-- here. Only the binding/digest/signature audit record is persisted.
CREATE TABLE IF NOT EXISTS signed_spoken_name_bindings (
  nonce                 TEXT PRIMARY KEY,
  schema_version        TEXT NOT NULL CHECK (schema_version = 'signed-spoken-name-metadata-v1'),
  tenant_id             TEXT NOT NULL,
  learner_id            TEXT NOT NULL,
  session_id            TEXT NOT NULL,
  lecture_id            TEXT NOT NULL,
  approved_plan_id      TEXT NOT NULL,
  approved_plan_version INTEGER NOT NULL,
  name_digest           TEXT NOT NULL CHECK (name_digest ~ '^[a-f0-9]{64}$'),
  signature_hash        TEXT NOT NULL CHECK (signature_hash ~ '^[a-f0-9]{64}$'),
  issued_at             TIMESTAMPTZ NOT NULL,
  expires_at            TIMESTAMPTZ NOT NULL,
  consumed_at           TIMESTAMPTZ,
  CONSTRAINT spoken_name_binding_expiry CHECK (expires_at > issued_at)
);
CREATE INDEX IF NOT EXISTS signed_spoken_name_session_idx
  ON signed_spoken_name_bindings (tenant_id, learner_id, session_id, expires_at);

CREATE TABLE IF NOT EXISTS startup_traces (
  trace_id         TEXT PRIMARY KEY,
  schema_version   TEXT NOT NULL CHECK (schema_version = 'startup-trace-v1'),
  tenant_id        TEXT NOT NULL,
  session_id       TEXT NOT NULL,
  mode             TEXT NOT NULL CHECK (mode IN ('cold', 'warm')),
  sample_origin    TEXT NOT NULL CHECK (sample_origin IN ('mock', 'measured')),
  target_hardware  TEXT NOT NULL,
  result           TEXT NOT NULL CHECK (result IN ('ready', 'failed', 'cancelled')),
  failure_code     TEXT,
  stages           JSONB NOT NULL,
  ready_ms         NUMERIC NOT NULL CHECK (ready_ms BETWEEN 0 AND 8000),
  first_frame_ms   NUMERIC NOT NULL CHECK (first_frame_ms >= ready_ms),
  recorded_at      TIMESTAMPTZ NOT NULL,
  CONSTRAINT startup_trace_failure_state CHECK (
    (result = 'ready' AND failure_code IS NULL)
    OR (result <> 'ready' AND failure_code IS NOT NULL)
  )
);
CREATE INDEX IF NOT EXISTS startup_traces_evidence_idx
  ON startup_traces (sample_origin, target_hardware, mode, recorded_at DESC);

CREATE TABLE IF NOT EXISTS cross_service_idempotency (
  tenant_id        TEXT NOT NULL,
  idempotency_key  TEXT NOT NULL,
  operation        TEXT NOT NULL,
  request_hash     TEXT NOT NULL CHECK (request_hash ~ '^[a-f0-9]{64}$'),
  trace_id         TEXT NOT NULL,
  state            TEXT NOT NULL CHECK (state IN ('reserved', 'completed', 'failed')),
  response_payload JSONB,
  error_payload    JSONB,
  created_at       TIMESTAMPTZ NOT NULL,
  completed_at     TIMESTAMPTZ,
  PRIMARY KEY (tenant_id, idempotency_key),
  CONSTRAINT cross_service_result_shape CHECK (
    (state = 'reserved' AND response_payload IS NULL AND error_payload IS NULL AND completed_at IS NULL)
    OR (state = 'completed' AND response_payload IS NOT NULL AND error_payload IS NULL AND completed_at IS NOT NULL)
    OR (state = 'failed' AND response_payload IS NULL AND error_payload IS NOT NULL AND completed_at IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS service_audit_events (
  event_id         TEXT PRIMARY KEY,
  tenant_id        TEXT NOT NULL,
  actor_id         TEXT NOT NULL,
  action           TEXT NOT NULL,
  resource_type    TEXT NOT NULL,
  resource_id      TEXT NOT NULL,
  resource_version INTEGER,
  trace_id         TEXT NOT NULL,
  detail           JSONB NOT NULL DEFAULT '{}'::jsonb,
  occurred_at      TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS service_audit_resource_idx
  ON service_audit_events (tenant_id, resource_type, resource_id, occurred_at DESC);

CREATE OR REPLACE FUNCTION prevent_sprint3_immutable_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_TABLE_NAME = 'learning_paths' AND OLD.status = 'approved' THEN
    RAISE EXCEPTION 'approved learning path %.% is immutable', OLD.path_id, OLD.path_version USING ERRCODE = '55000';
  END IF;
  IF TG_TABLE_NAME = 'assessment_packages' AND OLD.status IN ('accepted', 'rejected') THEN
    RAISE EXCEPTION 'processed assessment package %.% is immutable', OLD.package_id, OLD.package_version USING ERRCODE = '55000';
  END IF;
  IF TG_TABLE_NAME = 'publication_receipts' THEN
    RAISE EXCEPTION 'publication receipt % is immutable', OLD.receipt_id USING ERRCODE = '55000';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION protect_content_artifact_payload()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.state <> 'cleanup_eligible' THEN
      RAISE EXCEPTION 'artifact % must be cleanup_eligible before deletion', OLD.content_key USING ERRCODE = '55000';
    END IF;
    RETURN OLD;
  END IF;
  IF OLD.original_sha256 IS DISTINCT FROM NEW.original_sha256
    OR OLD.pipeline_fingerprint IS DISTINCT FROM NEW.pipeline_fingerprint
    OR OLD.byte_length IS DISTINCT FROM NEW.byte_length
    OR OLD.page_count IS DISTINCT FROM NEW.page_count
    OR OLD.artifact_checksum IS DISTINCT FROM NEW.artifact_checksum
    OR OLD.storage_ref IS DISTINCT FROM NEW.storage_ref THEN
    RAISE EXCEPTION 'content artifact % payload is immutable', OLD.content_key USING ERRCODE = '55000';
  END IF;
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  trigger_spec TEXT;
  trigger_name TEXT;
  table_name_value TEXT;
BEGIN
  FOREACH trigger_spec IN ARRAY ARRAY[
    'learning_paths_immutable:learning_paths',
    'assessment_packages_immutable:assessment_packages',
    'publication_receipts_immutable:publication_receipts'
  ] LOOP
    trigger_name := split_part(trigger_spec, ':', 1);
    table_name_value := split_part(trigger_spec, ':', 2);
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = trigger_name) THEN
      EXECUTE format(
        'CREATE TRIGGER %I BEFORE UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION prevent_sprint3_immutable_changes()',
        trigger_name,
        table_name_value
      );
    END IF;
  END LOOP;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'content_artifacts_payload_immutable') THEN
    CREATE TRIGGER content_artifacts_payload_immutable
      BEFORE UPDATE OR DELETE ON content_artifacts
      FOR EACH ROW
      EXECUTE FUNCTION protect_content_artifact_payload();
  END IF;
END;
$$;
