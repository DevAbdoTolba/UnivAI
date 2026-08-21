# Final demo without LiveKit

This mode keeps the real Better Auth account, PostgreSQL course data, schedule,
attendance, Credits, slides, and section packs. It replaces only the live media
transport. Prepared media is private learner data and is stored in the ignored
`demo-media/` directory, not Git.

## Normal demo flow

Start the data services, then start the branch:

```powershell
./run.ps1 up
./run.ps1 dev
```

On macOS/Linux, use `make up && make dev`. `dev` is the final-demo default on
this branch; `demo` is an explicit alias. The launcher applies migrations,
stops LiveKit and the live worker, starts the app services, and quietly
backfills media for every existing approved account.

After signup, upload and approve the course normally. The course generator now
renders and validates that account's real audio, VTT, and manifests before it
marks the course ready. No account-specific console command is part of the demo
flow.

## Optional operator checks

These selectors remain available for diagnosis or a manual preflight:

```powershell
cd UnivAI-app
npm run demo:preflight -- --email upload@mailna.co
npm run demo:prepare-media -- --student S-2026-000042 --week 2
npm run demo:prepare-media -- --all-current
```

The command resolves the existing account and approved programme. It fails
instead of inventing content when the account, registration number, lecture
artifact, script, slides, or section pack is missing. Re-running unchanged
content reuses its content-addressed WAV files. A changed script digest or pack
hash publishes a new bundle atomically.

Use `./run.ps1 dev-integration` or `make dev-integration` only when explicitly
rolling back to the LiveKit + worker stack.

Check readiness at `http://localhost:3100/api/health`. A ready response reports
`adapters.live: "demo-media"` and nonzero prepared lecture bundles.

## Browser and behavior

- Use current desktop Chrome or Edge.
- Opening from Watch now shows a random 5–20 second joining state. The enabled
  Start/Resume click then satisfies browser autoplay rules and plays real audio.
- Captions, slides, and checkpoints follow the WAV media clock and VTT cues.
- On rejoin, Resume plays the generated welcome-back clip and rewinds three
  completed cues.
- Browser speech recognition is optional. Typed questions and section answers
  always remain available.
- Browser speech synthesis is used only for dynamic answers; lecture and static
  section narration always use prepared files.

## Recovery

- **Audio preparation failed:** resume/regenerate the failed course from the UI;
  its status stays failed instead of falsely becoming ready.
- **Stale artifact/pack:** regenerate media; old bundles are rejected by digest.
- **Audio request failed:** keep the page open, restore the network, and use the
  visible Retry/Resume control. The server checkpoint remains canonical.
- **Another tab is playing:** close or pause it, wait 15 seconds, then resume.
- **RAG unavailable:** narration still works; grounded Q&A fails visibly and its
  Credit reservation is released.
- **Session expired:** sign in again and reopen the lecture; the server restores
  the durable checkpoint.

Prepared media is served only through authenticated, tenant-scoped endpoints
with byte ranges, private caching, ETags, and stale-digest validation. Never copy
`demo-media/` into `public/` or commit it.
