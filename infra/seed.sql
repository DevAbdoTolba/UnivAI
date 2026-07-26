-- UnivAI seed data. Idempotent: safe to re-run.

INSERT INTO settings (key, value)
VALUES ('course_size', 'S')
ON CONFLICT (key) DO NOTHING;
