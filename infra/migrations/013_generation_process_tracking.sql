-- Track the exact detached generator so deleting its source can cancel only
-- that process instead of blocking every source removal for the learner.
ALTER TABLE books ADD COLUMN IF NOT EXISTS generation_pid INTEGER;
