# Sprint 3 grounded learning-flow contracts

Sprint 3 uses versioned, strict JSON contracts. The canonical schemas are in
`docs/contracts/schemas/`; executable examples are in
`tests/fixtures/sprint3/`. Producers must validate before publishing and
consumers must validate before changing state. Unknown fields are rejected.

## Ownership and trust boundaries

- App authenticates the learner, owns collection membership, exact-version
  approval, schedules, and learner-facing orchestration.
- Agent owns parsing, indexing, prerequisite proposals, section generation,
  and all assessment question generation.
- Exam never generates, repairs, or substitutes questions. It validates an
  `AssessmentPackageV1` and returns a `PublicationReceiptV1`.
- Live consumes immutable lecture/section artifacts, signed learner metadata,
  and prompt manifests. It does not infer missing teaching content.
- Core owns these contracts, fixtures, persistence wiring, and cross-service
  smoke gates. Core does not implement component production behavior.

Source text, filenames, client IDs, model output, and provider callbacks are
untrusted. Every mutation is authenticated, tenant-authorized, idempotent,
audited, and bound to an exact approved plan/path version.

## Contract catalog

| Contract | Version | Purpose |
|---|---|---|
| ContentArtifact | `content-artifact-v1` | Immutable content-addressed RAG artifact, keyed by original-byte SHA-256 and the complete pipeline fingerprint. |
| TenantDocumentGrant | `tenant-document-grant-v1` | Tenant-owned authorization to use one artifact; artifact reuse never creates access. |
| LearningPathV1 | `learning-path-v1` | Ordered books, chapter-reset boundaries, evidence-backed prerequisite edges, warnings, and exact approval state. |
| SemesterWeekPlan | `semester-week-plan-v1` | Dynamic contiguous weeks and ordered lecture/section schedule items. |
| SectionPackV1 | `section-pack-v1` | Grounded worked examples and actionable TODOs separate from lecture narration. |
| SectionSessionMetaV1 | `section-session-meta-v1` | Exact learner/plan/lecture/section binding and resumable activity state for Live. |
| AssessmentPackage | `assessment-package-v1` with `quiz-package-v1`, `midterm-package-v1`, or `final-package-v1` discriminator | Agent-generated quiz, midterm, or final with blueprint, prompt trace, hashes, keys/rubrics, scope, and per-item provenance. |
| PublicationReceipt | `publication-receipt-v1` | Exam's atomic accepted/rejected result and machine-readable defects. |
| PersonalizedPromptManifestV1 | `personalized-prompt-manifest-v1` | Opaque per-account/version audio-cache identity and checksummed fixed-template clips. |
| SignedSpokenNameMetadataV1 | `signed-spoken-name-metadata-v1` | Short-lived signed safe spoken name bound to learner, session, plan version, and nonce. |
| StartupTraceV1 | `startup-trace-v1` | Ordered monotonic Live startup stages and raw measured/mock origin. |
| CrossServiceEnvelopeV1 | `cross-service-envelope-v1` | Authentication, tenant, idempotency, audit, trace, provenance, payload, and explicit error envelope. |

## Non-negotiable invariants

### Multi-book reuse and tenancy

`ContentArtifact.content_key` is calculated by the Agent from the original
bytes; client hashes and filenames are never trusted. The pipeline fingerprint
contains parser, chunker, embedding model, vector schema, and contract versions.
Any fingerprint change creates a different artifact.

Retrieval authorizes an active `TenantDocumentGrant` for the requesting tenant
on every query. A cache hit is private telemetry and is not returned to another
tenant. Revoking one grant cannot delete an artifact with another active grant;
last-reference cleanup is auditable and retry-safe.

### Path approval and dynamic scheduling

Every prerequisite edge cites both the prerequisite and dependent evidence.
The graph must be acyclic, all ordered document IDs must be unique, and every
book starts at its own chapter 1 only after all prerequisite books finish.
Cycles, confidence below `0.80`, missing evidence, unresolved alternatives, or
a stale version block approval. Overrides create a new version and require an
audit reason.

Weeks are contiguous from 1 to `week_count`; there is exactly one lecture per
week. A section is optional, has `session_type: "section"`, references an
approved SectionPack, and immediately follows its lecture. Counts are derived
from the plan; no four-week default is valid.

### Grounded sections and assessments

Every worked-example step and every TODO has resolved document/page/section and
passage IDs. Missing evidence refuses publication. Section completion is
explicit and separate from lecture attendance; resume state identifies the
exact activity and step.

Each assessment item is immutable and includes an item hash, approved plan/path
version, blueprint version, generator prompt ID/version, objectives, and source
provenance. Quiz scope is one approved week. Midterm scope contains completed
weeks only. Final scope is the complete approved semester. Exam returns defects
instead of writing or repairing content. Client-facing question delivery must
strip keys, rubrics, future questions, and private provenance.

### Personalization and startup evidence

The App derives the safe spoken name from its authenticated account, signs it,
and binds it to learner, session, plan version, nonce, issue time, and expiry.
The prompt cache key uses an opaque learner ID plus normalized-name digest,
language, voice/model/version, sample rate, and phrase-set version. Raw names,
emails, phones, and tokens never appear in cache paths or normal metrics.

`StartupTraceV1` stage times are monotonic and derived from a monotonic clock.
Mock traces test ordering only and never satisfy the SLO. Integrated acceptance
requires at least 30 raw `measured` cold and 30 raw `measured` warm traces from
target hardware. Warm ready p95 must be at most 2,000 ms and cold ready p95 at
most 5,000 ms; an unready run must fail visibly by 8,000 ms. If evidence is
missing or a budget is missed, Sprint 3 remains `PARTIAL`.

## Stable service boundaries

All mutation requests carry `CrossServiceEnvelopeV1` and an HTTP
`Idempotency-Key` equal to `envelope.idempotency.key`.

| Producer -> consumer | Boundary | Contract |
|---|---|---|
| App -> Agent | `PUT /v1/content-artifacts/{content_key}/grants/{document_id}` | TenantDocumentGrantV1 |
| Agent -> App | `POST /v1/learning-paths/{path_id}/versions` | LearningPathV1 |
| App -> Core | `POST /v1/learning-paths/{path_id}/versions/{version}/approval` | LearningPathV1 exact version |
| Agent -> App/Live | `PUT /v1/section-packs/{section_pack_id}` | SectionPackV1 |
| App -> Live | signed room metadata | SectionSessionMetaV1 + SignedSpokenNameMetadataV1 |
| Agent -> Exam | `POST /v1/assessment-publications` | AssessmentPackageV1 |
| Exam -> Agent/App | response/callback | PublicationReceiptV1 |
| App -> Live | `POST /v1/personalized-prompts/prewarm` | PersonalizedPromptManifestV1 |
| Live -> Core | `POST /v1/startup-traces` | StartupTraceV1 |

Errors never use success-shaped payloads. The shared error object contains a
stable code, safe message, retryability, and structured details. The same
tenant/idempotency key reserves a request hash and deterministic response; a
different hash is `IDEMPOTENCY_KEY_REUSED` and does not execute.

## Validation and rollout

```bash
make contract-check
node scripts/sprint3-smoke.mjs --mode mock
python -m pytest tests/contracts -q
```

Mock mode validates contracts and deterministic negative paths only. It does
not claim that a component endpoint, model, LiveKit room, or latency SLO works.

After all linked component PRs are merged and the real stack is configured:

```bash
make up
make status
node scripts/sprint3-smoke.mjs --mode integrated
```

Integrated mode requires real endpoint responses and a path containing 60 raw
measured startup traces. Every unavailable dependency is reported with its
exact blocker; it is never converted to PASS.
