-- Deterministic integration-demo records. Authentication still uses Better Auth.
INSERT INTO settings(key, value) VALUES ('course_size', 'XS')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

DELETE FROM attendance WHERE student_id = 'S-2026-000042';
DELETE FROM lectures WHERE student_id = 'S-2026-000042';
DELETE FROM grades WHERE student_id = 'S-2026-000042';
DELETE FROM books WHERE student_id = 'S-2026-000042';

INSERT INTO books(id, filename, title, pages, status, uploaded_at, progress, student_id)
VALUES (
  4200, 'standalone-course.md', 'Project-authored Integration Course', 4,
  'ready', '2026-07-27T08:00:00Z', 'Deterministic integration seed ready',
  'S-2026-000042'
)
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title, status = EXCLUDED.status, progress = EXCLUDED.progress;

INSERT INTO lectures(id, book_id, week, title, starts_at, status, student_id) VALUES
  (4211, 4200, 1, 'Evidence and Sources', '2026-07-28T10:00:00Z', 'ready', 'S-2026-000042'),
  (4212, 4200, 2, 'Tenant Isolation', '2026-08-04T10:00:00Z', 'ready', 'S-2026-000042'),
  (4213, 4200, 3, 'Explicit Runtime Modes', '2026-08-11T10:00:00Z', 'ready', 'S-2026-000042'),
  (4214, 4200, 4, 'Stable Contracts', '2026-08-18T10:00:00Z', 'ready', 'S-2026-000042')
ON CONFLICT (student_id, week) DO UPDATE SET
  title = EXCLUDED.title, starts_at = EXCLUDED.starts_at, status = EXCLUDED.status;

INSERT INTO grades(kind, week, score, max_score, feedback, taken_at, exam_id, flagged, report, student_id)
VALUES (
  'quiz', 1, 4, 5, 'Good use of source evidence.', '2026-07-28T11:10:00Z',
  'integration-demo-quiz-1', false,
  '{"suspicion_score":0,"flagged":false,"session_status":"completed","events":[]}',
  'S-2026-000042'
)
ON CONFLICT (exam_id) DO UPDATE SET score = EXCLUDED.score, report = EXCLUDED.report;
