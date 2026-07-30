from __future__ import annotations

import copy
import json
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest

from services.contracts.programme_plan import ProgrammePlan, ProgrammePlanStatus
from services.contracts.source_collection import (
    ContractValidationError,
    IngestionJobStatus,
    SourceCollectionStatus,
)
from services.orchestrator.programme_generation import (
    GenerationState,
    OrchestrationError,
    ProgrammeGenerationOrchestrator,
)

ROOT = Path(__file__).parents[2]
SOURCE_SCHEMA_PATH = (
    ROOT
    / "services"
    / "contracts"
    / "schemas"
    / "source-collection.schema.json"
)
PLAN_SCHEMA_PATH = (
    ROOT
    / "services"
    / "contracts"
    / "schemas"
    / "programme-plan.schema.json"
)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def ready_collection() -> dict:
    return copy.deepcopy(load_json(SOURCE_SCHEMA_PATH)["examples"][0])


def proposed_plan() -> dict:
    return copy.deepcopy(load_json(PLAN_SCHEMA_PATH)["examples"][0])


def generation_job() -> dict:
    return {
        "schema_version": "programme-generation-job-v1",
        "job_id": "generation-demo-001",
        "collection_id": "collection-demo-001",
        "owner_id": "S-2026-000001",
        "idempotency_key": "start-generation-001",
        "state": "queued",
        "plan_id": None,
        "plan_version": None,
        "error": None,
        "created_at": "2026-07-30T09:20:00Z",
        "updated_at": "2026-07-30T09:20:00Z",
    }


def prepare_planning_job() -> ProgrammeGenerationOrchestrator:
    orchestrator = ProgrammeGenerationOrchestrator()
    orchestrator.create_collection(
        ready_collection(),
        idempotency_key="create-collection-001",
    )
    orchestrator.start_generation(generation_job())
    orchestrator.advance_generation(
        "generation-demo-001",
        GenerationState.INGESTING,
        idempotency_key="generation-ingesting-001",
        updated_at="2026-07-30T09:21:00Z",
    )
    orchestrator.advance_generation(
        "generation-demo-001",
        GenerationState.PLANNING,
        idempotency_key="generation-planning-001",
        updated_at="2026-07-30T09:22:00Z",
    )
    return orchestrator


def test_committed_plan_fixture_is_valid_and_source_grounded() -> None:
    plan = ProgrammePlan.from_dict(proposed_plan())

    assert len(plan.semesters) == 2
    assert plan.source_document_ids() == {
        "book-algorithms",
        "book-databases",
        "book-networks",
    }
    assert plan.to_dict() == proposed_plan()


def test_invalid_ai_fixture_is_refused_instead_of_fabricating_sources() -> None:
    invalid = load_json(PLAN_SCHEMA_PATH)["x-invalidExamples"][0]["value"]

    with pytest.raises(ContractValidationError):
        ProgrammePlan.from_dict(invalid)


def test_three_book_two_semester_edit_approve_and_generate_demo() -> None:
    orchestrator = prepare_planning_job()
    version_1 = orchestrator.submit_plan(
        "generation-demo-001",
        proposed_plan(),
        idempotency_key="submit-plan-v1",
        updated_at="2026-07-30T10:00:00Z",
    )
    assert version_1.plan_version == 1
    assert (
        orchestrator.get_generation_job("generation-demo-001").state
        == GenerationState.AWAITING_APPROVAL
    )

    version_2_raw = version_1.to_dict()
    version_2_raw.update(
        {
            "plan_version": 2,
            "parent_plan_version": 1,
            "updated_at": "2026-07-30T10:10:00Z",
        }
    )
    version_2_raw["semesters"][1]["title"] = "Applied Systems"
    version_2 = orchestrator.submit_plan_edit(
        "generation-demo-001",
        version_2_raw,
        expected_plan_version=1,
        idempotency_key="edit-plan-v2",
        updated_at="2026-07-30T10:10:00Z",
    )

    with pytest.raises(OrchestrationError) as outdated:
        orchestrator.approve_plan(
            "generation-demo-001",
            1,
            approved_by="S-2026-000001",
            idempotency_key="approve-outdated-v1",
            approved_at="2026-07-30T10:11:00Z",
        )
    assert outdated.value.code == "OUTDATED_PLAN_VERSION"

    approved = orchestrator.approve_plan(
        "generation-demo-001",
        2,
        approved_by="S-2026-000001",
        idempotency_key="approve-plan-v2",
        approved_at="2026-07-30T10:12:00Z",
    )
    assert approved.status == ProgrammePlanStatus.APPROVED
    assert approved.plan_version == 2
    assert (
        orchestrator.get_generation_job("generation-demo-001").state
        == GenerationState.GENERATING
    )

    ready_job = orchestrator.advance_generation(
        "generation-demo-001",
        GenerationState.READY,
        idempotency_key="generation-ready-001",
        updated_at="2026-07-30T10:20:00Z",
    )
    assert ready_job.state == GenerationState.READY
    assert ready_job.plan_version == 2

    with pytest.raises(FrozenInstanceError):
        approved.plan_version = 3  # type: ignore[misc]


def test_duplicate_idempotency_key_is_rejected_with_explicit_payload() -> None:
    orchestrator = ProgrammeGenerationOrchestrator()
    orchestrator.create_collection(
        ready_collection(),
        idempotency_key="same-key",
    )

    with pytest.raises(OrchestrationError) as duplicate:
        orchestrator.create_collection(
            ready_collection(),
            idempotency_key="same-key",
        )

    assert duplicate.value.to_payload() == {
        "error": {
            "code": "DUPLICATE_IDEMPOTENCY_KEY",
            "message": "the idempotency key has already been used",
            "details": {"idempotency_key": "same-key"},
        }
    }


def test_plan_cannot_reference_a_document_outside_the_collection() -> None:
    orchestrator = prepare_planning_job()
    invalid = proposed_plan()
    invalid["semesters"][0]["courses"][0]["lectures"][0]["source_coverage"][0][
        "document_id"
    ] = "book-not-approved"

    with pytest.raises(OrchestrationError) as refused:
        orchestrator.submit_plan(
            "generation-demo-001",
            invalid,
            idempotency_key="submit-unknown-source",
            updated_at="2026-07-30T10:00:00Z",
        )

    assert refused.value.code == "UNAPPROVED_SOURCE_REFERENCE"
    assert refused.value.details == {"document_ids": ["book-not-approved"]}

    invalid["semesters"][0]["courses"][0]["lectures"][0]["source_coverage"][0][
        "document_id"
    ] = "book-algorithms"
    accepted = orchestrator.submit_plan(
        "generation-demo-001",
        invalid,
        idempotency_key="submit-unknown-source",
        updated_at="2026-07-30T10:00:00Z",
    )
    assert accepted.plan_version == 1


def test_plan_page_citations_must_fit_the_registered_document() -> None:
    orchestrator = prepare_planning_job()
    invalid = proposed_plan()
    invalid["semesters"][0]["courses"][0]["lectures"][0]["source_coverage"][0][
        "page_ranges"
    ] = [{"start": 400, "end": 500}]

    with pytest.raises(OrchestrationError) as refused:
        orchestrator.submit_plan(
            "generation-demo-001",
            invalid,
            idempotency_key="submit-page-out-of-range",
            updated_at="2026-07-30T10:00:00Z",
        )

    assert refused.value.code == "SOURCE_PAGE_OUT_OF_RANGE"
    assert refused.value.details["page_ranges"][0]["page_count"] == 420


def test_all_three_ingestion_jobs_must_finish_before_collection_is_ready() -> None:
    orchestrator = ProgrammeGenerationOrchestrator()
    raw_collection = ready_collection()
    raw_collection["status"] = "draft"
    raw_collection["updated_at"] = "2026-07-30T09:00:00Z"
    for document in raw_collection["documents"]:
        document["status"] = "registered"
        document["updated_at"] = "2026-07-30T09:00:00Z"
    orchestrator.create_collection(
        raw_collection,
        idempotency_key="create-ingesting-collection",
    )

    for index, document in enumerate(raw_collection["documents"], start=1):
        orchestrator.register_ingestion_job(
            {
                "schema_version": "source-collection-v1",
                "job_id": f"ingestion-{index}",
                "collection_id": raw_collection["collection_id"],
                "document_id": document["document_id"],
                "owner_id": raw_collection["owner_id"],
                "idempotency_key": f"register-ingestion-{index}",
                "status": "queued",
                "error": None,
                "created_at": "2026-07-30T09:01:00Z",
                "updated_at": "2026-07-30T09:01:00Z",
            }
        )
        orchestrator.advance_ingestion(
            f"ingestion-{index}",
            IngestionJobStatus.INGESTING,
            idempotency_key=f"start-ingestion-{index}",
            updated_at="2026-07-30T09:02:00Z",
        )
        orchestrator.advance_ingestion(
            f"ingestion-{index}",
            IngestionJobStatus.READY,
            idempotency_key=f"finish-ingestion-{index}",
            updated_at=f"2026-07-30T09:1{index}:00Z",
        )
        expected = (
            SourceCollectionStatus.READY
            if index == len(raw_collection["documents"])
            else SourceCollectionStatus.INGESTING
        )
        assert (
            orchestrator.get_collection(raw_collection["collection_id"]).status
            == expected
        )
