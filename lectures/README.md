# Account lecture directory

Semester plans live in `books.semester_plan`; lecture scripts, structured
slides, quizzes, and generation checkpoints live in `lecture_artifacts`; and
grounded practicals live in `section_packs`. PostgreSQL generates opaque UUIDs
for every public lecture and section identifier.

The no-LiveKit demo stores each account's validated playable lecture bundle at
`<registration-number>/week-<N>/demo-media/<artifact>/plan-<N>/<script-digest>/`.
These generated account folders are ignored by Git; only this README is tracked.
