-- The liveness beat of a running course build.
--
-- Resumable generation (006) shipped the progress columns but not the beat
-- itself, so every POST /api/upload died on `column "heartbeat_at" does not
-- exist` — the app and the Agent both write it, nothing created it.
--
-- The builder stamps it as it works (UnivAI-Agent/generation/lecture_gen.py);
-- the app treats a book stuck in 'generating' with a beat older than two
-- minutes as abandoned and lets a new upload take the work over
-- (UnivAI-app/app/api/upload/route.ts, lib/collections.ts). NULL means no
-- build has claimed this book yet, which is why there is no default.

ALTER TABLE books ADD COLUMN IF NOT EXISTS heartbeat_at TIMESTAMPTZ;

-- Sweeping for abandoned builds only ever looks at books mid-generation.
CREATE INDEX IF NOT EXISTS books_generating_heartbeat_idx
  ON books (heartbeat_at)
  WHERE status = 'generating';
