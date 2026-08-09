-- Use opaque UUIDs for authentication identity and retain the displayed
-- S-YYYY-NNNNNN value as the student's registration number.
BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'user' AND column_name = 'studentId'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public' AND table_name = 'user' AND column_name = 'registrationNumber'
  ) THEN
    ALTER TABLE "user" RENAME COLUMN "studentId" TO "registrationNumber";
  END IF;
END $$;

DROP INDEX IF EXISTS "user_studentId_key";
CREATE UNIQUE INDEX IF NOT EXISTS "user_registrationNumber_key"
  ON "user" ("registrationNumber");

DO $$
DECLARE
  current_id_type text;
BEGIN
  SELECT data_type INTO current_id_type
    FROM information_schema.columns
   WHERE table_schema = 'public' AND table_name = 'user' AND column_name = 'id';

  -- Fresh databases are already UUID-based from schema.sql. Existing databases
  -- enter this block once and are re-keyed without losing relationships.
  IF current_id_type = 'text' THEN
    CREATE TEMP TABLE user_uuid_map (
      old_id text PRIMARY KEY,
      new_id uuid NOT NULL UNIQUE
    ) ON COMMIT DROP;

    INSERT INTO user_uuid_map (old_id, new_id)
    SELECT "id", gen_random_uuid() FROM "user";

    ALTER TABLE "session" DROP CONSTRAINT IF EXISTS "session_userId_fkey";
    ALTER TABLE "account" DROP CONSTRAINT IF EXISTS "account_userId_fkey";

    UPDATE "session" s SET "userId" = m.new_id::text
      FROM user_uuid_map m WHERE s."userId" = m.old_id;
    UPDATE "account" a SET "userId" = m.new_id::text
      FROM user_uuid_map m WHERE a."userId" = m.old_id;
    UPDATE "session" s SET "impersonatedBy" = m.new_id::text
      FROM user_uuid_map m WHERE s."impersonatedBy" = m.old_id;
    UPDATE auth_audit a SET actor_id = m.new_id::text
      FROM user_uuid_map m WHERE a.actor_id = m.old_id;
    UPDATE auth_audit a SET target_id = m.new_id::text
      FROM user_uuid_map m WHERE a.target_id = m.old_id;
    UPDATE "user" u SET "id" = m.new_id::text
      FROM user_uuid_map m WHERE u."id" = m.old_id;

    -- These internal record IDs have no external references.
    UPDATE "session" SET "id" = gen_random_uuid()::text;
    UPDATE "account" SET "id" = gen_random_uuid()::text;
    UPDATE "verification" SET "id" = gen_random_uuid()::text;

    ALTER TABLE "user"
      ALTER COLUMN "id" TYPE uuid USING "id"::uuid,
      ALTER COLUMN "id" SET DEFAULT gen_random_uuid();
    ALTER TABLE "session"
      ALTER COLUMN "id" TYPE uuid USING "id"::uuid,
      ALTER COLUMN "id" SET DEFAULT gen_random_uuid(),
      ALTER COLUMN "userId" TYPE uuid USING "userId"::uuid;
    ALTER TABLE "account"
      ALTER COLUMN "id" TYPE uuid USING "id"::uuid,
      ALTER COLUMN "id" SET DEFAULT gen_random_uuid(),
      ALTER COLUMN "userId" TYPE uuid USING "userId"::uuid;
    ALTER TABLE "verification"
      ALTER COLUMN "id" TYPE uuid USING "id"::uuid,
      ALTER COLUMN "id" SET DEFAULT gen_random_uuid();

    ALTER TABLE "session" ADD CONSTRAINT "session_userId_fkey"
      FOREIGN KEY ("userId") REFERENCES "user" ("id") ON DELETE CASCADE;
    ALTER TABLE "account" ADD CONSTRAINT "account_userId_fkey"
      FOREIGN KEY ("userId") REFERENCES "user" ("id") ON DELETE CASCADE;
  END IF;
END $$;

COMMIT;
