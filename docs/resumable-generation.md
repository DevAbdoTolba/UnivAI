# Resumable course generation

Course generation publishes durable checkpoints instead of treating the whole
book as one job. A late failure never invalidates an earlier ready checkpoint.

## Lifecycle

1. Read the PDF, hash it, and save the deterministic semester plan.
2. For each week, checkpoint the lecture, quiz, and static slide deck.
3. As soon as one complete week is published, the curriculum may be built.
4. After all core weeks are published, render one week of audio per run.
5. Pause with the remaining audio marked `deferred`; the learner may request the
   next step when the machine has capacity.

The durable stages are `plan`, `lecture`, `quiz`, `slides`, and `audio`. Their
states are `pending`, `running`, `ready`, `failed`, or `deferred` in
`course_generation_milestones`.

## Resume rules

- A `ready` stage is reused only when its expected artifact still exists.
- Source identity is stored in `generation-manifest.json` using the PDF SHA-256.
- A changed source does not inherit checkpoints from the previous source.
- Audio is written clip-by-clip through atomic temporary files. A retry reuses
  valid clips and renders only missing or invalid clips.
- A failed stage records its own error. Earlier and later milestone state is not
  erased.
- The generator updates `books.heartbeat_at`; an abandoned run becomes
  recoverable after the heartbeat is stale.

## User-visible states

- `generating`: work is active; published week counts may already be usable.
- `partial`: the process paused at a safe boundary and can continue later.
- `partial_failed`: some content is usable, and the failed stage can be resumed.
- `failed`: no usable week exists yet; resume begins at the failed checkpoint.
- `ready`: all core and audio milestones are complete.

The Library polls every five seconds, lists every week's milestone state, enables
Build Curriculum after the first published week, and offers **Generate next
step** or **Resume generation** without re-indexing the PDF.
