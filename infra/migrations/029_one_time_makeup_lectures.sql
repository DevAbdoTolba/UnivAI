-- An access-only absence decision opens one normal, interactive lecture at a
-- learner-confirmed start time. It is not a replay/archive entitlement.

ALTER TABLE absence_case_items
  ADD COLUMN IF NOT EXISTS makeup_started_at timestamptz;

ALTER TABLE absence_case_items
  DROP CONSTRAINT IF EXISTS absence_case_items_remedy_check;

UPDATE absence_case_items
   SET remedy = CASE WHEN item_type = 'lecture' THEN 'makeup_live' ELSE 'none' END
 WHERE remedy = 'replay';

ALTER TABLE absence_case_items
  ADD CONSTRAINT absence_case_items_remedy_check
  CHECK (remedy IN ('pending', 'none', 'exclude_from_denominator', 'makeup_live'));

ALTER TABLE absence_case_items
  DROP CONSTRAINT IF EXISTS absence_case_items_makeup_start_check;
ALTER TABLE absence_case_items
  ADD CONSTRAINT absence_case_items_makeup_start_check
  CHECK (
    makeup_started_at IS NULL
    OR (item_type = 'lecture' AND remedy = 'makeup_live')
  );

CREATE INDEX IF NOT EXISTS absence_case_items_makeup_idx
  ON absence_case_items (student_id, lecture_public_id, makeup_started_at)
  WHERE item_type = 'lecture' AND remedy = 'makeup_live';
