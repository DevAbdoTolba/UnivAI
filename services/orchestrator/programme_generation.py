"""Deterministic programme-generation state machine and mutation contract.

The orchestrator validates AI-produced plans before they enter state. Persistence
is defined by ``infra/migrations/002_final_mvp.sql``; callers can serialize these
frozen domain objects without changing field names.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
from typing import Any, Mapping

from services.contracts.programme_plan import (
    ProgrammePlan,
    ProgrammePlanStatus,
)
from services.contracts.source_collection import (
    ContractValidationError,
    IngestionJob,
    IngestionJobStatus,
    SourceCollection,
    SourceCollectionStatus,
    SourceDocumentStatus,
    _optional_string,
    _required_string,
    _strict_keys,
    _timestamp,
)

GENERATION_SCHEMA_VERSION = "programme-generation-job-v1"


class GenerationState(StrEnum):
    QUEUED = "queued"
    INGESTING = "ingesting"
    PLANNING = "planning"
    AWAITING_APPROVAL = "awaiting_approval"
    GENERATING = "generating"
    READY = "ready"
    FAILED = "failed"


_GENERATION_TRANSITIONS: dict[GenerationState, frozenset[GenerationState]] = {
    GenerationState.QUEUED: frozenset(
        {GenerationState.INGESTING, GenerationState.FAILED}
    ),
    GenerationState.INGESTING: frozenset(
        {GenerationState.PLANNING, GenerationState.FAILED}
    ),
    GenerationState.PLANNING: frozenset(
        {GenerationState.AWAITING_APPROVAL, GenerationState.FAILED}
    ),
    GenerationState.AWAITING_APPROVAL: frozenset(
        {GenerationState.GENERATING, GenerationState.FAILED}
    ),
    GenerationState.GENERATING: frozenset(
        {GenerationState.READY, GenerationState.FAILED}
    ),
    GenerationState.READY: frozenset(),
    GenerationState.FAILED: frozenset(),
}

_INGESTION_TRANSITIONS: dict[IngestionJobStatus, frozenset[IngestionJobStatus]] = {
    IngestionJobStatus.QUEUED: frozenset(
        {IngestionJobStatus.INGESTING, IngestionJobStatus.FAILED}
    ),
    IngestionJobStatus.INGESTING: frozenset(
        {IngestionJobStatus.READY, IngestionJobStatus.FAILED}
    ),
    IngestionJobStatus.READY: frozenset(),
    IngestionJobStatus.FAILED: frozenset(),
}


class OrchestrationError(RuntimeError):
    """An explicit error response for orchestration mutations."""

    def __init__(
        self,
        code: str,
        message: str,
        *,
        details: Mapping[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.details = dict(details or {})

    def to_payload(self) -> dict[str, Any]:
        return {
            "error": {
                "code": self.code,
                "message": str(self),
                "details": self.details,
            }
        }


@dataclass(frozen=True, slots=True)
class GenerationJob:
    schema_version: str
    job_id: str
    collection_id: str
    owner_id: str
    idempotency_key: str
    state: GenerationState
    plan_id: str | None
    plan_version: int | None
    error: str | None
    created_at: str
    updated_at: str

    @classmethod
    def from_dict(cls, raw: Mapping[str, Any]) -> GenerationJob:
        data = dict(raw)
        _strict_keys(
            data,
            required={
                "schema_version",
                "job_id",
                "collection_id",
                "owner_id",
                "idempotency_key",
                "state",
                "plan_id",
                "plan_version",
                "error",
                "created_at",
                "updated_at",
            },
            optional=set(),
            contract="GenerationJob",
        )
        if data["schema_version"] != GENERATION_SCHEMA_VERSION:
            raise ContractValidationError(
                "UNSUPPORTED_SCHEMA_VERSION",
                f"schema_version must be {GENERATION_SCHEMA_VERSION}",
                field="schema_version",
            )
        try:
            state = GenerationState(data["state"])
        except (TypeError, ValueError) as exc:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "invalid generation state",
                field="state",
            ) from exc
        plan_id = _optional_string(data["plan_id"], "plan_id")
        plan_version = data["plan_version"]
        if plan_version is not None and (
            isinstance(plan_version, bool)
            or not isinstance(plan_version, int)
            or plan_version < 1
        ):
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "plan_version must be a positive integer or null",
                field="plan_version",
            )
        if (plan_id is None) != (plan_version is None):
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "plan_id and plan_version must both be set or both be null",
            )
        if state in {
            GenerationState.AWAITING_APPROVAL,
            GenerationState.GENERATING,
            GenerationState.READY,
        } and plan_id is None:
            raise ContractValidationError(
                "INVALID_GENERATION_STATE",
                f"{state.value} jobs require a plan reference",
            )
        error = _optional_string(data["error"], "error")
        if state == GenerationState.FAILED and not error:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "failed generation jobs require an error",
                field="error",
            )
        if state != GenerationState.FAILED and error:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "only failed generation jobs may carry an error",
                field="error",
            )
        return cls(
            schema_version=GENERATION_SCHEMA_VERSION,
            job_id=_required_string(data["job_id"], "job_id"),
            collection_id=_required_string(data["collection_id"], "collection_id"),
            owner_id=_required_string(data["owner_id"], "owner_id"),
            idempotency_key=_required_string(
                data["idempotency_key"], "idempotency_key"
            ),
            state=state,
            plan_id=plan_id,
            plan_version=plan_version,
            error=error,
            created_at=_timestamp(data["created_at"], "created_at"),
            updated_at=_timestamp(data["updated_at"], "updated_at"),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            **asdict(self),
            "state": self.state.value,
        }


class ProgrammeGenerationOrchestrator:
    """Reference domain service for the documented Core API boundaries.

    It keeps state in-process so unit CI is deterministic. Production adapters
    persist the same objects in the migration tables and must reserve the
    idempotency key in the same transaction as each mutation.
    """

    def __init__(self) -> None:
        self._collections: dict[str, SourceCollection] = {}
        self._ingestion_jobs: dict[str, IngestionJob] = {}
        self._generation_jobs: dict[str, GenerationJob] = {}
        self._plans: dict[tuple[str, int], ProgrammePlan] = {}
        self._latest_plan_versions: dict[str, int] = {}
        self._used_idempotency_keys: set[tuple[str, str]] = set()

    def create_collection(
        self,
        raw_collection: Mapping[str, Any],
        *,
        idempotency_key: str,
    ) -> SourceCollection:
        collection = SourceCollection.from_dict(raw_collection)
        mutation_key = self._check_key(collection.owner_id, idempotency_key)
        if collection.collection_id in self._collections:
            raise OrchestrationError(
                "COLLECTION_ALREADY_EXISTS",
                f"collection {collection.collection_id} already exists",
            )
        self._commit_key(mutation_key)
        self._collections[collection.collection_id] = collection
        return collection

    def register_ingestion_job(
        self,
        raw_job: Mapping[str, Any],
    ) -> IngestionJob:
        job = IngestionJob.from_dict(raw_job)
        mutation_key = self._check_key(job.owner_id, job.idempotency_key)
        if job.status != IngestionJobStatus.QUEUED:
            raise OrchestrationError(
                "INVALID_INGESTION_STATE",
                "new ingestion jobs must start in queued",
            )
        collection = self._owned_collection(job.collection_id, job.owner_id)
        if job.job_id in self._ingestion_jobs:
            raise OrchestrationError(
                "INGESTION_JOB_ALREADY_EXISTS",
                f"ingestion job {job.job_id} already exists",
            )
        if job.document_id not in {
            document.document_id for document in collection.documents
        }:
            raise OrchestrationError(
                "DOCUMENT_NOT_FOUND",
                f"document {job.document_id} does not belong to the collection",
            )
        self._commit_key(mutation_key)
        self._ingestion_jobs[job.job_id] = job
        return job

    def advance_ingestion(
        self,
        job_id: str,
        target: IngestionJobStatus,
        *,
        idempotency_key: str,
        updated_at: str,
        error: str | None = None,
    ) -> IngestionJob:
        job = self.get_ingestion_job(job_id)
        mutation_key = self._check_key(job.owner_id, idempotency_key)
        if target not in _INGESTION_TRANSITIONS[job.status]:
            raise OrchestrationError(
                "INVALID_INGESTION_TRANSITION",
                f"cannot move ingestion from {job.status.value} to {target.value}",
            )
        timestamp = _timestamp(updated_at, "updated_at")
        updated_job = IngestionJob.from_dict(
            {
                **job.to_dict(),
                "status": target.value,
                "error": error,
                "updated_at": timestamp,
            }
        )
        document_status = {
            IngestionJobStatus.INGESTING: SourceDocumentStatus.INGESTING,
            IngestionJobStatus.READY: SourceDocumentStatus.READY,
            IngestionJobStatus.FAILED: SourceDocumentStatus.FAILED,
        }[target]
        collection = self._collections[job.collection_id].with_document_status(
            job.document_id,
            document_status,
            updated_at=timestamp,
            error=error,
        )
        self._commit_key(mutation_key)
        self._ingestion_jobs[job_id] = updated_job
        self._collections[job.collection_id] = collection
        return updated_job

    def start_generation(
        self,
        raw_job: Mapping[str, Any],
    ) -> GenerationJob:
        job = GenerationJob.from_dict(raw_job)
        mutation_key = self._check_key(job.owner_id, job.idempotency_key)
        if job.state != GenerationState.QUEUED:
            raise OrchestrationError(
                "INVALID_GENERATION_STATE",
                "new generation jobs must start in queued",
            )
        collection = self._owned_collection(job.collection_id, job.owner_id)
        if collection.status != SourceCollectionStatus.READY:
            raise OrchestrationError(
                "COLLECTION_NOT_READY",
                "generation requires a source collection whose documents are ready",
            )
        if job.job_id in self._generation_jobs:
            raise OrchestrationError(
                "GENERATION_JOB_ALREADY_EXISTS",
                f"generation job {job.job_id} already exists",
            )
        self._commit_key(mutation_key)
        self._generation_jobs[job.job_id] = job
        return job

    def advance_generation(
        self,
        job_id: str,
        target: GenerationState,
        *,
        idempotency_key: str,
        updated_at: str,
        error: str | None = None,
    ) -> GenerationJob:
        job = self.get_generation_job(job_id)
        mutation_key = self._check_key(job.owner_id, idempotency_key)
        if target not in _GENERATION_TRANSITIONS[job.state]:
            raise OrchestrationError(
                "INVALID_GENERATION_TRANSITION",
                f"cannot move generation from {job.state.value} to {target.value}",
            )
        if target in {
            GenerationState.AWAITING_APPROVAL,
            GenerationState.GENERATING,
        }:
            raise OrchestrationError(
                "GUARDED_GENERATION_TRANSITION",
                f"use {'submit_plan' if target == GenerationState.AWAITING_APPROVAL else 'approve_plan'} for this transition",
            )
        updated = GenerationJob.from_dict(
            {
                **job.to_dict(),
                "state": target.value,
                "error": error,
                "updated_at": _timestamp(updated_at, "updated_at"),
            }
        )
        self._commit_key(mutation_key)
        self._generation_jobs[job_id] = updated
        return updated

    def submit_plan(
        self,
        job_id: str,
        raw_plan: Mapping[str, Any],
        *,
        idempotency_key: str,
        updated_at: str,
    ) -> ProgrammePlan:
        job = self.get_generation_job(job_id)
        mutation_key = self._check_key(job.owner_id, idempotency_key)
        if job.state != GenerationState.PLANNING:
            raise OrchestrationError(
                "INVALID_GENERATION_STATE",
                "a proposed plan can only be submitted while planning",
            )
        plan = ProgrammePlan.from_dict(raw_plan)
        if plan.status != ProgrammePlanStatus.PROPOSED or plan.plan_version != 1:
            raise OrchestrationError(
                "INVALID_INITIAL_PLAN",
                "the initial AI-produced plan must be proposed version 1",
            )
        self._validate_plan_ownership_and_sources(job, plan)
        key = (plan.plan_id, plan.plan_version)
        if key in self._plans:
            raise OrchestrationError(
                "PLAN_VERSION_ALREADY_EXISTS",
                f"plan {plan.plan_id} version {plan.plan_version} already exists",
            )
        timestamp = _timestamp(updated_at, "updated_at")
        self._commit_key(mutation_key)
        self._plans[key] = plan
        self._latest_plan_versions[plan.plan_id] = plan.plan_version
        self._generation_jobs[job_id] = GenerationJob.from_dict(
            {
                **job.to_dict(),
                "state": GenerationState.AWAITING_APPROVAL.value,
                "plan_id": plan.plan_id,
                "plan_version": plan.plan_version,
                "updated_at": timestamp,
            }
        )
        return plan

    def submit_plan_edit(
        self,
        job_id: str,
        raw_plan: Mapping[str, Any],
        *,
        expected_plan_version: int,
        idempotency_key: str,
        updated_at: str,
    ) -> ProgrammePlan:
        job = self.get_generation_job(job_id)
        mutation_key = self._check_key(job.owner_id, idempotency_key)
        if job.state != GenerationState.AWAITING_APPROVAL or not job.plan_id:
            raise OrchestrationError(
                "INVALID_GENERATION_STATE",
                "plan edits require an awaiting_approval job",
            )
        latest = self._latest_plan_versions[job.plan_id]
        if expected_plan_version != latest:
            raise OrchestrationError(
                "OUTDATED_PLAN_VERSION",
                "the submitted edit is based on an outdated plan version",
                details={
                    "expected_plan_version": expected_plan_version,
                    "latest_plan_version": latest,
                },
            )
        current = self._plans[(job.plan_id, latest)]
        if current.status == ProgrammePlanStatus.APPROVED:
            raise OrchestrationError(
                "APPROVED_PLAN_IMMUTABLE",
                "approved plan versions cannot be edited",
            )
        edited = ProgrammePlan.from_dict(raw_plan)
        if (
            edited.plan_id != current.plan_id
            or edited.plan_version != latest + 1
            or edited.parent_plan_version != latest
            or edited.status != ProgrammePlanStatus.PROPOSED
        ):
            raise OrchestrationError(
                "INVALID_PLAN_REVISION",
                "an edit must keep plan_id and create the next proposed version",
            )
        self._validate_plan_ownership_and_sources(job, edited)
        self._commit_key(mutation_key)
        self._plans[(edited.plan_id, edited.plan_version)] = edited
        self._latest_plan_versions[edited.plan_id] = edited.plan_version
        self._generation_jobs[job_id] = GenerationJob.from_dict(
            {
                **job.to_dict(),
                "plan_version": edited.plan_version,
                "updated_at": _timestamp(updated_at, "updated_at"),
            }
        )
        return edited

    def approve_plan(
        self,
        job_id: str,
        plan_version: int,
        *,
        approved_by: str,
        idempotency_key: str,
        approved_at: str,
    ) -> ProgrammePlan:
        job = self.get_generation_job(job_id)
        mutation_key = self._check_key(job.owner_id, idempotency_key)
        if job.state != GenerationState.AWAITING_APPROVAL or not job.plan_id:
            raise OrchestrationError(
                "INVALID_GENERATION_STATE",
                "only awaiting_approval jobs can approve a plan",
            )
        latest = self._latest_plan_versions[job.plan_id]
        if plan_version != latest:
            raise OrchestrationError(
                "OUTDATED_PLAN_VERSION",
                "approval must name the exact latest plan version",
                details={
                    "requested_plan_version": plan_version,
                    "latest_plan_version": latest,
                },
            )
        proposed = self._plans[(job.plan_id, latest)]
        timestamp = _timestamp(approved_at, "approved_at")
        approved = ProgrammePlan.from_dict(
            {
                **proposed.to_dict(),
                "status": ProgrammePlanStatus.APPROVED.value,
                "approved_by": _required_string(approved_by, "approved_by"),
                "approved_at": timestamp,
                "updated_at": timestamp,
            }
        )
        self._commit_key(mutation_key)
        self._plans[(approved.plan_id, approved.plan_version)] = approved
        self._generation_jobs[job_id] = GenerationJob.from_dict(
            {
                **job.to_dict(),
                "state": GenerationState.GENERATING.value,
                "plan_version": approved.plan_version,
                "updated_at": timestamp,
            }
        )
        return approved

    def get_collection(self, collection_id: str) -> SourceCollection:
        try:
            return self._collections[collection_id]
        except KeyError as exc:
            raise OrchestrationError(
                "COLLECTION_NOT_FOUND",
                f"collection {collection_id} was not found",
            ) from exc

    def get_ingestion_job(self, job_id: str) -> IngestionJob:
        try:
            return self._ingestion_jobs[job_id]
        except KeyError as exc:
            raise OrchestrationError(
                "INGESTION_JOB_NOT_FOUND",
                f"ingestion job {job_id} was not found",
            ) from exc

    def get_generation_job(self, job_id: str) -> GenerationJob:
        try:
            return self._generation_jobs[job_id]
        except KeyError as exc:
            raise OrchestrationError(
                "GENERATION_JOB_NOT_FOUND",
                f"generation job {job_id} was not found",
            ) from exc

    def get_plan(self, plan_id: str, plan_version: int) -> ProgrammePlan:
        try:
            return self._plans[(plan_id, plan_version)]
        except KeyError as exc:
            raise OrchestrationError(
                "PLAN_VERSION_NOT_FOUND",
                f"plan {plan_id} version {plan_version} was not found",
            ) from exc

    def _check_key(
        self,
        owner_id: str,
        idempotency_key: str,
    ) -> tuple[str, str]:
        normalized_owner = _required_string(owner_id, "owner_id")
        normalized_key = _required_string(idempotency_key, "idempotency_key")
        key = (normalized_owner, normalized_key)
        if key in self._used_idempotency_keys:
            raise OrchestrationError(
                "DUPLICATE_IDEMPOTENCY_KEY",
                "the idempotency key has already been used",
                details={"idempotency_key": normalized_key},
            )
        return key

    def _commit_key(self, key: tuple[str, str]) -> None:
        self._used_idempotency_keys.add(key)

    def _owned_collection(
        self,
        collection_id: str,
        owner_id: str,
    ) -> SourceCollection:
        collection = self.get_collection(collection_id)
        if collection.owner_id != owner_id:
            raise OrchestrationError(
                "OWNER_MISMATCH",
                "the resource does not belong to this owner",
            )
        return collection

    def _validate_plan_ownership_and_sources(
        self,
        job: GenerationJob,
        plan: ProgrammePlan,
    ) -> None:
        collection = self._owned_collection(job.collection_id, job.owner_id)
        if (
            plan.collection_id != collection.collection_id
            or plan.owner_id != collection.owner_id
        ):
            raise OrchestrationError(
                "PLAN_SCOPE_MISMATCH",
                "plan owner and collection must match the generation job",
            )
        approved_documents = {
            document.document_id
            for document in collection.documents
            if document.status == SourceDocumentStatus.READY
        }
        unknown_sources = sorted(plan.source_document_ids() - approved_documents)
        if unknown_sources:
            raise OrchestrationError(
                "UNAPPROVED_SOURCE_REFERENCE",
                "plan source coverage references documents outside the ready collection",
                details={"document_ids": unknown_sources},
            )
        page_counts = {
            document.document_id: document.page_count
            for document in collection.documents
        }
        invalid_ranges: list[dict[str, Any]] = []
        for semester in plan.semesters:
            for course in semester.courses:
                for outline in (*course.lectures, *course.assessments):
                    for coverage in outline.source_coverage:
                        for page_range in coverage.page_ranges:
                            if page_range.end > page_counts[coverage.document_id]:
                                invalid_ranges.append(
                                    {
                                        "document_id": coverage.document_id,
                                        "start": page_range.start,
                                        "end": page_range.end,
                                        "page_count": page_counts[
                                            coverage.document_id
                                        ],
                                    }
                                )
        if invalid_ranges:
            raise OrchestrationError(
                "SOURCE_PAGE_OUT_OF_RANGE",
                "plan source coverage exceeds the registered document page count",
                details={"page_ranges": invalid_ranges},
            )
