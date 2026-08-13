-- Quiz banks created before learner ownership was explicit may be donor copies.
-- They cannot be safely backfilled: force one quiz-only regeneration while
-- preserving every lecture, slide, section, and narration checkpoint.

UPDATE course_generation_milestones AS milestone
SET status = 'pending',
    progress = 'Learner-owned assessment regeneration required',
    artifact_ref = NULL,
    error = NULL,
    updated_at = CURRENT_TIMESTAMP
FROM lecture_artifacts AS artifact
WHERE milestone.book_id = artifact.book_id
  AND milestone.week = artifact.week
  AND milestone.stage = 'quiz'
  AND (
    artifact.quiz_payload IS NULL
    OR artifact.quiz_payload->>'schema_version' IS DISTINCT FROM 'learner-assessment-bank-v1'
    OR artifact.quiz_payload->>'owner_student_id' IS DISTINCT FROM artifact.student_id
    OR artifact.quiz_payload->>'owner_book_id' IS DISTINCT FROM artifact.book_id::text
    OR COALESCE(artifact.quiz_payload->>'generation_id', '') = ''
  );

UPDATE books AS book
SET status = 'partial',
    generation_stage = 'content',
    progress = 'Assessment banks need learner-owned regeneration',
    error = NULL
WHERE EXISTS (
  SELECT 1
  FROM lecture_artifacts AS artifact
  WHERE artifact.book_id = book.id
    AND (
      artifact.quiz_payload IS NULL
      OR artifact.quiz_payload->>'schema_version' IS DISTINCT FROM 'learner-assessment-bank-v1'
      OR artifact.quiz_payload->>'owner_student_id' IS DISTINCT FROM artifact.student_id
      OR artifact.quiz_payload->>'owner_book_id' IS DISTINCT FROM artifact.book_id::text
      OR COALESCE(artifact.quiz_payload->>'generation_id', '') = ''
    )
);

UPDATE lecture_artifacts AS artifact
SET quiz_payload = NULL,
    updated_at = CURRENT_TIMESTAMP
WHERE artifact.quiz_payload IS NOT NULL
  AND (
    artifact.quiz_payload->>'schema_version' IS DISTINCT FROM 'learner-assessment-bank-v1'
    OR artifact.quiz_payload->>'owner_student_id' IS DISTINCT FROM artifact.student_id
    OR artifact.quiz_payload->>'owner_book_id' IS DISTINCT FROM artifact.book_id::text
    OR COALESCE(artifact.quiz_payload->>'generation_id', '') = ''
  );

UPDATE books AS book
SET generation_ready_weeks = (
  SELECT COUNT(*)::integer
  FROM (
    SELECT milestone.week
    FROM course_generation_milestones AS milestone
    WHERE milestone.book_id = book.id
      AND milestone.week > 0
      AND milestone.stage IN ('lecture', 'quiz', 'slides')
      AND milestone.status = 'ready'
    GROUP BY milestone.week
    HAVING COUNT(DISTINCT milestone.stage) = 3
  ) AS ready_week
);
