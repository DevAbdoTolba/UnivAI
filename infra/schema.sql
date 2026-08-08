-- UnivAI MVP-1 schema. Idempotent: safe to re-run.
-- NOTE: RAG owns its own storage (chunks, embeddings, vector index) in the
-- team's existing RAG service. This app never stores or indexes book text.

-- The virtual clock. Exactly one row (id = 1). Nothing else in the system
-- may read the wall clock; see ClockService (app/lib/clock.ts, services/common/clock.py).
CREATE TABLE IF NOT EXISTS clock_state (
  id         SMALLINT PRIMARY KEY DEFAULT 1,
  offset_ms  BIGINT   NOT NULL DEFAULT 0,
  CONSTRAINT clock_singleton CHECK (id = 1)
);
INSERT INTO clock_state (id, offset_ms) VALUES (1, 0) ON CONFLICT (id) DO NOTHING;

-- MVP-1 has exactly one book. We keep only a pointer to it; the RAG service
-- holds the actual content.
CREATE TABLE IF NOT EXISTS books (
  id          SERIAL PRIMARY KEY,
  filename    TEXT NOT NULL,
  title       TEXT,
  pages       INTEGER NOT NULL DEFAULT 0,
  status      TEXT NOT NULL DEFAULT 'pending',   -- pending | ingesting | ready | failed
  error       TEXT,
  uploaded_at TIMESTAMPTZ NOT NULL               -- virtual time
);

CREATE TABLE IF NOT EXISTS lectures (
  id         SERIAL PRIMARY KEY,
  book_id    INTEGER REFERENCES books(id) ON DELETE CASCADE,
  week       INTEGER NOT NULL,
  title      TEXT NOT NULL,
  starts_at  TIMESTAMPTZ NOT NULL,                -- virtual time
  status     TEXT NOT NULL DEFAULT 'ready',
  UNIQUE (week)
);

-- Attendance: TRACKING ONLY in MVP-1. No penalties, no enforcement.
-- 'absent' is never stored: it is derived at read time from the virtual clock.
CREATE TABLE IF NOT EXISTS attendance (
  id           SERIAL PRIMARY KEY,
  lecture_id   INTEGER NOT NULL REFERENCES lectures(id) ON DELETE CASCADE,
  joined_at    TIMESTAMPTZ NOT NULL,              -- virtual time
  status       TEXT NOT NULL,                     -- on_time | late
  late_minutes INTEGER NOT NULL DEFAULT 0,
  UNIQUE (lecture_id)
);

-- TODO(exam-system): stubbed in MVP-1. Integrating the UnivAI-exam_system
-- submodule (Ahmed Samir's APIs) is a separate later task.
CREATE TABLE IF NOT EXISTS grades (
  id        SERIAL PRIMARY KEY,
  kind      TEXT NOT NULL,                        -- quiz | midterm
  week      INTEGER,                              -- NULL for midterm
  score     NUMERIC(5,2) NOT NULL,
  max_score NUMERIC(5,2) NOT NULL DEFAULT 100,
  feedback  TEXT,
  taken_at  TIMESTAMPTZ NOT NULL                  -- virtual time
);

-- Questions asked during a live lecture, answered by the tiny LLM via the RAG MCP.
CREATE TABLE IF NOT EXISTS qa_log (
  id         SERIAL PRIMARY KEY,
  lecture_id INTEGER REFERENCES lectures(id) ON DELETE SET NULL,
  question   TEXT NOT NULL,
  answer     TEXT NOT NULL,
  citations  JSONB NOT NULL DEFAULT '[]'::jsonb,
  model_used TEXT,
  asked_at   TIMESTAMPTZ NOT NULL                 -- virtual time
);

-- The student finished watching this lecture (the Lecturer agent reached the end).
-- A finished lecture cannot be re-opened.
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- Exam results arriving from the exam system's webhook carry a proctoring
-- report; we keep it so the admin can judge whether an attempt has a problem.
ALTER TABLE grades ADD COLUMN IF NOT EXISTS exam_id TEXT UNIQUE;
ALTER TABLE grades ADD COLUMN IF NOT EXISTS flagged BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE grades ADD COLUMN IF NOT EXISTS report JSONB;

-- Where lecture generation currently is ("Writing lecture 2 of 4…"), shown on
-- the upload page while the course is being built from the book.
ALTER TABLE books ADD COLUMN IF NOT EXISTS progress TEXT;
ALTER TABLE books ADD COLUMN IF NOT EXISTS source_sha256 TEXT;
ALTER TABLE books ADD COLUMN IF NOT EXISTS generation_stage TEXT;
ALTER TABLE books ADD COLUMN IF NOT EXISTS generation_total_weeks INTEGER NOT NULL DEFAULT 0;
ALTER TABLE books ADD COLUMN IF NOT EXISTS generation_ready_weeks INTEGER NOT NULL DEFAULT 0;
ALTER TABLE books ADD COLUMN IF NOT EXISTS generation_audio_ready_weeks INTEGER NOT NULL DEFAULT 0;
-- Liveness beat of a running build; a stale one means the build was abandoned
-- and a new upload may take it over. See migrations/007_generation_heartbeat.sql.
ALTER TABLE books ADD COLUMN IF NOT EXISTS heartbeat_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS books_generating_heartbeat_idx
  ON books (heartbeat_at)
  WHERE status = 'generating';
-- Byte identity, so a book already turned into a course is recognised rather
-- than rebuilt. See migrations/008_document_content_hash.sql.
CREATE INDEX IF NOT EXISTS books_source_sha256_idx
  ON books (source_sha256)
  WHERE source_sha256 IS NOT NULL;

CREATE TABLE IF NOT EXISTS course_generation_milestones (
  id            BIGSERIAL PRIMARY KEY,
  book_id       INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
  student_id    TEXT NOT NULL,
  week          INTEGER NOT NULL CHECK (week >= 0),
  stage         TEXT NOT NULL CHECK (stage IN ('plan', 'lecture', 'quiz', 'slides', 'audio')),
  status        TEXT NOT NULL CHECK (status IN ('pending', 'running', 'ready', 'failed', 'deferred')),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  progress      TEXT,
  error         TEXT,
  artifact_ref  TEXT,
  started_at    TIMESTAMPTZ,
  completed_at  TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (book_id, week, stage)
);
CREATE INDEX IF NOT EXISTS course_generation_milestones_book_idx
  ON course_generation_milestones (book_id, week, stage);
CREATE INDEX IF NOT EXISTS course_generation_milestones_student_status_idx
  ON course_generation_milestones (student_id, status, updated_at);

-- Small key/value admin settings (e.g. course_size: XS | S | M | L | XL).
CREATE TABLE IF NOT EXISTS settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- ===========================================================================
-- Auth (Better Auth). See docs/auth-plan.md + docs/auth-contract.md.
--
-- Generated by `npx @better-auth/cli generate` from UnivAI-app/lib/auth.ts,
-- adapted to CREATE ... IF NOT EXISTS so this file stays idempotent. If you
-- change lib/auth.ts (fields, plugins), REGENERATE and update this block.
-- camelCase identifiers are quoted on purpose — that is what Better Auth emits
-- and expects. Column order/types must match the generator exactly.
-- ===========================================================================

-- Serial behind the human-readable studentId (S-YYYY-NNNNNN), assigned in the
-- user.create hook in lib/auth.ts. The RAG / LiveKit namespace key.
CREATE SEQUENCE IF NOT EXISTS student_id_seq START 1;

CREATE TABLE IF NOT EXISTS "user" (
  "id"            text NOT NULL PRIMARY KEY,
  "name"          text NOT NULL,
  "email"         text NOT NULL UNIQUE,
  "emailVerified" boolean NOT NULL,
  "image"         text,
  "createdAt"     timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"     timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "role"          text,
  "banned"        boolean,
  "banReason"     text,
  "banExpires"    timestamptz,
  -- NULL = not given. Google sign-in supplies no phone number (migration 011).
  "phone"         text,
  "studentId"     text
);
-- studentId is server-assigned and must be globally unique (nulls allowed only
-- transiently). Unique INDEX (not a table constraint) keeps this idempotent.
CREATE UNIQUE INDEX IF NOT EXISTS "user_studentId_key" ON "user" ("studentId");

CREATE TABLE IF NOT EXISTS "session" (
  "id"             text NOT NULL PRIMARY KEY,
  "expiresAt"      timestamptz NOT NULL,
  "token"          text NOT NULL UNIQUE,
  "createdAt"      timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"      timestamptz NOT NULL,
  "ipAddress"      text,
  "userAgent"      text,
  "userId"         text NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  "impersonatedBy" text
);
CREATE INDEX IF NOT EXISTS "session_userId_idx" ON "session" ("userId");

CREATE TABLE IF NOT EXISTS "account" (
  "id"                    text NOT NULL PRIMARY KEY,
  "accountId"             text NOT NULL,
  "providerId"            text NOT NULL,
  "userId"                text NOT NULL REFERENCES "user" ("id") ON DELETE CASCADE,
  "accessToken"           text,
  "refreshToken"          text,
  "idToken"               text,
  "accessTokenExpiresAt"  timestamptz,
  "refreshTokenExpiresAt" timestamptz,
  "scope"                 text,
  "password"              text,
  "createdAt"             timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"             timestamptz NOT NULL
);
CREATE INDEX IF NOT EXISTS "account_userId_idx" ON "account" ("userId");

CREATE TABLE IF NOT EXISTS "verification" (
  "id"         text NOT NULL PRIMARY KEY,
  "identifier" text NOT NULL,
  "value"      text NOT NULL,
  "expiresAt"  timestamptz NOT NULL,
  "createdAt"  timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt"  timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS "verification_identifier_idx" ON "verification" ("identifier");

-- Audit trail for privileged admin actions (role changes, bans, deletes).
-- Written by the Better Auth after-hook in lib/auth-audit.ts. Uses REAL wall
-- time (not the virtual clock) — an audit log must reflect when things actually
-- happened. Not owned by any student, so it carries no user_id scoping.
CREATE TABLE IF NOT EXISTS auth_audit (
  id          BIGSERIAL PRIMARY KEY,
  action      TEXT NOT NULL,        -- set-role | ban-user | unban-user | remove-user
  actor_id    TEXT,                 -- who performed it (user.id)
  actor_email TEXT,
  target_id   TEXT,                 -- the affected user (user.id)
  detail      JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS auth_audit_target_idx ON auth_audit (target_id);
CREATE INDEX IF NOT EXISTS auth_audit_created_idx ON auth_audit (created_at DESC);

-- ===========================================================================
-- Phase 5 — per-student multi-tenancy.  See docs/auth-plan.md §5.
--
-- Tenant key is the human-readable user.studentId (S-YYYY-NNNNNN), threaded
-- across every service (RAG namespace, LiveKit identity, lecture/slide disk
-- dirs, exam records). Each learner owns their own book, course, attendance,
-- grades and Q&A; every app query filters by student_id.
--
-- Existing single-tenant demo rows keep student_id = NULL (they belong to no
-- one and are simply re-created per user on the next upload). No backfill.
-- ===========================================================================
ALTER TABLE books      ADD COLUMN IF NOT EXISTS student_id TEXT;
ALTER TABLE lectures   ADD COLUMN IF NOT EXISTS student_id TEXT;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS student_id TEXT;
ALTER TABLE grades     ADD COLUMN IF NOT EXISTS student_id TEXT;
ALTER TABLE qa_log     ADD COLUMN IF NOT EXISTS student_id TEXT;

-- Single-student uniqueness becomes per-student uniqueness. Drop the old
-- auto-named UNIQUE constraints (present on already-migrated DBs, absent on
-- fresh ones — DROP ... IF EXISTS covers both) and re-add as composite indexes.
ALTER TABLE lectures   DROP CONSTRAINT IF EXISTS lectures_week_key;
ALTER TABLE attendance DROP CONSTRAINT IF EXISTS attendance_lecture_id_key;
CREATE UNIQUE INDEX IF NOT EXISTS lectures_student_week_key    ON lectures   (student_id, week);
CREATE UNIQUE INDEX IF NOT EXISTS attendance_student_lecture_key ON attendance (student_id, lecture_id);

-- Owner-scoped read paths.
CREATE INDEX IF NOT EXISTS books_student_idx    ON books    (student_id);
CREATE INDEX IF NOT EXISTS grades_student_idx   ON grades   (student_id);
CREATE INDEX IF NOT EXISTS qa_log_student_idx   ON qa_log   (student_id);
-- (Referential FKs to "user"("studentId") with ON DELETE CASCADE are a later
-- hardening step; ownership is enforced in the app layer today.)

-- ===========================================================================
-- Versioned Core migrations
--
-- `make schema` and `./run.ps1 schema` apply this base schema followed by every
-- migration below, in order. Keep the migration files as the single source of
-- truth for post-MVP-1 contracts instead of copying their tables into this file.
--
--   infra/migrations/002_final_mvp.sql
--   infra/migrations/003_sprint3_learning_flow.sql
--   infra/migrations/004_app_library.sql
-- ===========================================================================
CREATE TABLE IF NOT EXISTS core_schema_migrations (
  version     INTEGER PRIMARY KEY,
  name        TEXT NOT NULL UNIQUE,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
