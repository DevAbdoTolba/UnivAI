-- Find a learner's generated file by where it lives.
--
-- ensureSchedule now attaches each week's artifacts to its lecture row by
-- storage_ref, because the generator stamps those keys before the lecture rows
-- exist and its UPDATE matched nothing. That lookup runs on schedule reads, so
-- it gets an index rather than a sequential scan that grows with every learner.

CREATE INDEX IF NOT EXISTS content_artifacts_storage_ref_idx
  ON content_artifacts (storage_ref);
