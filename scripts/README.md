# scripts/ — build helpers

| Script | Does | Run |
|---|---|---|
| `build-slides.mjs` | legacy standalone Slidev builder; integrated generation compiles PostgreSQL decks itself | direct invocation for legacy fixtures only (`make slides` is a no-op) |
| `migrate-legacy-lecture-artifacts.py` | one-time backfill of old learner folders into `lecture_artifacts`; never used at runtime | `.venv/Scripts/python.exe scripts/migrate-legacy-lecture-artifacts.py --dry-run`, then rerun without `--dry-run` |

The course builder runs this automatically at the end of a generation — run it
by hand only after editing a deck yourself. Slidev comes from the **root**
`package.json`.
