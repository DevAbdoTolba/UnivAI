# Final exam recovery and retake policy

Date: 10 August 2026

This document is the product and integration contract for UnivAI final exams. It separates an interrupted browser session from an academic retake: reconnecting during an open exam continues the same attempt, while a retake is a later second attempt on a reserve form.

## Timings

- The primary final opens when the learner's last scheduled lecture ends.
- The primary form remains open for 24 hours.
- When that window closes, the learner has 14 days to request one retake. The interval is half-open: a request at the exact deadline is too late.
- A requested retake opens exactly seven days after the request and remains open for 24 hours.
- These 24-hour form windows are current UnivAI product defaults because the original requirement did not specify an attempt-window length. Change the constants in `UnivAI-app/lib/final-exam-policy.ts` only together with UI, tests, and this contract.

## Learner state flow

| State | Learner action | Grade behavior |
| --- | --- | --- |
| Primary open | Start or continue the primary final | Saved answers stay server-side; no official final grade exists yet. |
| Primary closed, request open | Request a retake with a 20–1000 character reason, even after completion or a perfect score | A completed primary score is provisional. No submission is provisionally absent. |
| Retake waiting | Study while the seven-day delay runs | The learner sees the exact opening time and an encouraging message. |
| Retake open | Start or continue the reserve form | Completing it replaces the primary result in full, even when the replacement is lower. |
| No request by deadline | No action | Primary becomes official; no primary submission becomes `Absent — 0 (F)`. |
| Requested but retake not taken | No action by retake close | Primary becomes official; if there was no primary submission, the result is `Absent — 0 (F)`. |
| Administrator declines | No learner action | The primary/absent result becomes official and a mandatory decision email is queued atomically with the decision. |

A retake request is available regardless of the provisional score. That includes a primary score of 100%. This is a deliberate product rule, not a conclusion established by the research literature.

## Session recovery

Starting an already-active form creates a new attempt credential for the same exam and the same server-side answer state. Issuing the new credential:

- hashes and replaces the old token;
- increments the session generation;
- clears the old active connection identifier; and
- makes requests carrying the old token fail;
- replaces an older same-process proctoring socket without raising a false duplicate-session lock; and
- rejects later messages from an old socket on another replica by checking its generation and connection identifier in MongoDB.

The exam service checks the form's absolute closing time on reads, answer writes, proctoring events, and submission. At expiry it terminates an in-progress session, removes its credential, and directs the learner to the 14-day request flow. Recovery never creates an extra academic attempt.

## Two-form contract

The Exam service materializes both immutable forms for the learner before launching the first one:

1. `primary`, attempt 1;
2. `retake`, attempt 2.

Published assessment content must provide two complete, distinct packages using the same blueprint and plan version. Each form receives its own frozen question snapshot and the papers must not reuse question content, even under different question IDs. For legacy banks, at least 20 valid questions are required and the compatibility path divides them into two disjoint ten-question forms. Reusing the primary paper for the retake is not allowed.

## Administrator decision

An administrator can decline a request only before its reserve form has started. A 10–500 character reason is required. The decision, audit record, official grade, and required email outbox entry are committed as one database transaction. The learner sees the reason in the exam UI and receives email even when optional assessment emails are disabled.

The current implementation records one administrator's decision but does not provide a second-level appeal. The evidence review recommends adding a published eligibility rubric and an appeal/review path before treating discretionary decline as institution-ready policy.

## Finalization and transcript release

The final callback no longer writes a primary score directly to `grades`. It stores that score in `final_exam_cases` until a terminal policy event chooses the official result. Only that chosen result is written as the final grade. A submitted primary or reserve paper remains in `awaiting-grade` after its access window when trusted manual grading is still pending; it is never treated as a no-show. An absent final carries an explicit `report.absent` marker, forcing course letter grade `F` and GPA `0` even if coursework points alone exceed 50%.

After the official final grade is selected, the existing transcript-review workflow begins. Its seven-day review hold is additional to the 14-day retake-request period (or the requested-retake lifecycle); it does not run concurrently with a provisional primary score. Administrators may still release the transcript early or hold it for investigation.

## Operations and trust boundaries

- `POST /api/notifications/dispatch` must run regularly. It creates absentee cases for learners who never visit `/exams`, reconciles expired request/retake windows, releases due transcripts, and dispatches queued email.
- App-to-Exam final launches use a raw-body HMAC with `EXAM_CALLBACK_SECRET`; result callbacks use the reverse signed contract.
- The App chooses the authorized form and window. The Exam service owns immutable papers, answer state, attempt credentials, grading, and result delivery.
- PostgreSQL migration `020_final_exam_retakes.sql` is canonical for upgrades. Fresh integrated and standalone schemas contain the same constraints.

## Boundary examples

- Primary closes at 12:00:00 UTC: a resume at 11:59:59 is allowed; one at 12:00:00 is not.
- Request deadline is 14 days later at 12:00:00 UTC: a request at 11:59:59 is allowed; one at 12:00:00 is not.
- Request accepted Monday at 09:30 UTC: the reserve form opens the next Monday at 09:30 UTC and closes Tuesday at 09:30 UTC.
- A learner submits 100%, requests a retake, then earns 82%: 82% is the official final result.
- A learner submits 82%, requests a retake, then does not attend it: 82% remains official.
