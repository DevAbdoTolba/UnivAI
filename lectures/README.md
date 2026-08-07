# Legacy lecture directory

Integrated UnivAI no longer generates or reads learner content here.

Semester plans live in `books.semester_plan`; lecture scripts, structured
slides, quizzes, and generation checkpoints live in `lecture_artifacts`; and
grounded practicals live in `section_packs`. PostgreSQL generates opaque UUIDs
for every public lecture and section identifier. The app renders slides from
JSONB, the exam bridge reads quiz JSONB, and the Live worker reads narration
JSONB and synthesizes speech on demand.

This directory remains only as a clear boundary for old local artifacts and
standalone fixtures. Nothing in the integrated generation path writes here.
