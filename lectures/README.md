# lectures/ — the generated course

Everything here is **written by the course builder**
(`UnivAI-Agent/generation/lecture_gen.py` — the Brain cave) from the uploaded
book. Don't edit
by hand unless you know why; the next "Regenerate course" overwrites it.

## Anatomy of a week

```
week-N/
  slides.md      the Slidev deck (title slide + content slides)
  script.json    what the Lecturer SPEAKS, aligned slide-by-slide, with page citations
  quiz.json      the week's question bank — each question tagged
                 "lecture" (taught) or "self_study" (book-only, max 10% of a paper)
  audio/         the pre-recorded voice: s{segment}-t{sentence}.npy + meta.json
                 (gitignored — regenerable in minutes)
```

`_prompts/` — the personalized raise-hand lines ("Yes, <student>? …"), same
voice as the lecture, also gitignored.

## Who reads what

- the **UnivAI-app** submodule reads `script.json` (titles, schedule) and serves the built decks
- the **voice worker** plays `audio/` and follows `script.json`
- the **exam system** gets `quiz.json` synced into its Mongo question bank on
  every exam start

Text content (`slides.md`, `script.json`, `quiz.json`) is committed so the
team can see the current course in git; binary audio is not.
