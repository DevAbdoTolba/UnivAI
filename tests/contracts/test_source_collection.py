from __future__ import annotations

import json
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest

from services.contracts.source_collection import (
    ContractValidationError,
    IngestionJob,
    SourceCollection,
)

SCHEMA_PATH = (
    Path(__file__).parents[2]
    / "services"
    / "contracts"
    / "schemas"
    / "source-collection.schema.json"
)


def load_schema() -> dict:
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def valid_collection() -> dict:
    return load_schema()["examples"][0]


def test_three_book_collection_round_trips_without_semester_assumptions() -> None:
    collection = SourceCollection.from_dict(valid_collection())

    assert len(collection.documents) == 3
    assert {document.document_id for document in collection.documents} == {
        "book-algorithms",
        "book-databases",
        "book-networks",
    }
    assert collection.to_dict() == valid_collection()


def test_committed_invalid_fixture_is_refused() -> None:
    invalid = load_schema()["x-invalidExamples"][0]["value"]

    with pytest.raises(ContractValidationError, match="every document"):
        SourceCollection.from_dict(invalid)


def test_duplicate_document_ids_are_refused_with_an_explicit_error_payload() -> None:
    raw = valid_collection()
    raw["documents"][1]["document_id"] = raw["documents"][0]["document_id"]

    with pytest.raises(ContractValidationError) as raised:
        SourceCollection.from_dict(raw)

    assert raised.value.to_payload() == {
        "error": {
            "code": "DUPLICATE_DOCUMENT_ID",
            "message": "document_id values must be unique within a collection",
            "field": "documents",
        }
    }


def test_source_contract_is_immutable_after_validation() -> None:
    collection = SourceCollection.from_dict(valid_collection())

    with pytest.raises(FrozenInstanceError):
        collection.owner_id = "another-owner"  # type: ignore[misc]


def test_ingestion_job_requires_failure_details() -> None:
    with pytest.raises(ContractValidationError, match="require an error"):
        IngestionJob.from_dict(
            {
                "schema_version": "source-collection-v1",
                "job_id": "ingest-1",
                "collection_id": "collection-demo-001",
                "document_id": "book-algorithms",
                "owner_id": "S-2026-000001",
                "idempotency_key": "upload-algorithms-1",
                "status": "failed",
                "error": None,
                "created_at": "2026-07-30T09:00:00Z",
                "updated_at": "2026-07-30T09:01:00Z",
            }
        )
