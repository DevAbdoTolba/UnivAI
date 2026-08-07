-- The byte identity of an uploaded book, known at upload time.
--
-- books.source_sha256 (006) is written by the generator, long after the upload
-- has been accepted, so the app could not answer the only question a learner
-- asks at that moment: "haven't I already uploaded this?" Uploading the same
-- book under a different filename simply made a second course.
--
-- This is always the SHA-256 the SERVER computed over the bytes it received.
-- The client sends its own hash as a hint so the UI can react early, but a
-- client-supplied value is never stored here and never grants access to
-- anything — see UnivAI-Agent/cache/content_identity.py for the same rule one
-- layer down.

ALTER TABLE documents ADD COLUMN IF NOT EXISTS content_sha256 TEXT;

-- "Do I already have this book?" is per learner, and it is asked on every
-- upload.
CREATE INDEX IF NOT EXISTS documents_student_content_idx
  ON documents (student_id, content_sha256);

-- "Has anyone already built a course from these bytes?" is how a second
-- learner skips the build entirely.
CREATE INDEX IF NOT EXISTS books_source_sha256_idx
  ON books (source_sha256)
  WHERE source_sha256 IS NOT NULL;
