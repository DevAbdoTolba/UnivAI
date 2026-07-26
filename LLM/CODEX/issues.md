# UnivAI Issues Register

**Snapshot:** 2026-07-26  
**Total:** 84 primary issues  
**MVP1:** 24 retrospective completed records  
**MVP2–MVP6:** 60 planned issues

## Usage

- Create issues only for the active MVP after its entry gate is accepted.
- Paste the relevant body into the owning repository's `task` or `feature` template.
- Keep the roadmap key in the title or body.
- Use exactly one accountable assignee and a different reviewer.
- Do not duplicate an existing issue identified below; expand/re-label it instead.
- MVP1 completed records are retrospective ownership/acceptance records, not a replacement for Git authorship.

## Summary by MVP

| MVP | Status | Sprints | Issues |
| --- | --- | --- | --- |
| 1 | Completed baseline | 4 | 24 |
| 2 | Planned | 2 | 12 |
| 3 | Planned | 2 | 12 |
| 4 | Planned | 2 | 12 |
| 5 | Planned | 2 | 12 |
| 6 | Planned | 2 | 12 |


# MVP 1 · Sprint 1 — Foundation and Repository Baseline


## UAI-M1-S1-01 — Bootstrap orchestrator, submodules and local infrastructure

- **Status:** ✅ Completed
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 1 — Foundation and Repository Baseline`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:1`, `sprint:1`, `priority:P0`, `status:completed-retro`

### Outcome

Create the main integration repository, register the four product submodules, and provide a repeatable local startup path.

### What needs to be done?

- [x] Register App, Agent, Live and Exam as pinned Git submodules.
- [x] Define Docker Compose services and stable local ports for Postgres, Qdrant, MongoDB and Ollama.
- [x] Provide Makefile/PowerShell entry points and environment examples.
- [x] Document startup order, health checks and failure diagnostics.

### Definition of Done / acceptance criteria

- [x] A recursive clone resolves all submodules at recorded commits.
- [x] The documented local command starts required infrastructure.
- [x] No secret is committed; example environment files contain placeholders only.
- [x] Repository map and port map match the running stack.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S1-02 — Build the application shell, routing and MUI baseline

- **Status:** ✅ Completed
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 1 — Foundation and Repository Baseline`
- **Story points:** 5
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:app`, `mvp:1`, `sprint:1`, `priority:P0`, `status:completed-retro`

### Outcome

Create the student/admin web application shell and the initial route structure used by later vertical slices.

### What needs to be done?

- [x] Create the Next.js application and shared layout/navigation.
- [x] Add initial routes for upload, schedule, lecture, exams, dashboard and admin.
- [x] Establish MUI component/theme conventions.
- [x] Add typed API client and configuration boundaries.

### Definition of Done / acceptance criteria

- [x] Application builds with strict TypeScript checks.
- [x] All baseline routes render without runtime errors.
- [x] Shared layout works on desktop and mobile widths.
- [x] API endpoints are configured through environment variables.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S1-03 — Create document-processing and vector-store foundation

- **Status:** ✅ Completed
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 1 — Foundation and Repository Baseline`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:agent`, `mvp:1`, `sprint:1`, `priority:P0`, `status:completed-retro`

### Outcome

Create the AI service skeleton for parsing books, chunking content, embedding chunks and storing retrieval metadata.

### What needs to be done?

- [x] Create the Python service/package structure.
- [x] Implement PDF text extraction and structure-preserving chunk contracts.
- [x] Connect Qdrant and define collection metadata.
- [x] Provide local LLM/embedding configuration with graceful error messages.

### Definition of Done / acceptance criteria

- [x] A supported PDF can be parsed into deterministic chunks.
- [x] Chunks include document and page/section metadata.
- [x] Embeddings can be inserted and retrieved from Qdrant.
- [x] Invalid files and unavailable models return structured errors.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S1-04 — Create LiveKit worker and speech pipeline skeleton

- **Status:** ✅ Completed
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 1 — Foundation and Repository Baseline`
- **Story points:** 5
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:live`, `mvp:1`, `sprint:1`, `priority:P0`, `status:completed-retro`

### Outcome

Establish the real-time lecture worker, room lifecycle and pluggable TTS/STT interfaces.

### What needs to be done?

- [x] Create LiveKit room/worker bootstrap.
- [x] Define TTS and STT provider interfaces.
- [x] Add local provider configuration for Kokoro/Piper and faster-whisper.
- [x] Document required credentials and hardware assumptions.

### Definition of Done / acceptance criteria

- [x] Worker starts in a configured development environment.
- [x] Missing LiveKit credentials fail explicitly rather than silently.
- [x] TTS/STT providers can be swapped through configuration.
- [x] Health/status output identifies unavailable dependencies.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S1-05 — Create exam service, persistence and API foundation

- **Status:** ✅ Completed
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 1 — Foundation and Repository Baseline`
- **Story points:** 5
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:1`, `sprint:1`, `priority:P0`, `status:completed-retro`

### Outcome

Establish the exam service, MongoDB persistence and core assessment API boundaries.

### What needs to be done?

- [x] Create exam application/service structure.
- [x] Define assessment, attempt, answer and result records.
- [x] Connect MongoDB with environment-based configuration.
- [x] Expose health and baseline CRUD endpoints.

### Definition of Done / acceptance criteria

- [x] Exam service starts against local MongoDB.
- [x] Assessment and attempt records can be created and read.
- [x] Payload validation rejects malformed requests.
- [x] No score is trusted directly from an unvalidated client payload.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S1-06 — Define exam UX contracts and baseline QA harness

- **Status:** ✅ Completed
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 1 — Foundation and Repository Baseline`
- **Story points:** 5
- **Issue template:** `task`
- **Labels:** `task`, `area:exam`, `mvp:1`, `sprint:1`, `priority:P0`, `status:completed-retro`

### Outcome

Define the learner-facing exam flow and a repeatable test harness for the initial exam APIs.

### What needs to be done?

- [x] Document start, answer, submit, result and appeal states.
- [x] Create representative quiz and midterm fixtures.
- [x] Add API smoke tests for happy and invalid paths.
- [x] Record expected ownership boundaries between App and Exam repositories.

### Definition of Done / acceptance criteria

- [x] Fixtures cover quiz and midterm shapes.
- [x] Smoke tests can be executed with one documented command.
- [x] Expected status/error codes are recorded.
- [x] UI/API contract is accepted by App and Exam owners.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


# MVP 1 · Sprint 2 — Core Learning Slice


## UAI-M1-S2-01 — Implement virtual clock and shared course-state contracts

- **Status:** ✅ Completed
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 2 — Core Learning Slice`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:core`, `mvp:1`, `sprint:2`, `priority:P0`, `status:completed-retro`

### Outcome

Provide the accelerated academic clock and shared contracts required by App, Agent and Exam.

### What needs to be done?

- [x] Define course, week, lecture and virtual-time records.
- [x] Implement deterministic clock progression and reset controls.
- [x] Expose shared time/state through documented APIs or shared data access.
- [x] Add seed data and failure recovery instructions.

### Definition of Done / acceptance criteria

- [x] All subsystems observe the same virtual course time.
- [x] A four-week semester can be advanced and reset deterministically.
- [x] Clock state survives the intended persistence lifecycle.
- [x] Race conditions or invalid transitions are handled explicitly.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S2-02 — Implement upload, schedule, dashboard and admin workflows

- **Status:** ✅ Completed
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 2 — Core Learning Slice`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:app`, `mvp:1`, `sprint:2`, `priority:P0`, `status:completed-retro`

### Outcome

Build the primary UI workflows for book upload, generated schedule, attendance dashboard and local administration.

### What needs to be done?

- [x] Build validated PDF upload with progress and error states.
- [x] Render the generated weekly schedule and lecture states.
- [x] Render attendance totals and learner dashboard summaries.
- [x] Add local admin controls for course generation and clock management.

### Definition of Done / acceptance criteria

- [x] Valid uploads reach the generation API and invalid files are rejected.
- [x] Schedule changes reflect the shared virtual clock.
- [x] Dashboard totals match stored attendance records.
- [x] Admin controls are clearly marked as local-demo controls where authentication is absent.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S2-03 — Implement MCP ingestion, hybrid retrieval and citations

- **Status:** ✅ Completed
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 2 — Core Learning Slice`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:agent`, `mvp:1`, `sprint:2`, `priority:P0`, `status:completed-retro`

### Outcome

Expose stable tools for ingestion and grounded retrieval with page-aware citations.

### What needs to be done?

- [x] Implement ingest_file, retrieve_context, list_documents and remove_document tools.
- [x] Combine dense retrieval with lexical/keyword retrieval.
- [x] Add reranking and metadata filters.
- [x] Return source document, page and section metadata with retrieved context.

### Definition of Done / acceptance criteria

- [x] All four MCP tools have typed inputs/outputs and documented errors.
- [x] Answers can cite the originating book and page/section.
- [x] Retrieval refuses or degrades safely when no relevant context exists.
- [x] The service includes repeatable retrieval smoke tests.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S2-04 — Implement pre-recorded lecture playback and grounded Q&A

- **Status:** ✅ Completed
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 2 — Core Learning Slice`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:live`, `mvp:1`, `sprint:2`, `priority:P0`, `status:completed-retro`

### Outcome

Deliver lecture audio and allow a learner to interrupt through a raise-hand flow that uses grounded retrieval.

### What needs to be done?

- [x] Implement lecture audio/slide event sequencing.
- [x] Implement raise-hand, pause, question capture and resume states.
- [x] Call Agent retrieval for question context.
- [x] Synthesize the grounded answer and record interaction metadata.

### Definition of Done / acceptance criteria

- [x] Lecture playback has deterministic pause/resume behaviour.
- [x] A question produces an answer or an explicit grounded refusal.
- [x] Source identity is preserved through the Q&A call chain.
- [x] Provider failures do not corrupt the room state.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S2-05 — Implement assessment weighting, grading and result webhook

- **Status:** ✅ Completed
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 2 — Core Learning Slice`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:1`, `sprint:2`, `priority:P0`, `status:completed-retro`

### Outcome

Implement the initial academic scoring model and return trusted results to the main application.

### What needs to be done?

- [x] Implement quiz and midterm assessment types.
- [x] Apply the agreed 90/10 grading composition.
- [x] Validate submitted answers server-side and compute scores.
- [x] Send signed/validated result callbacks to the integration layer.

### Definition of Done / acceptance criteria

- [x] A known fixture produces the expected score.
- [x] Client-supplied total scores are ignored.
- [x] Duplicate submissions are idempotent or rejected safely.
- [x] Result callbacks include attempt identity and integrity metadata.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S2-06 — Implement exam-taking UI, observable proctor events and appeal entry

- **Status:** ✅ Completed
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 2 — Core Learning Slice`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:1`, `sprint:2`, `priority:P0`, `status:completed-retro`

### Outcome

Provide a usable exam flow that records observable events without making an autonomous cheating accusation.

### What needs to be done?

- [x] Build or integrate question navigation, answer persistence and submission states.
- [x] Record camera disabled, face missing/multiple faces and tab-switch events where supported.
- [x] Show policy-based warnings and session-state changes.
- [x] Provide an appeal entry point after an invalidated or flagged attempt.

### Definition of Done / acceptance criteria

- [x] Learner answers persist across normal navigation.
- [x] Observable events are timestamped and auditable.
- [x] The UI never labels a learner as a cheater based solely on automation.
- [x] Appeal data can be submitted and associated with an attempt.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


# MVP 1 · Sprint 3 — Cross-Repository Integration


## UAI-M1-S3-01 — Orchestrate generation, persistence and subsystem failover

- **Status:** ✅ Completed
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 3 — Cross-Repository Integration`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:core`, `mvp:1`, `sprint:3`, `priority:P0`, `status:completed-retro`

### Outcome

Connect the subsystem contracts into a single course-generation and learning workflow.

### What needs to be done?

- [x] Implement orchestration for upload, ingestion, generation and persistence.
- [x] Define correlation IDs and idempotency boundaries.
- [x] Add retry/fallback behaviour for unavailable AI dependencies.
- [x] Persist generation status and actionable error details.

### Definition of Done / acceptance criteria

- [x] A generation request reaches a terminal success or explicit failure state.
- [x] Retries do not duplicate courses or assessments.
- [x] Subsystem errors are traceable by a shared correlation ID.
- [x] Local fallback behaviour is documented and tested.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S3-02 — Integrate lecture room, token endpoint and assessment callbacks

- **Status:** ✅ Completed
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 3 — Cross-Repository Integration`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:app`, `mvp:1`, `sprint:3`, `priority:P0`, `status:completed-retro`

### Outcome

Connect the learner interface to live lecture rooms and trusted assessment result updates.

### What needs to be done?

- [x] Implement LiveKit token request and room join UI.
- [x] Connect lecture state to the shared course/clock model.
- [x] Trigger and display exam sessions from the schedule.
- [x] Receive/refetch trusted results and update dashboard progress.

### Definition of Done / acceptance criteria

- [x] Unconfigured LiveKit access is refused with a clear message.
- [x] Room state and lecture state remain consistent.
- [x] Assessment completion updates the learner dashboard.
- [x] Loading, failure and retry states are visible.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S3-03 — Generate structured course plans, lecture assets and assessments

- **Status:** ✅ Completed
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 3 — Cross-Repository Integration`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:agent`, `mvp:1`, `sprint:3`, `priority:P0`, `status:completed-retro`

### Outcome

Generate schema-valid learning artefacts grounded in the indexed book.

### What needs to be done?

- [x] Create structured schemas for course plan, lecture, slide/script and assessment outputs.
- [x] Generate four weeks of lectures from the book structure.
- [x] Generate lecture assets and assessment blueprints with source references.
- [x] Add validation, repair and deterministic fallback paths.

### Definition of Done / acceptance criteria

- [x] Generated output validates against published schemas.
- [x] Every generated learning item carries source provenance.
- [x] Invalid model output is repaired or rejected explicitly.
- [x] The same request does not silently create conflicting duplicate artefacts.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S3-04 — Implement room worker and raise-hand interaction protocol

- **Status:** ✅ Completed
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 3 — Cross-Repository Integration`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:live`, `mvp:1`, `sprint:3`, `priority:P0`, `status:completed-retro`

### Outcome

Make live-room state transitions reliable across audio playback, interruption and grounded response generation.

### What needs to be done?

- [x] Implement participant join/leave and room lifecycle handling.
- [x] Synchronise playback events with lecture segments/slides.
- [x] Implement raise-hand queue, acknowledgement and turn completion.
- [x] Record latency and failure state for each interaction step.

### Definition of Done / acceptance criteria

- [x] Only authorised room participants receive room events.
- [x] A raise-hand interaction pauses and resumes the correct lecture segment.
- [x] Concurrent or repeated hand raises are queued or rejected predictably.
- [x] Interaction logs are sufficient to diagnose failures.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S3-05 — Implement suspicion scoring and integrity report contracts

- **Status:** ✅ Completed
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 3 — Cross-Repository Integration`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:1`, `sprint:3`, `priority:P0`, `status:completed-retro`

### Outcome

Aggregate observable proctor events into an explainable risk record while retaining human review responsibility.

### What needs to be done?

- [x] Define event types, severity weights and policy thresholds.
- [x] Compute risk/session actions from recorded events.
- [x] Produce an integrity report with event timeline and reasons.
- [x] Separate automated session enforcement from a human misconduct decision.

### Definition of Done / acceptance criteria

- [x] Risk is reproducible from the stored event sequence.
- [x] Reports show which events affected the score or session action.
- [x] No API field declares cheating as an autonomous model verdict.
- [x] Policy values are configurable and versioned.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S3-06 — Execute and document full-system API and manual E2E tests

- **Status:** ✅ Completed
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 3 — Cross-Repository Integration`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:1`, `sprint:3`, `priority:P0`, `status:completed-retro`

### Outcome

Create a repeatable end-to-end verification pack spanning all five repositories.

### What needs to be done?

- [x] Create a seeded happy-path scenario.
- [x] Exercise upload, generation, lecture, Q&A, attendance, exam and result flows.
- [x] Record expected payloads, screenshots/logs and known environment limitations.
- [x] Open defects with reproduction steps and route them to the correct repository.

### Definition of Done / acceptance criteria

- [x] The scenario can be followed by a developer unfamiliar with the implementation.
- [x] Every subsystem boundary is exercised at least once.
- [x] Known credential/hardware blockers are distinguished from code failures.
- [x] Blocking defects are linked to an owner and resolution decision.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


# MVP 1 · Sprint 4 — Acceptance Record and Handoff


## UAI-M1-S4-01 — Publish one-command setup, architecture and acceptance baseline

- **Status:** ✅ Completed
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 4 — Acceptance Record and Handoff`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:1`, `sprint:4`, `priority:P0`, `status:completed-retro`

### Outcome

Consolidate startup, architecture, repository mapping and MVP1 acceptance evidence in the integration repository.

### What needs to be done?

- [x] Publish RUNNING, ARCHITECTURE and ACCEPTANCE documents.
- [x] Record exact verified date and environment assumptions.
- [x] Add issue templates and the project-board automation workflow.
- [x] Document submodule update and integration procedures.

### Definition of Done / acceptance criteria

- [x] A new developer can reach the documented baseline from a recursive clone.
- [x] Acceptance claims distinguish verified, failed and not-tested items.
- [x] Open issues automatically enter the project board when workflow credentials are present.
- [x] Closing an issue moves its project item to Done.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S4-02 — Verify application build, attendance and dashboard acceptance

- **Status:** ✅ Completed
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 4 — Acceptance Record and Handoff`
- **Story points:** 5
- **Issue template:** `task`
- **Labels:** `task`, `area:app`, `mvp:1`, `sprint:4`, `priority:P0`, `status:completed-retro`

### Outcome

Record repeatable application-level evidence for the MVP1 routes and core learner state.

### What needs to be done?

- [x] Run production build and strict type checks.
- [x] Verify route rendering and MUI implementation constraints.
- [x] Verify lecture state and attendance transitions against virtual time.
- [x] Verify dashboard totals against seeded records.

### Definition of Done / acceptance criteria

- [x] Build completes successfully with the recorded route set.
- [x] Attendance on-time/late/absent scenarios are evidenced.
- [x] Dashboard totals reconcile with source records.
- [x] Known local-admin authentication limitation is documented.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S4-03 — Publish Agent MCP contract and baseline verification

- **Status:** ✅ Completed
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 4 — Acceptance Record and Handoff`
- **Story points:** 5
- **Issue template:** `task`
- **Labels:** `task`, `area:agent`, `mvp:1`, `sprint:4`, `priority:P0`, `status:completed-retro`

### Outcome

Freeze the Agent tool contract and document the retrieval/generation checks available at the MVP1 boundary.

### What needs to be done?

- [x] Document MCP tools, schemas and error behaviour.
- [x] Record supported ingestion and retrieval paths.
- [x] Add baseline smoke-test commands.
- [x] Create a known-gap list for credential/model-dependent checks.

### Definition of Done / acceptance criteria

- [x] Tool documentation matches executable schemas.
- [x] Smoke tests fail clearly when dependencies are unavailable.
- [x] Citation and grounded-refusal expectations are stated.
- [x] Unverified quality claims are not marked as passed.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S4-04 — Publish Live credential, hardware and integration readiness record

- **Status:** ✅ Completed
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 4 — Acceptance Record and Handoff`
- **Story points:** 5
- **Issue template:** `task`
- **Labels:** `task`, `area:live`, `mvp:1`, `sprint:4`, `priority:P0`, `status:completed-retro`

### Outcome

Document the live subsystem's executable baseline and clearly isolate checks blocked by credentials or hardware.

### What needs to be done?

- [x] Document LiveKit, TTS and STT setup requirements.
- [x] Record expected room, playback and raise-hand flows.
- [x] Add health checks and troubleshooting steps.
- [x] List unverified real-audio, latency, barge-in and synchronisation gates.

### Definition of Done / acceptance criteria

- [x] Missing credentials produce explicit refusal/diagnostics.
- [x] Setup instructions identify required services and models.
- [x] Blocked tests are listed as blocked rather than passed.
- [x] Ownership for carrying each blocked gate forward is recorded.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S4-05 — Publish Exam integration and integrity acceptance record

- **Status:** ✅ Completed
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 4 — Acceptance Record and Handoff`
- **Story points:** 5
- **Issue template:** `task`
- **Labels:** `task`, `area:exam`, `mvp:1`, `sprint:4`, `priority:P0`, `status:completed-retro`

### Outcome

Freeze the exam API, scoring and integrity-policy baseline for MVP1.

### What needs to be done?

- [x] Document assessment and attempt API contracts.
- [x] Verify server-side scoring and result callback behaviour.
- [x] Record observable proctor events and policy actions.
- [x] Document appeal and human-review principles.

### Definition of Done / acceptance criteria

- [x] Known fixtures produce expected scores.
- [x] No client-provided final score is accepted blindly.
- [x] Integrity reporting distinguishes event detection from misconduct judgment.
- [x] Known limitations and future hardening work are listed.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


## UAI-M1-S4-06 — Audit full-system acceptance evidence and known gaps

- **Status:** ✅ Completed
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 1 — Integrated Autonomous Semester Baseline`
- **Sprint:** `MVP 1 / Sprint 4 — Acceptance Record and Handoff`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:1`, `sprint:4`, `priority:P0`, `status:completed-retro`

### Outcome

Independently reconcile subsystem evidence into the final MVP1 pass/not-tested record.

### What needs to be done?

- [x] Review evidence from all repository owners.
- [x] Re-run feasible happy-path and negative-path checks.
- [x] Record credential/hardware-dependent checks separately.
- [x] Create or link carry-forward issues for every unresolved gate.

### Definition of Done / acceptance criteria

- [x] Every MVP1 acceptance line has an owner and evidence/status.
- [x] No blocked item is represented as verified.
- [x] Carry-forward work is mapped to MVP2-MVP6 or an explicit backlog.
- [x] Product Owner signs off the baseline snapshot.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [x] Linked implementation PR or documentation commit.
- [x] Relevant automated test output or reproducible manual test evidence.
- [x] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [x] Reviewer approval and integrated demo evidence.


# MVP 2 · Sprint 1 — Multi-Book Ingestion and Collection Model


## UAI-M2-S1-01 — Define source-collection, programme and document contracts

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 1 — Multi-Book Ingestion and Collection Model`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:core`, `mvp:2`, `sprint:1`, `priority:P0`
- **Existing issue:** Reuse/expand existing Core issue #5 (ERD).

### Outcome

Introduce the shared data model that separates source collections, programmes, semesters, courses and individual books.

### What needs to be done?

- [ ] Extend the ERD and API contracts for collection and document identities.
- [ ] Define ingestion-job states and idempotency keys.
- [ ] Define ownership and lifecycle events across Core, App and Agent.
- [ ] Plan backward compatibility for existing single-book courses.

### Definition of Done / acceptance criteria

- [ ] ERD and schema review are accepted by Core, App and Agent owners.
- [ ] Every book is addressable independently within a collection.
- [ ] Single-book data has a documented migration path.
- [ ] Repeated upload requests cannot silently duplicate the same item.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M2-S1-02 — Build multi-file upload and source-library management UI

- **Status:** ⬜ Planned
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 1 — Multi-Book Ingestion and Collection Model`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:app`, `mvp:2`, `sprint:1`, `priority:P0`

### Outcome

Replace the single-upload assumption with a collection-oriented upload and management experience.

### What needs to be done?

- [ ] Support drag-and-drop and selection of multiple books.
- [ ] Show per-file validation, progress, success and failure states.
- [ ] Build source library with rename, remove, retry and preview metadata actions.
- [ ] Require confirmation for destructive actions after curriculum generation.

### Definition of Done / acceptance criteria

- [ ] A collection can contain multiple valid books.
- [ ] One failed item does not hide the status of successful items.
- [ ] Retry does not duplicate successful documents.
- [ ] Library state is restored after navigation or refresh.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M2-S1-03 — Implement batch ingestion and collection-aware metadata

- **Status:** ⬜ Planned
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 1 — Multi-Book Ingestion and Collection Model`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:agent`, `mvp:2`, `sprint:1`, `priority:P0`

### Outcome

Ingest multiple books concurrently or sequentially with robust job tracking and source isolation.

### What needs to be done?

- [ ] Extend ingestion tools to accept collection identity and multiple documents.
- [ ] Extract title, author, table-of-contents and structural metadata where available.
- [ ] Store document/page/section identity on every chunk.
- [ ] Implement retry, cancellation and partial-success semantics.

### Definition of Done / acceptance criteria

- [ ] A batch reports status for every input document.
- [ ] Retrieval can filter by collection and document.
- [ ] Partial failures preserve successful indexed documents.
- [ ] Removing a document removes only its own vectors and metadata.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M2-S1-04 — Preserve book identity in spoken answers and citations

- **Status:** ⬜ Planned
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 1 — Multi-Book Ingestion and Collection Model`
- **Story points:** 5
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:live`, `mvp:2`, `sprint:1`, `priority:P0`

### Outcome

Make source identity understandable when a live answer draws from a multi-book collection.

### What needs to be done?

- [ ] Extend Q&A payloads with document title and location.
- [ ] Define concise spoken citation formatting.
- [ ] Expose full citation metadata to the App while keeping spoken output natural.
- [ ] Handle answers supported by more than one book.

### Definition of Done / acceptance criteria

- [ ] A learner can identify which book supports an answer.
- [ ] Multiple-source answers preserve each source reference.
- [ ] Missing source metadata causes a grounded refusal or explicit warning.
- [ ] Spoken and visual citation identities agree.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M2-S1-05 — Add multi-book assessment provenance schema

- **Status:** ⬜ Planned
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 1 — Multi-Book Ingestion and Collection Model`
- **Story points:** 5
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:2`, `sprint:1`, `priority:P0`

### Outcome

Track which source material supports each generated assessment item.

### What needs to be done?

- [ ] Add source collection, document and page/section references to questions.
- [ ] Validate provenance payloads received from Agent.
- [ ] Persist provenance with immutable attempt snapshots.
- [ ] Expose source references in admin review without revealing answers prematurely.

### Definition of Done / acceptance criteria

- [ ] Every generated question has valid provenance or is rejected.
- [ ] Attempt history retains the question version and source references used.
- [ ] Deleting a source does not corrupt historical attempt records.
- [ ] Learner-facing exposure follows assessment policy.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M2-S1-06 — Create multi-book contract and ingestion test matrix

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 1 — Multi-Book Ingestion and Collection Model`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:2`, `sprint:1`, `priority:P0`

### Outcome

Prove collection lifecycle and failure behaviour across App, Core, Agent and Exam.

### What needs to be done?

- [ ] Create fixtures for one, several, duplicate, corrupted and oversized books.
- [ ] Test partial failure, retry, removal and idempotency.
- [ ] Verify collection/document filters in retrieval.
- [ ] Verify provenance survives question generation and attempt creation.

### Definition of Done / acceptance criteria

- [ ] The matrix covers at least ten representative scenarios.
- [ ] Each scenario has expected status and evidence.
- [ ] Defects are routed to the owning repository.
- [ ] No destructive collection action occurs without an explicit policy decision.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


# MVP 2 · Sprint 2 — Curriculum Intelligence and Semester Planning


## UAI-M2-S2-01 — Implement programme, semester and course orchestration

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 2 — Curriculum Intelligence and Semester Planning`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:core`, `mvp:2`, `sprint:2`, `priority:P0`

### Outcome

Persist approved multi-semester plans and orchestrate downstream generation by course and semester.

### What needs to be done?

- [ ] Implement programme/semester/course CRUD and status transitions.
- [ ] Store planner version, assumptions and approval record.
- [ ] Coordinate generation jobs per approved course.
- [ ] Prevent schedule activation before explicit approval.

### Definition of Done / acceptance criteria

- [ ] One collection can produce one or several semesters.
- [ ] Plan revisions create traceable versions.
- [ ] Generation is tied to an approved version.
- [ ] Failure of one course does not silently corrupt the entire programme.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M2-S2-02 — Build curriculum review, edit and approval workspace

- **Status:** ⬜ Planned
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 2 — Curriculum Intelligence and Semester Planning`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:app`, `mvp:2`, `sprint:2`, `priority:P0`

### Outcome

Give the learner visibility and control over the AI-proposed curriculum before expensive generation begins.

### What needs to be done?

- [ ] Visualise semester/course hierarchy and source coverage.
- [ ] Show overlap decisions, prerequisite edges and workload rationale.
- [ ] Allow reorder, merge, split, rename and exclusion within policy.
- [ ] Require explicit approval and show regeneration consequences.

### Definition of Done / acceptance criteria

- [ ] Learner can understand why content was merged or sequenced.
- [ ] Valid edits are persisted as a new plan version.
- [ ] Invalid prerequisite order is blocked or clearly warned.
- [ ] Approval produces an immutable generation target.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M2-S2-03 — Implement overlap, prerequisite and workload planning agent

- **Status:** ⬜ Planned
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 2 — Curriculum Intelligence and Semester Planning`
- **Story points:** 13
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:agent`, `mvp:2`, `sprint:2`, `priority:P0`

### Outcome

Analyse the source collection and produce a structured, evidence-backed curriculum plan.

### What needs to be done?

- [ ] Detect duplicated, overlapping and complementary topics.
- [ ] Infer prerequisite relationships with supporting source locations.
- [ ] Estimate workload and number of semesters under configurable constraints.
- [ ] Produce schema-valid programme, semester and course objects with confidence/rationale.

### Definition of Done / acceptance criteria

- [ ] A one-book collection can still produce a valid one-semester plan.
- [ ] Overlapping content is not needlessly repeated without rationale.
- [ ] Prerequisite edges cite supporting source structures or text.
- [ ] Planner output is validated and can be reviewed before generation.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M2-S2-04 — Schedule live delivery across courses and semesters

- **Status:** ⬜ Planned
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 2 — Curriculum Intelligence and Semester Planning`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:live`, `mvp:2`, `sprint:2`, `priority:P0`

### Outcome

Make lecture delivery room/session creation aware of programme, semester and course identity.

### What needs to be done?

- [ ] Extend room/session metadata with programme hierarchy.
- [ ] Create lecture sessions from approved course schedules.
- [ ] Prevent joining content outside active progression rules.
- [ ] Preserve source/course identity in recordings and interactions.

### Definition of Done / acceptance criteria

- [ ] Room events identify the correct programme, semester, course and lecture.
- [ ] Schedule changes propagate without orphaning existing records.
- [ ] Access outside the active schedule follows a documented policy.
- [ ] Interaction logs remain queryable by course.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M2-S2-05 — Generate assessment blueprints across course outcomes

- **Status:** ⬜ Planned
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 2 — Curriculum Intelligence and Semester Planning`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:2`, `sprint:2`, `priority:P0`

### Outcome

Plan assessments against course outcomes and source coverage rather than generating isolated questions.

### What needs to be done?

- [ ] Define learning-outcome and assessment-blueprint contracts.
- [ ] Map questions to outcomes, difficulty and source coverage.
- [ ] Validate blueprint distribution before publishing an exam.
- [ ] Support independent course-level grading within a semester.

### Definition of Done / acceptance criteria

- [ ] Every published assessment satisfies its blueprint constraints.
- [ ] Coverage can be audited by outcome and source.
- [ ] Difficulty distribution is explicit and configurable.
- [ ] Course grades do not leak across programme boundaries.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M2-S2-06 — Run multi-book curriculum E2E acceptance

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 2 — Multi-Book Curriculum Intelligence`
- **Sprint:** `MVP 2 / Sprint 2 — Curriculum Intelligence and Semester Planning`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:2`, `sprint:2`, `priority:P0`

### Outcome

Validate that multiple books become a defensible approved programme rather than a concatenated content dump.

### What needs to be done?

- [ ] Create collections representing duplicate, complementary and prerequisite-heavy cases.
- [ ] Compare planner output against a human-authored expected structure.
- [ ] Exercise review/edit/approval and downstream generation.
- [ ] Record quality, latency and failure evidence.

### Definition of Done / acceptance criteria

- [ ] At least three representative collections pass the end-to-end path.
- [ ] Known wrong merges or prerequisite errors are logged and triaged.
- [ ] Approved version identity is preserved through generation.
- [ ] MVP2 exit metrics and known limitations are published.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


# MVP 3 · Sprint 1 — Coursework and Progression


## UAI-M3-S1-01 — Implement academic activity and progression policy engine

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 1 — Coursework and Progression`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:core`, `mvp:3`, `sprint:1`, `priority:P1`

### Outcome

Define the event and policy layer that decides when a learner may progress.

### What needs to be done?

- [ ] Define activity, submission, participation and completion events.
- [ ] Implement configurable progression rules and exemptions.
- [ ] Publish events consumed by App, Agent, Live and Exam.
- [ ] Add deterministic replay/recalculation for learner progress.

### Definition of Done / acceptance criteria

- [ ] Progress is derived from auditable events.
- [ ] Policy changes are versioned and do not rewrite history silently.
- [ ] A learner can see why a gate is open or closed.
- [ ] Reprocessing the same event is idempotent.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M3-S1-02 — Build coursework, submission and progress UI

- **Status:** ⬜ Planned
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 1 — Coursework and Progression`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:app`, `mvp:3`, `sprint:1`, `priority:P1`

### Outcome

Provide learner workflows for assignments, labs, homework, deadlines, submissions and progression status.

### What needs to be done?

- [ ] Build course task list and detail views.
- [ ] Support text/file submissions as permitted by task type.
- [ ] Show deadlines, attempts, feedback and gate requirements.
- [ ] Add instructor/admin override UI with reason capture.

### Definition of Done / acceptance criteria

- [ ] Learner can submit each supported task type.
- [ ] Submission states survive refresh and failed network calls.
- [ ] Gate requirements and unmet conditions are visible.
- [ ] Overrides require authorised role and an audit reason.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M3-S1-03 — Generate grounded assignments, labs and homework

- **Status:** ⬜ Planned
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 1 — Coursework and Progression`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:agent`, `mvp:3`, `sprint:1`, `priority:P1`

### Outcome

Generate practical academic activities that align with course outcomes and cited source material.

### What needs to be done?

- [ ] Define schemas for homework, assignment and lab activities.
- [ ] Generate instructions, expected evidence, rubric and source grounding.
- [ ] Apply difficulty and estimated-time constraints.
- [ ] Validate unsafe or impossible generated tasks before publication.

### Definition of Done / acceptance criteria

- [ ] Activities map to explicit course outcomes.
- [ ] Rubrics are machine-readable and human-readable.
- [ ] Source grounding is retained for generation and review.
- [ ] Invalid outputs are blocked rather than published automatically.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M3-S1-04 — Capture participation and interruption evidence

- **Status:** ⬜ Planned
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 1 — Coursework and Progression`
- **Story points:** 5
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:live`, `mvp:3`, `sprint:1`, `priority:P1`

### Outcome

Convert meaningful live interactions into auditable participation events without rewarding noise.

### What needs to be done?

- [ ] Define attendance and participation event contracts.
- [ ] Record join duration, lecture completion and valid Q&A turns.
- [ ] Attach transcript/source references where policy permits.
- [ ] Publish events to the progression engine.

### Definition of Done / acceptance criteria

- [ ] Participation events are attributable to learner and lecture.
- [ ] Repeated joins do not inflate completion incorrectly.
- [ ] Sensitive audio/transcript retention follows configured policy.
- [ ] Progression can distinguish attendance from meaningful participation.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M3-S1-05 — Implement coursework grading and rubric services

- **Status:** ⬜ Planned
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 1 — Coursework and Progression`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:3`, `sprint:1`, `priority:P1`

### Outcome

Grade objective and rubric-based coursework with traceable evidence and human override.

### What needs to be done?

- [ ] Implement submission ingestion and rubric evaluation contracts.
- [ ] Support deterministic grading for objective components.
- [ ] Use AI-assisted rubric scoring only with evidence and confidence.
- [ ] Provide manual review/override and immutable audit history.

### Definition of Done / acceptance criteria

- [ ] Objective fixtures grade deterministically.
- [ ] AI-assisted scores include rubric criteria and evidence.
- [ ] Low-confidence or policy-sensitive cases enter human review.
- [ ] Overrides preserve original and final values with reasons.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M3-S1-06 — Test progression gates and grading consistency

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 1 — Coursework and Progression`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:3`, `sprint:1`, `priority:P1`

### Outcome

Verify academic rules across attendance, coursework, grading, retries and overrides.

### What needs to be done?

- [ ] Build scenarios for pass, fail, late, missing, excused and overridden activities.
- [ ] Verify progress recalculation after each event.
- [ ] Check rubric score consistency against fixtures.
- [ ] Test learner-visible explanations and admin audit records.

### Definition of Done / acceptance criteria

- [ ] At least twelve progression scenarios are automated or reproducibly manual.
- [ ] No learner is advanced by duplicate events.
- [ ] Every blocked state has a learner-visible reason.
- [ ] Grade overrides are fully auditable.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


# MVP 3 · Sprint 2 — Academic Record, Remediation and Human Review


## UAI-M3-S2-01 — Implement gradebook, transcript, retake and make-up policies

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 2 — Academic Record, Remediation and Human Review`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:core`, `mvp:3`, `sprint:2`, `priority:P1`

### Outcome

Create the authoritative academic record and semester-completion policy.

### What needs to be done?

- [ ] Define weighted gradebook and course/semester completion records.
- [ ] Implement retake, make-up and excused-absence policies.
- [ ] Generate transcript snapshots with policy/version metadata.
- [ ] Prevent historical records from being rewritten without audit.

### Definition of Done / acceptance criteria

- [ ] Course and semester grades reconcile from source activities.
- [ ] Retake policy produces deterministic final-grade treatment.
- [ ] Transcript snapshots are immutable and traceable.
- [ ] Completion status can be recalculated from event history.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M3-S2-02 — Build gradebook, feedback, appeal and review interfaces

- **Status:** ⬜ Planned
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 2 — Academic Record, Remediation and Human Review`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:app`, `mvp:3`, `sprint:2`, `priority:P1`

### Outcome

Expose academic results and review workflows clearly to learners and authorised reviewers.

### What needs to be done?

- [ ] Build learner gradebook and transcript views.
- [ ] Show rubric feedback, remediation requirements and retake eligibility.
- [ ] Build appeal submission/status flow.
- [ ] Build reviewer queue and decision form with evidence timeline.

### Definition of Done / acceptance criteria

- [ ] Learner can trace each grade to its activity.
- [ ] Appeals have clear status and timestamps.
- [ ] Reviewer actions require role and reason.
- [ ] Sensitive integrity evidence is not exposed beyond policy.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M3-S2-03 — Generate personalised remediation and feedback plans

- **Status:** ⬜ Planned
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 2 — Academic Record, Remediation and Human Review`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:agent`, `mvp:3`, `sprint:2`, `priority:P1`

### Outcome

Use grounded performance evidence to recommend targeted study and practice rather than generic advice.

### What needs to be done?

- [ ] Aggregate missed outcomes and weak rubric criteria.
- [ ] Retrieve supporting sections from the learner's source collection.
- [ ] Generate a structured remediation plan with tasks and success checks.
- [ ] Avoid unsupported diagnosis or punitive language.

### Definition of Done / acceptance criteria

- [ ] Every recommendation maps to performance evidence and source material.
- [ ] Plan output validates against the published schema.
- [ ] Learner can see measurable completion criteria.
- [ ] Low-evidence cases produce conservative guidance.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M3-S2-04 — Implement tracked make-up lecture and replay sessions

- **Status:** ⬜ Planned
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 2 — Academic Record, Remediation and Human Review`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:live`, `mvp:3`, `sprint:2`, `priority:P1`

### Outcome

Allow policy-approved replay or make-up sessions while preserving attendance and completion integrity.

### What needs to be done?

- [ ] Create make-up/replay session types and access tokens.
- [ ] Track playback progress and required interactions.
- [ ] Publish completion events to the progression engine.
- [ ] Prevent repeated replay from duplicating credit.

### Definition of Done / acceptance criteria

- [ ] Only eligible learners can enter restricted make-up sessions.
- [ ] Completion requires configured evidence, not merely opening the room.
- [ ] Events are idempotent and auditable.
- [ ] Replay accessibility does not expose unrelated course content.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M3-S2-05 — Implement human-in-the-loop integrity review

- **Status:** ⬜ Planned
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 2 — Academic Record, Remediation and Human Review`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:3`, `sprint:2`, `priority:P1`

### Outcome

Turn risk reports into an explicit reviewer decision process with appeal support.

### What needs to be done?

- [ ] Create review queue, evidence bundle and policy-version snapshot.
- [ ] Support clear, uphold, invalidate and request-more-information decisions.
- [ ] Require reviewer identity and rationale.
- [ ] Link appeals and subsequent decisions without deleting history.

### Definition of Done / acceptance criteria

- [ ] Automation may warn or enforce session policy but does not independently declare cheating.
- [ ] Every final misconduct/invalidation decision has a human reviewer or explicit institutional rule.
- [ ] Decision and appeal history is immutable.
- [ ] Learner-facing language is factual and non-accusatory.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M3-S2-06 — Validate multi-semester records, remediation and appeals

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 3 — Complete Academic Journey`
- **Sprint:** `MVP 3 / Sprint 2 — Academic Record, Remediation and Human Review`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:3`, `sprint:2`, `priority:P1`

### Outcome

Exercise complete academic-record and human-review workflows across semester boundaries.

### What needs to be done?

- [ ] Create learner histories with passes, failures, retakes and make-up work.
- [ ] Reconcile gradebook and transcript snapshots.
- [ ] Run flagged-exam review and appeal scenarios.
- [ ] Verify authorisation and evidence visibility boundaries.

### Definition of Done / acceptance criteria

- [ ] Historical grades remain stable after later policy changes.
- [ ] Retake and remediation paths end in expected progression states.
- [ ] Appeal decisions preserve complete history.
- [ ] MVP3 academic lifecycle is demonstrated end to end.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


# MVP 4 · Sprint 1 — Hierarchical Agents and Evaluation Foundation


## UAI-M4-S1-01 — Define orchestration contracts, tool registry and task tracking

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 1 — Hierarchical Agents and Evaluation Foundation`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:core`, `mvp:4`, `sprint:1`, `priority:P1`

### Outcome

Provide the platform contracts and persistence needed for multi-agent execution and auditing.

### What needs to be done?

- [ ] Define agent task, handoff, tool-call and result schemas.
- [ ] Create a versioned tool registry with permissions and timeout limits.
- [ ] Persist task state, correlation, retries and terminal outcomes.
- [ ] Expose safe status APIs to App and operators.

### Definition of Done / acceptance criteria

- [ ] Every agent action is attributable to a task and tool version.
- [ ] Unavailable tools fail within bounded time.
- [ ] Retry and cancellation states are explicit.
- [ ] Sensitive reasoning is not exposed as raw private chain-of-thought.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M4-S1-02 — Build source panel, confidence and feedback UI

- **Status:** ⬜ Planned
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 1 — Hierarchical Agents and Evaluation Foundation`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:app`, `mvp:4`, `sprint:1`, `priority:P1`

### Outcome

Make AI output inspectable through citations, source context, confidence cues and user feedback.

### What needs to be done?

- [ ] Add citation bubbles and source-document side panel.
- [ ] Display calibrated status/confidence language where available.
- [ ] Add thumbs up/down, issue flag and explain-more actions.
- [ ] Show generation/retrieval trace summaries suitable for end users.

### Definition of Done / acceptance criteria

- [ ] A citation opens the correct book location or closest available context.
- [ ] Feedback is stored with output/version identity.
- [ ] Confidence wording does not claim certainty unsupported by metrics.
- [ ] No private internal reasoning trace is exposed.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M4-S1-03 — Implement hierarchical agent graph and structured handoffs

- **Status:** ⬜ Planned
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 1 — Hierarchical Agents and Evaluation Foundation`
- **Story points:** 13
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:agent`, `mvp:4`, `sprint:1`, `priority:P1`

### Outcome

Implement manager-worker orchestration for curriculum, lecture and assessment generation.

### What needs to be done?

- [ ] Implement Manager, Curriculum, Lecture and Assessment agent nodes.
- [ ] Define structured input/output schemas and handoff rules.
- [ ] Restrict each agent to an explicit tool set.
- [ ] Add validation, reflection and bounded replanning for failed outputs.

### Definition of Done / acceptance criteria

- [ ] A task follows an observable graph with deterministic terminal states.
- [ ] Workers cannot call tools outside their registry permissions.
- [ ] Invalid handoffs are rejected before downstream persistence.
- [ ] Replanning is bounded by configured cost/time limits.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M4-S1-04 — Instrument live Q&A tool calls, latency and cost

- **Status:** ⬜ Planned
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 1 — Hierarchical Agents and Evaluation Foundation`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:live`, `mvp:4`, `sprint:1`, `priority:P1`
- **Existing issue:** Reuse/expand existing Live issue #1 (dashboard for own testing).

### Outcome

Expose operational evidence for the real-time AI path without degrading the learner experience.

### What needs to be done?

- [ ] Attach trace/correlation IDs to room interactions.
- [ ] Measure STT, retrieval, generation, TTS and total latency.
- [ ] Record model/token/provider usage where available.
- [ ] Build or extend a developer dashboard for live-path testing.

### Definition of Done / acceptance criteria

- [ ] Each Q&A turn has a complete timing breakdown.
- [ ] Failures identify the failing stage and provider.
- [ ] Metrics contain no unnecessary raw audio or sensitive text.
- [ ] Dashboard supports the current Live developer test workflow.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M4-S1-05 — Define safe Assessment Agent interface and boundaries

- **Status:** ⬜ Planned
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 1 — Hierarchical Agents and Evaluation Foundation`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:4`, `sprint:1`, `priority:P1`

### Outcome

Allow an assessment agent to propose content while keeping publishing, scoring and integrity actions controlled.

### What needs to be done?

- [ ] Define tools for blueprint lookup, draft-question creation and validation.
- [ ] Separate draft generation from publication.
- [ ] Apply schema, provenance and policy checks.
- [ ] Require human or rule-based approval for high-impact changes.

### Definition of Done / acceptance criteria

- [ ] Agent cannot publish an exam or alter a grade directly.
- [ ] Every draft records model, prompt and source provenance.
- [ ] Unsafe or invalid content is rejected with reasons.
- [ ] Tool calls are visible in the shared trace model.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M4-S1-06 — Build 50-case grounded evaluation dataset

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 1 — Hierarchical Agents and Evaluation Foundation`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:4`, `sprint:1`, `priority:P1`

### Outcome

Create the minimum regression dataset required to measure retrieval, generation and agent-task quality.

### What needs to be done?

- [ ] Select representative English and Arabic source excerpts.
- [ ] Create at least 50 questions/tasks with expected sources and rubric outcomes.
- [ ] Include answerable, unanswerable, ambiguous and adversarial cases.
- [ ] Version fixtures and define human review procedure.

### Definition of Done / acceptance criteria

- [ ] Dataset contains at least 50 reviewed cases.
- [ ] Ground truth includes expected source locations or refusal behaviour.
- [ ] Cases cover curriculum, lecture, Q&A and assessment outputs.
- [ ] A repeatable runner produces machine-readable results.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


# MVP 4 · Sprint 2 — Observability, Guardrails and Continuous Quality


## UAI-M4-S2-01 — Integrate central AI observability and cost attribution

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 2 — Observability, Guardrails and Continuous Quality`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:core`, `mvp:4`, `sprint:2`, `priority:P1`

### Outcome

Connect one observability platform and define consistent trace, metric and alert contracts.

### What needs to be done?

- [ ] Select and configure Langfuse, LangSmith or equivalent.
- [ ] Instrument request, agent, retrieval, model and tool spans.
- [ ] Capture latency, token/cost, errors and task outcomes.
- [ ] Define retention, redaction and access controls.

### Definition of Done / acceptance criteria

- [ ] A cross-repository request is visible as one correlated trace.
- [ ] Cost and latency can be attributed by subsystem and model.
- [ ] Sensitive values are redacted before export.
- [ ] Alerts exist for error-rate, latency or cost threshold breaches.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M4-S2-02 — Implement feedback, retry and explain-more workflows

- **Status:** ⬜ Planned
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 2 — Observability, Guardrails and Continuous Quality`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:app`, `mvp:4`, `sprint:2`, `priority:P1`

### Outcome

Convert learner feedback into traceable quality signals and controlled regeneration actions.

### What needs to be done?

- [ ] Persist rating, issue category and optional comment.
- [ ] Implement retry with previous-output/version linkage.
- [ ] Implement explain-more without losing citation context.
- [ ] Show clear state when fallback or degraded output is used.

### Definition of Done / acceptance criteria

- [ ] Feedback links to the exact output and trace.
- [ ] Retry creates a new version without erasing prior output.
- [ ] Explain-more remains grounded in sources.
- [ ] Degraded mode is visible rather than silently substituted.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M4-S2-03 — Implement retrieval evaluation, prompt registry and query transformation

- **Status:** ⬜ Planned
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 2 — Observability, Guardrails and Continuous Quality`
- **Story points:** 13
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:agent`, `mvp:4`, `sprint:2`, `priority:P1`

### Outcome

Measure and improve RAG quality through versioned prompts and at least one advanced retrieval strategy.

### What needs to be done?

- [ ] Create central prompt templates with version identifiers.
- [ ] Implement query decomposition/multi-query or another approved advanced strategy.
- [ ] Calculate context precision/recall, MRR, faithfulness and answer relevancy.
- [ ] Support controlled prompt/retrieval A/B comparisons.

### Definition of Done / acceptance criteria

- [ ] Evaluation runner reports metrics by version.
- [ ] At least two retrieval strategies are implemented, including semantic retrieval.
- [ ] Advanced retrieval is enabled only where it improves the agreed dataset.
- [ ] Regression thresholds block clearly worse releases.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M4-S2-04 — Implement live-path fallback and latency budgets

- **Status:** ⬜ Planned
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 2 — Observability, Guardrails and Continuous Quality`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:live`, `mvp:4`, `sprint:2`, `priority:P1`

### Outcome

Keep lecture interaction usable when speech or model providers are slow or unavailable.

### What needs to be done?

- [ ] Define stage-level latency budgets and timeouts.
- [ ] Implement retries with backoff and circuit breakers.
- [ ] Add text-only or deferred-answer fallback paths.
- [ ] Expose fallback reason to App and observability.

### Definition of Done / acceptance criteria

- [ ] No provider call can block a room indefinitely.
- [ ] Fallback is deterministic and visible.
- [ ] Room playback remains recoverable after a failed question.
- [ ] Latency SLO evidence is recorded for representative hardware.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M4-S2-05 — Harden exam AI inputs, outputs and rate limits

- **Status:** ⬜ Planned
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 2 — Observability, Guardrails and Continuous Quality`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:4`, `sprint:2`, `priority:P1`

### Outcome

Protect assessment generation and integrity endpoints from prompt injection, malformed output and abuse.

### What needs to be done?

- [ ] Sanitise untrusted source/user content before prompt use.
- [ ] Validate all model outputs against strict schemas.
- [ ] Apply per-user/session rate and action limits.
- [ ] Log blocked attempts without exposing protected prompts.

### Definition of Done / acceptance criteria

- [ ] Known prompt-injection fixtures are blocked or neutralised.
- [ ] Malformed generated questions never reach publication.
- [ ] Rate limits return consistent and documented responses.
- [ ] Logs support audit without storing secrets.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M4-S2-06 — Automate adversarial and regression quality gates

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 4 — Agentic Quality and Observability`
- **Sprint:** `MVP 4 / Sprint 2 — Observability, Guardrails and Continuous Quality`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:4`, `sprint:2`, `priority:P1`

### Outcome

Turn the evaluation dataset into a release gate and quality dashboard.

### What needs to be done?

- [ ] Add jailbreak, injection, unsupported-answer and multilingual cases.
- [ ] Run evaluations in CI with mocked and controlled real-model modes.
- [ ] Publish trend reports and failing-case details.
- [ ] Define ownership and waiver process for regressions.

### Definition of Done / acceptance criteria

- [ ] CI produces a versioned evaluation report.
- [ ] Critical safety/grounding failures block release.
- [ ] Model-dependent flaky checks are isolated and documented.
- [ ] Waivers require owner, reason and expiry.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


# MVP 5 · Sprint 1 — Security, Identity and Multi-User Isolation


## UAI-M5-S1-01 — Implement identity, RBAC, tenancy and data lifecycle

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 1 — Security, Identity and Multi-User Isolation`
- **Story points:** 13
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:core`, `mvp:5`, `sprint:1`, `priority:P0`

### Outcome

Create the authoritative authentication/authorisation and privacy-control layer.

### What needs to be done?

- [ ] Integrate an identity provider or secure in-house auth decision.
- [ ] Define learner, reviewer and admin roles with least privilege.
- [ ] Add tenant/user ownership to domain records and APIs.
- [ ] Implement consent, retention, export and deletion workflows.

### Definition of Done / acceptance criteria

- [ ] Unauthenticated requests cannot access protected APIs.
- [ ] Users cannot read or mutate another user's programme data.
- [ ] Privileged actions are audited.
- [ ] Deletion/retention behaviour is documented and testable.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M5-S1-02 — Build authentication, onboarding, account and consent UX

- **Status:** ⬜ Planned
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 1 — Security, Identity and Multi-User Isolation`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:app`, `mvp:5`, `sprint:1`, `priority:P0`

### Outcome

Replace local-only admin access with explicit user and role-aware application flows.

### What needs to be done?

- [ ] Build sign-in/sign-out and session-expiry states.
- [ ] Build learner onboarding and consent capture.
- [ ] Build account data export/deletion controls.
- [ ] Hide or disable actions the current role cannot perform.

### Definition of Done / acceptance criteria

- [ ] Protected routes redirect or reject correctly.
- [ ] Session expiry does not expose stale private data.
- [ ] Consent version and timestamp are visible to the user.
- [ ] Deletion requires confirmation and reports completion/status.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M5-S1-03 — Implement tenant-scoped retrieval, PII redaction and guardrails

- **Status:** ⬜ Planned
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 1 — Security, Identity and Multi-User Isolation`
- **Story points:** 13
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:agent`, `mvp:5`, `sprint:1`, `priority:P0`

### Outcome

Prevent cross-user retrieval and reduce sensitive-data exposure in AI inputs, traces and outputs.

### What needs to be done?

- [ ] Namespace/filter vectors by owner and collection.
- [ ] Propagate authenticated identity through tool calls.
- [ ] Detect/redact configured PII before external model or observability calls.
- [ ] Add input/output policy guardrails and audit events.

### Definition of Done / acceptance criteria

- [ ] Cross-tenant retrieval tests return no foreign chunks.
- [ ] Tool calls reject missing or mismatched identity.
- [ ] Configured PII is redacted before third-party transmission.
- [ ] Guardrail decisions are explainable and logged.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M5-S1-04 — Authorise rooms and enforce audio privacy lifecycle

- **Status:** ⬜ Planned
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 1 — Security, Identity and Multi-User Isolation`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:live`, `mvp:5`, `sprint:1`, `priority:P0`

### Outcome

Protect live sessions, tokens, audio and transcripts according to user/course policy.

### What needs to be done?

- [ ] Issue short-lived scoped room tokens.
- [ ] Validate learner/course/session eligibility.
- [ ] Define recording/transcript consent and retention settings.
- [ ] Delete or anonymise live artefacts through the central lifecycle workflow.

### Definition of Done / acceptance criteria

- [ ] A token cannot join an unrelated room.
- [ ] Expired or replayed tokens are rejected.
- [ ] Recording state and consent are visible.
- [ ] Deletion removes or anonymises covered live artefacts.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M5-S1-05 — Secure exam sessions, actions and integrity evidence

- **Status:** ⬜ Planned
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 1 — Security, Identity and Multi-User Isolation`
- **Story points:** 13
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:5`, `sprint:1`, `priority:P0`

### Outcome

Enforce authenticated exam attempts, least-privilege review and tamper-evident audit records.

### What needs to be done?

- [ ] Bind attempt tokens to learner, assessment and time window.
- [ ] Protect answer, submit, review and decision endpoints by role.
- [ ] Add nonce/idempotency and replay protections.
- [ ] Make integrity evidence and decisions tamper-evident.

### Definition of Done / acceptance criteria

- [ ] A token cannot be reused for another learner or exam.
- [ ] Learners cannot access reviewer-only evidence or actions.
- [ ] Repeated submissions are handled safely.
- [ ] Audit verification detects unauthorised record changes.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M5-S1-06 — Create threat model and automated security test pack

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 1 — Security, Identity and Multi-User Isolation`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:5`, `sprint:1`, `priority:P0`

### Outcome

Document trust boundaries and verify the highest-risk abuse cases across all repositories.

### What needs to be done?

- [ ] Create data-flow/threat diagrams covering auth, RAG, Live and Exam.
- [ ] Map controls to OWASP web and LLM risks.
- [ ] Test horizontal/vertical access control, injection, replay and secret leakage.
- [ ] Run dependency and secret scans in CI.

### Definition of Done / acceptance criteria

- [ ] Threat model is reviewed by every subsystem owner.
- [ ] Critical access-control tests are automated.
- [ ] CI reports dependency and secret-scan results.
- [ ] No unresolved critical vulnerability is accepted for MVP5 exit.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


# MVP 5 · Sprint 2 — Arabic, Accessibility and Full QA


## UAI-M5-S2-01 — Define localisation, content-language and accessibility contracts

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 2 — Arabic, Accessibility and Full QA`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:5`, `sprint:2`, `priority:P0`

### Outcome

Standardise locale, direction, language fallback and accessible content metadata across services.

### What needs to be done?

- [ ] Define locale/direction fields and API negotiation.
- [ ] Define source-language, generated-language and learner-preference rules.
- [ ] Add translation-key ownership and missing-key policy.
- [ ] Publish accessibility requirements for generated artefacts.

### Definition of Done / acceptance criteria

- [ ] All repositories use the same supported locale identifiers.
- [ ] Fallback language behaviour is deterministic.
- [ ] Generated content records its source and output language.
- [ ] Contracts support RTL and accessible labels/descriptions.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M5-S2-02 — Implement English/Arabic RTL, responsive and WCAG AA UI

- **Status:** ⬜ Planned
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 2 — Arabic, Accessibility and Full QA`
- **Story points:** 13
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:app`, `mvp:5`, `sprint:2`, `priority:P0`

### Outcome

Make the learner/admin experience usable in English and Arabic across device sizes and assistive technologies.

### What needs to be done?

- [ ] Localise product text and implement runtime direction switching.
- [ ] Audit keyboard navigation, focus, ARIA, contrast and text scaling.
- [ ] Fix mobile/tablet layouts and responsive source/lecture/exam panels.
- [ ] Add PWA/offline-shell behaviour where safe and useful.

### Definition of Done / acceptance criteria

- [ ] Core flows work in LTR and RTL without layout breakage.
- [ ] Keyboard-only completion is possible for primary workflows.
- [ ] Automated accessibility checks have no critical violations.
- [ ] Responsive checks cover agreed mobile, tablet and desktop sizes.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M5-S2-03 — Implement Arabic retrieval, generation and dialect evaluation

- **Status:** ⬜ Planned
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 2 — Arabic, Accessibility and Full QA`
- **Story points:** 13
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:agent`, `mvp:5`, `sprint:2`, `priority:P0`

### Outcome

Support Arabic books and queries while measuring grounding and language quality.

### What needs to be done?

- [ ] Select multilingual embeddings/models and document rationale.
- [ ] Normalise Arabic text without destroying source citation offsets.
- [ ] Support Arabic query transformation and answer generation.
- [ ] Add MSA and representative colloquial Egyptian cases to evaluation.

### Definition of Done / acceptance criteria

- [ ] Arabic retrieval meets agreed benchmark thresholds.
- [ ] Citations resolve to the correct Arabic source location.
- [ ] The system handles mixed Arabic/English queries predictably.
- [ ] Model limitations and dialect coverage are documented.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M5-S2-04 — Implement Arabic/English STT, TTS and voice selection

- **Status:** ⬜ Planned
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 2 — Arabic, Accessibility and Full QA`
- **Story points:** 13
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:live`, `mvp:5`, `sprint:2`, `priority:P0`

### Outcome

Deliver understandable bilingual lecture and Q&A speech paths with measured latency.

### What needs to be done?

- [ ] Add language detection/selection policy.
- [ ] Configure Arabic and English STT/TTS providers or models.
- [ ] Handle mixed-language terms and technical vocabulary.
- [ ] Benchmark intelligibility, latency and fallback behaviour.

### Definition of Done / acceptance criteria

- [ ] Learner can select or confirm lecture voice language.
- [ ] Representative Arabic questions transcribe accurately enough for retrieval.
- [ ] Technical terms are not silently mistranslated without fallback.
- [ ] Benchmarks and known hardware limits are published.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M5-S2-05 — Implement bilingual assessment rendering and content checks

- **Status:** ⬜ Planned
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 2 — Arabic, Accessibility and Full QA`
- **Story points:** 8
- **Issue template:** `enhancement`
- **Labels:** `enhancement`, `area:exam`, `mvp:5`, `sprint:2`, `priority:P0`

### Outcome

Support Arabic/English questions, answers, timing and integrity messaging without semantic drift.

### What needs to be done?

- [ ] Store assessment locale and direction metadata.
- [ ] Render RTL question navigation and mixed-language content.
- [ ] Validate translated/generated question equivalence where applicable.
- [ ] Localise warnings, review status and appeal language.

### Definition of Done / acceptance criteria

- [ ] Arabic assessments remain usable under timed conditions.
- [ ] Question/answer semantics are preserved across supported language paths.
- [ ] Integrity messages remain factual and non-accusatory.
- [ ] Exported results preserve correct Unicode and direction metadata.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M5-S2-06 — Build 60% coverage, E2E and accessibility release gate

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 5 — Secure Bilingual Multi-User Product`
- **Sprint:** `MVP 5 / Sprint 2 — Arabic, Accessibility and Full QA`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:5`, `sprint:2`, `priority:P0`

### Outcome

Create the full automated QA baseline required before production deployment.

### What needs to be done?

- [ ] Add unit/component coverage collection across repositories.
- [ ] Create Playwright/Cypress end-to-end flows for primary journeys.
- [ ] Add API integration, accessibility and cross-browser checks.
- [ ] Mock LLMs by default and isolate controlled real-model tests.

### Definition of Done / acceptance criteria

- [ ] Targeted backend/frontend code reaches at least 60% coverage or has approved exclusions.
- [ ] Primary English and Arabic E2E journeys pass in CI.
- [ ] Critical accessibility failures block merge.
- [ ] Flaky tests have owners and are not silently ignored.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


# MVP 6 · Sprint 1 — Cloud Release Engineering


## UAI-M6-S1-01 — Implement production orchestration, CI/CD, secrets and rollback

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 1 — Cloud Release Engineering`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:6`, `sprint:1`, `priority:P0`

### Outcome

Create the production deployment path and operational controls for the complete system.

### What needs to be done?

- [ ] Create multi-stage images and production Compose/orchestration definitions.
- [ ] Implement CI build, test, scan, migration and deployment jobs.
- [ ] Configure managed secrets, TLS, least-privilege identities and environment separation.
- [ ] Add health checks, structured logs, uptime monitoring, backup and rollback runbooks.

### Definition of Done / acceptance criteria

- [ ] A tagged release can deploy from a clean CI runner.
- [ ] Failed health checks stop or roll back deployment.
- [ ] No production secret appears in repository or CI logs.
- [ ] Restore and rollback procedures are tested and timed.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M6-S1-02 — Harden and deploy the web application

- **Status:** ⬜ Planned
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 1 — Cloud Release Engineering`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:app`, `mvp:6`, `sprint:1`, `priority:P0`

### Outcome

Produce the optimised production web build and deployment configuration.

### What needs to be done?

- [ ] Configure production API/origin settings and secure headers.
- [ ] Optimise static assets, lazy loading and caching.
- [ ] Add frontend error monitoring and source-map policy.
- [ ] Create post-deploy smoke tests for critical routes.

### Definition of Done / acceptance criteria

- [ ] Production build has no blocking warnings/errors.
- [ ] Security headers and HTTPS are verified.
- [ ] Critical routes pass smoke tests after deployment.
- [ ] Client errors are observable without exposing sensitive data.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M6-S1-03 — Deploy scalable RAG services, indexes and backups

- **Status:** ⬜ Planned
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 1 — Cloud Release Engineering`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:agent`, `mvp:6`, `sprint:1`, `priority:P0`

### Outcome

Package and deploy the Agent service with durable vector data, caching and controlled model fallbacks.

### What needs to be done?

- [ ] Create production image and startup/migration checks.
- [ ] Configure Qdrant persistence, snapshots and restore procedure.
- [ ] Add embedding/query caching and bounded concurrency.
- [ ] Configure primary/fallback models with cost and availability controls.

### Definition of Done / acceptance criteria

- [ ] Agent restarts without losing indexed collections.
- [ ] Snapshot restore is demonstrated.
- [ ] Concurrency limits prevent resource exhaustion.
- [ ] Fallback choice and cost are visible in traces.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M6-S1-04 — Deploy Live worker, media dependencies and health checks

- **Status:** ⬜ Planned
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 1 — Cloud Release Engineering`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:live`, `mvp:6`, `sprint:1`, `priority:P0`

### Outcome

Package the real-time worker and speech models for the selected production infrastructure.

### What needs to be done?

- [ ] Create deployable worker image and model acquisition strategy.
- [ ] Configure LiveKit credentials, network/media requirements and autoscaling decision.
- [ ] Add readiness/liveness checks for speech providers.
- [ ] Measure production-like room concurrency and recovery.

### Definition of Done / acceptance criteria

- [ ] Worker can join and serve a staging room.
- [ ] Unavailable speech dependency fails readiness or uses approved fallback.
- [ ] Secrets are injected at runtime.
- [ ] Capacity and hardware assumptions are documented.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M6-S1-05 — Deploy exam service, durable data and recovery controls

- **Status:** ⬜ Planned
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 1 — Cloud Release Engineering`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:exam`, `mvp:6`, `sprint:1`, `priority:P0`

### Outcome

Deploy the exam system with secure persistence, backups and operational health controls.

### What needs to be done?

- [ ] Create production image and database index/migration process.
- [ ] Configure MongoDB authentication, encryption and backup.
- [ ] Add liveness/readiness and dependency checks.
- [ ] Test restore, duplicate callback and in-flight attempt recovery.

### Definition of Done / acceptance criteria

- [ ] Service survives restart without losing valid attempts.
- [ ] Backup restore is demonstrated in staging.
- [ ] Health checks distinguish service and dependency failures.
- [ ] In-flight recovery follows a documented learner-safe policy.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M6-S1-06 — Run load, reliability and disaster-recovery acceptance

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 1 — Cloud Release Engineering`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:6`, `sprint:1`, `priority:P0`

### Outcome

Verify release-candidate behaviour under expected demo/pilot load and representative failures.

### What needs to be done?

- [ ] Define expected concurrency and performance budgets.
- [ ] Run k6/Locust or equivalent load scenarios.
- [ ] Inject model, database, network and worker failures.
- [ ] Execute backup restore and rollback drills.

### Definition of Done / acceptance criteria

- [ ] Results include latency, throughput and error-rate evidence.
- [ ] No critical data-loss scenario remains unresolved.
- [ ] Recovery objectives and capacity limits are published.
- [ ] Release candidate is accepted or rejected against explicit thresholds.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


# MVP 6 · Sprint 2 — Submission, Pilot and Final Acceptance


## UAI-M6-S2-01 — Freeze release, technical documentation and submission checklist

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @DevAbdoTolba — Abdo Tolba
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 2 — Submission, Pilot and Final Acceptance`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:6`, `sprint:2`, `priority:P0`

### Outcome

Own the final release decision and consolidate all technical and capstone deliverables.

### What needs to be done?

- [ ] Freeze versioned architecture, ERD, OpenAPI, deployment and configuration documentation.
- [ ] Create operations runbook, contributor guide, changelog and known-issues register.
- [ ] Verify repository access, clean setup and release tags.
- [ ] Coordinate pitch deck, business case, live-demo script and submission checklist.

### Definition of Done / acceptance criteria

- [ ] All mandatory deliverables are linked from the main README.
- [ ] A clean environment can follow setup and deployment docs.
- [ ] Known limitations are transparent and severity-ranked.
- [ ] Product Owner signs the final release/submission checklist.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M6-S2-02 — Complete onboarding, user guide and presentation polish

- **Status:** ⬜ Planned
- **Repository:** `abdalrahmanalirajab/UnivAI-app`
- **Area:** App
- **Assignee:** @abdalrahmanalirajab — Abdalrhman Ali Ragab
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 2 — Submission, Pilot and Final Acceptance`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:app`, `mvp:6`, `sprint:2`, `priority:P0`

### Outcome

Make the production application understandable to first-time pilot users and presentation-ready.

### What needs to be done?

- [ ] Polish onboarding and empty/error states.
- [ ] Create screenshot-based English/Arabic user guide.
- [ ] Add contextual help and troubleshooting links.
- [ ] Run final visual, responsive and accessibility regression.

### Definition of Done / acceptance criteria

- [ ] A first-time user can complete the primary journey without team assistance.
- [ ] Guide screenshots match the released UI.
- [ ] No critical responsive/accessibility regression remains.
- [ ] Demo mode uses production behaviour rather than hidden manual shortcuts.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M6-S2-03 — Publish model rationale, evaluation report and AI limitations

- **Status:** ⬜ Planned
- **Repository:** `AhmeedFatehy/UnivAI-Agent`
- **Area:** Agent
- **Assignee:** @AhmeedFatehy — Ahmed Fathi Heshmat
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 2 — Submission, Pilot and Final Acceptance`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:agent`, `mvp:6`, `sprint:2`, `priority:P0`

### Outcome

Produce the evidence needed to defend model, RAG and agent design decisions.

### What needs to be done?

- [ ] Document primary/fallback model and embedding choices.
- [ ] Publish retrieval, generation and agent evaluation results.
- [ ] Document prompt versions, cost/latency benchmarks and failure modes.
- [ ] State grounding, Arabic and unsupported-content limitations.

### Definition of Done / acceptance criteria

- [ ] Evaluation report is reproducible from versioned fixtures.
- [ ] Claims are supported by measured results.
- [ ] Limitations and mitigation paths are explicit.
- [ ] Final release references exact model/prompt/config versions.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M6-S2-04 — Prepare resilient live-demo and audio fallback package

- **Status:** ⬜ Planned
- **Repository:** `muhameedhanyyy/UnivAI-live`
- **Area:** Live
- **Assignee:** @muhameedhanyyy — Mohamed Hany
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 2 — Submission, Pilot and Final Acceptance`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:live`, `mvp:6`, `sprint:2`, `priority:P0`

### Outcome

Make the live lecture segment reliable in the final demonstration while preserving honesty about fallback.

### What needs to be done?

- [ ] Create a timed live-demo runbook.
- [ ] Pre-warm models and verify staging credentials/hardware.
- [ ] Prepare an approved recorded fallback for external-service failure.
- [ ] Capture latency and success evidence from final rehearsal.

### Definition of Done / acceptance criteria

- [ ] Team can run the live segment within the allotted demo time.
- [ ] Fallback is disclosed and does not fake a successful live call.
- [ ] Final rehearsal logs are archived.
- [ ] Recovery steps are executable by another team member.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M6-S2-05 — Publish exam integrity policy, reviewer guide and known limits

- **Status:** ⬜ Planned
- **Repository:** `AhmedSamirKhalaf/UnivAI-exam_system`
- **Area:** Exam
- **Assignee:** @AhmedSamirKhalaf — Ahmed Samir Khalaf
- **Reviewer:** @Youssefmo7 — Youssef Mohamed
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 2 — Submission, Pilot and Final Acceptance`
- **Story points:** 8
- **Issue template:** `task`
- **Labels:** `task`, `area:exam`, `mvp:6`, `sprint:2`, `priority:P0`

### Outcome

Document how assessments, proctor events, human review and appeals operate in the released product.

### What needs to be done?

- [ ] Publish scoring and assessment policy.
- [ ] Publish observable-event, warning, invalidation and human-review policy.
- [ ] Create reviewer/appeal guide with screenshots or examples.
- [ ] Document false-positive risks, privacy controls and unsupported conditions.

### Definition of Done / acceptance criteria

- [ ] Policy matches executable configuration.
- [ ] Reviewers can reach a decision from the guide and evidence bundle.
- [ ] Documentation never states that AI alone proves cheating.
- [ ] Known limitations are linked from learner-facing terms/help.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.


## UAI-M6-S2-06 — Run UAT, pilot, demo recording and final evidence audit

- **Status:** ⬜ Planned
- **Repository:** `DevAbdoTolba/UnivAi`
- **Area:** Core
- **Assignee:** @Youssefmo7 — Youssef Mohamed
- **Reviewer:** @DevAbdoTolba — Abdo Tolba
- **Milestone:** `MVP 6 — Cloud Release and Capstone Evidence`
- **Sprint:** `MVP 6 / Sprint 2 — Submission, Pilot and Final Acceptance`
- **Story points:** 13
- **Issue template:** `task`
- **Labels:** `task`, `area:core`, `mvp:6`, `sprint:2`, `priority:P0`

### Outcome

Independently validate the final product and assemble traceable acceptance evidence.

### What needs to be done?

- [ ] Run UAT with representative learners/reviewers.
- [ ] Record defects, usability findings and release decisions.
- [ ] Verify the complete requirements checklist against evidence links.
- [ ] Coordinate and verify the 3–5 minute demo video and final QA charts.

### Definition of Done / acceptance criteria

- [ ] All release blockers are fixed or explicitly rejected with rationale.
- [ ] Requirements checklist maps each claim to evidence.
- [ ] Demo video shows the real released workflow.
- [ ] Final acceptance report includes metrics, known issues and sign-off.

### Dependencies

- The sprint entry criteria and prior-MVP gate are satisfied.
- Any API/schema dependency is linked to its owning repository issue or accepted contract.
- Assignee and reviewer are different accounts.

### Required closure evidence

- [ ] Linked implementation PR or documentation commit.
- [ ] Relevant automated test output or reproducible manual test evidence.
- [ ] Updated API/ERD/sequence/wireframe documentation when behaviour changed.
- [ ] Reviewer approval and integrated demo evidence.
