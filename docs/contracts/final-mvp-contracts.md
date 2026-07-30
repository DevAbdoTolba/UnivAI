# Final MVP programme contracts

Contract versions:

- `source-collection-v1`
- `programme-plan-v1`
- `programme-generation-job-v1`

The Python contracts are the validation authority. The JSON Schemas publish the
same field names plus committed valid and invalid Day-1 fixtures under
`examples` and `x-invalidExamples`.

## Source collection

A source collection belongs to one `owner_id` and contains one or many source
documents. It does not assign a book to a semester. A programme plan may use
parts of several documents in one course or use one document across semesters.

Every document carries its own ingestion status, error and timestamps.
`SourceCollection.status` becomes `ready` only when every document is `ready`.
A failed document makes the collection fail with the same explicit error.

## Programme plan

`ProgrammePlan` contains:

```text
ProgrammePlan
  Semester[]
    Course[]
      LectureOutline[]
      AssessmentOutline[]
```

Each lecture and assessment has document IDs, page ranges and section names.
Output without this source coverage is refused. Workload and confidence exist
at the useful planning levels, and course prerequisites use stable course IDs.

Edits create a new version with `parent_plan_version` equal to the immediately
previous version. Approval must name the latest exact `plan_version`. Approval
adds `approved_by` and `approved_at`; that stored version is immutable and is
the version referenced by downstream generation.

## Generation states

The only normal path is:

```text
queued -> ingesting -> planning -> awaiting_approval -> generating -> ready
```

Any non-terminal state may move to `failed` with an error. `ready` and `failed`
are terminal. Submitting a validated plan owns the transition to
`awaiting_approval`; exact-version approval owns the transition to `generating`.
Callers cannot skip either guard.

## Core API boundaries

These are the stable boundaries for the App, Agent, Live and Exam repositories.
The HTTP adapter is intentionally separate from this contract issue.

| Action | Boundary | Success | Explicit failures |
|---|---|---|---|
| Create collection | `POST /v1/source-collections` | `201` SourceCollection | `VALIDATION_ERROR`, `COLLECTION_ALREADY_EXISTS`, `DUPLICATE_IDEMPOTENCY_KEY` |
| Register upload | `POST /v1/source-collections/{collection_id}/documents` | `202` IngestionJob | `COLLECTION_NOT_FOUND`, `DOCUMENT_NOT_FOUND`, `OWNER_MISMATCH` |
| Read status | `GET /v1/programme-generation-jobs/{job_id}` | `200` GenerationJob | `GENERATION_JOB_NOT_FOUND` |
| Read plan | `GET /v1/programme-plans/{plan_id}/versions/{plan_version}` | `200` ProgrammePlan | `PLAN_VERSION_NOT_FOUND` |
| Submit edits | `POST /v1/programme-plans/{plan_id}/versions` | `201` proposed ProgrammePlan | `OUTDATED_PLAN_VERSION`, `INVALID_PLAN_REVISION`, `APPROVED_PLAN_IMMUTABLE` |
| Approve exact version | `POST /v1/programme-plans/{plan_id}/versions/{plan_version}/approval` | `200` approved ProgrammePlan | `OUTDATED_PLAN_VERSION`, `INVALID_GENERATION_STATE` |

Every mutation requires an `Idempotency-Key` header. Production adapters reserve
`(owner_id, idempotency_key)` in the same transaction as the mutation and store
the request hash and response. Reusing the key is rejected as
`DUPLICATE_IDEMPOTENCY_KEY`; using the same key with a different payload must
never execute another mutation.

Errors use one shape:

```json
{
  "error": {
    "code": "OUTDATED_PLAN_VERSION",
    "message": "approval must name the exact latest plan version",
    "details": {
      "requested_plan_version": 1,
      "latest_plan_version": 2
    }
  }
}
```

## Persistence

Apply the idempotent migration after the MVP-1 schema:

```bash
docker exec -i univai-db psql -U univai -d univai -v ON_ERROR_STOP=1 < infra/migrations/002_final_mvp.sql
```

The migration stores each `(plan_id, plan_version)` separately and installs a
database trigger that rejects updates and deletes after approval. Generation
jobs reference the exact plan/version pair.

## Manual demo

1. Load the source collection example from
   `services/contracts/schemas/source-collection.schema.json`.
2. Start a generation job and advance it to `planning`.
3. Load the two-semester plan example from
   `services/contracts/schemas/programme-plan.schema.json`.
4. Submit it as version 1, submit an edited version 2, and try approving version
   1. The outdated approval must return `OUTDATED_PLAN_VERSION`.
5. Approve version 2. The job must become `generating` with `plan_version: 2`.
6. Mark generation ready. The job must become `ready` and keep that exact
   approved version.
