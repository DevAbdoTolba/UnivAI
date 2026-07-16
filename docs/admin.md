# The admin panel — `/admin`

**SUDO, no auth, local demo only.** This page is the remote control for the
whole simulation.

## Virtual clock

The world runs on virtual time (wall clock + an offset stored in Postgres).
From here you can:

- **+5 min / +1 hour / +1 day / +1 week** — nudge time forward
- **Jump to next lecture start** — the button you'll actually use in a demo
- **Reset to real time** — offset back to zero
- **Set exact time (ISO)** — teleport anywhere

Everything follows the clock: lecture LIVE/upcoming/done states, attendance
lateness, quiz windows (24h after each lecture), the midterm window (3 days
after week 4).

## Semester

**Restart semester** — one click:

- wipes attendance, grades, proctoring reports, the Q&A log, and every
  exam attempt (the exam world re-seeds itself on the next exam start)
- reschedules the four lectures to start fresh: tomorrow 10:00 virtual time,
  then weekly
- **keeps** all generated content — slides, narration, quizzes, voice

Use it between demo runs. The clock itself is not touched.

## Course size

One dial: **XS / S / M / L / XL** — controls slides per lecture, narration
length, and how many questions each quiz and the midterm carry
(M = a normal lecture; XS is the 3-slide smoke-test size).

**Regenerate course** — one button on purpose: lectures, slides, quizzes and
the pre-recorded voice rebuild together, so quizzes always match what the
lecturer actually says. Progress streams live on the page (and to
`logs/lecture-gen.log`). Expect ~25 min at size M on the local 3B model.

## Book

Shows the uploaded book and its status (`ingesting → generating → ready`).
Replacing the book happens on `/upload` — it clears the RAG index, resets
everything, and generates a brand-new course from the new PDF.

## The read-only cards

- **Attendance** — on-time / late (+minutes) / absent per lecture, with totals
- **Grades** — every quiz/midterm score with an **integrity chip**: clean or
  FLAGGED with the suspicion score and event count from the proctoring report
- **Q&A log** — every question asked mid-lecture, the spoken answer, and which
  model served it

The full proctoring reports (event-by-event tables) live on `/exams` — visible
there because *we* are the admins in this demo.
