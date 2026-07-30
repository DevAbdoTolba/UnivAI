"""Versioned contracts for multi-book source collections and ingestion jobs."""

from __future__ import annotations

from dataclasses import asdict, dataclass, replace
from datetime import datetime
from enum import StrEnum
from typing import Any, Mapping, Sequence

SCHEMA_VERSION = "source-collection-v1"


class ContractValidationError(ValueError):
    """A machine-readable contract validation failure."""

    def __init__(
        self,
        code: str,
        message: str,
        *,
        field: str | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.field = field

    def to_payload(self) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "error": {
                "code": self.code,
                "message": str(self),
            }
        }
        if self.field:
            payload["error"]["field"] = self.field
        return payload


class SourceDocumentStatus(StrEnum):
    REGISTERED = "registered"
    INGESTING = "ingesting"
    READY = "ready"
    FAILED = "failed"


class SourceCollectionStatus(StrEnum):
    DRAFT = "draft"
    INGESTING = "ingesting"
    READY = "ready"
    FAILED = "failed"


class IngestionJobStatus(StrEnum):
    QUEUED = "queued"
    INGESTING = "ingesting"
    READY = "ready"
    FAILED = "failed"


def _required_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ContractValidationError(
            "VALIDATION_ERROR",
            f"{field} must be a non-empty string",
            field=field,
        )
    return value.strip()


def _optional_string(value: Any, field: str) -> str | None:
    if value is None:
        return None
    return _required_string(value, field)


def _timestamp(value: Any, field: str) -> str:
    text = _required_string(value, field)
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ContractValidationError(
            "VALIDATION_ERROR",
            f"{field} must be an ISO-8601 timestamp",
            field=field,
        ) from exc
    if parsed.tzinfo is None:
        raise ContractValidationError(
            "VALIDATION_ERROR",
            f"{field} must include a timezone",
            field=field,
        )
    return text


def _enum_value(enum_type: type[StrEnum], value: Any, field: str) -> StrEnum:
    try:
        return enum_type(value)
    except (TypeError, ValueError) as exc:
        allowed = ", ".join(item.value for item in enum_type)
        raise ContractValidationError(
            "VALIDATION_ERROR",
            f"{field} must be one of: {allowed}",
            field=field,
        ) from exc


def _strict_keys(
    data: Mapping[str, Any],
    *,
    required: set[str],
    optional: set[str],
    contract: str,
) -> None:
    missing = sorted(required - data.keys())
    if missing:
        raise ContractValidationError(
            "VALIDATION_ERROR",
            f"{contract} is missing required fields: {', '.join(missing)}",
        )
    unknown = sorted(data.keys() - required - optional)
    if unknown:
        raise ContractValidationError(
            "VALIDATION_ERROR",
            f"{contract} contains unknown fields: {', '.join(unknown)}",
        )


@dataclass(frozen=True, slots=True)
class SourceDocument:
    document_id: str
    filename: str
    title: str
    media_type: str
    page_count: int
    status: SourceDocumentStatus
    error: str | None
    created_at: str
    updated_at: str

    @classmethod
    def from_dict(cls, raw: Mapping[str, Any]) -> SourceDocument:
        data = dict(raw)
        _strict_keys(
            data,
            required={
                "document_id",
                "filename",
                "title",
                "media_type",
                "page_count",
                "status",
                "error",
                "created_at",
                "updated_at",
            },
            optional=set(),
            contract="SourceDocument",
        )
        page_count = data["page_count"]
        if isinstance(page_count, bool) or not isinstance(page_count, int) or page_count < 1:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "page_count must be a positive integer",
                field="page_count",
            )
        status = _enum_value(SourceDocumentStatus, data["status"], "status")
        error = _optional_string(data["error"], "error")
        if status == SourceDocumentStatus.FAILED and not error:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "failed documents require an error",
                field="error",
            )
        if status != SourceDocumentStatus.FAILED and error:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "only failed documents may carry an error",
                field="error",
            )
        return cls(
            document_id=_required_string(data["document_id"], "document_id"),
            filename=_required_string(data["filename"], "filename"),
            title=_required_string(data["title"], "title"),
            media_type=_required_string(data["media_type"], "media_type"),
            page_count=page_count,
            status=status,
            error=error,
            created_at=_timestamp(data["created_at"], "created_at"),
            updated_at=_timestamp(data["updated_at"], "updated_at"),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            **asdict(self),
            "status": self.status.value,
        }


@dataclass(frozen=True, slots=True)
class SourceCollection:
    schema_version: str
    collection_id: str
    owner_id: str
    status: SourceCollectionStatus
    documents: tuple[SourceDocument, ...]
    error: str | None
    created_at: str
    updated_at: str

    @classmethod
    def from_dict(cls, raw: Mapping[str, Any]) -> SourceCollection:
        data = dict(raw)
        _strict_keys(
            data,
            required={
                "schema_version",
                "collection_id",
                "owner_id",
                "status",
                "documents",
                "error",
                "created_at",
                "updated_at",
            },
            optional=set(),
            contract="SourceCollection",
        )
        if data["schema_version"] != SCHEMA_VERSION:
            raise ContractValidationError(
                "UNSUPPORTED_SCHEMA_VERSION",
                f"schema_version must be {SCHEMA_VERSION}",
                field="schema_version",
            )
        if not isinstance(data["documents"], Sequence) or isinstance(
            data["documents"], (str, bytes)
        ):
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "documents must be an array",
                field="documents",
            )
        documents = tuple(
            SourceDocument.from_dict(item)
            if isinstance(item, Mapping)
            else _raise_document_type()
            for item in data["documents"]
        )
        if not documents:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "a source collection requires at least one document",
                field="documents",
            )
        document_ids = [document.document_id for document in documents]
        if len(document_ids) != len(set(document_ids)):
            raise ContractValidationError(
                "DUPLICATE_DOCUMENT_ID",
                "document_id values must be unique within a collection",
                field="documents",
            )
        status = _enum_value(SourceCollectionStatus, data["status"], "status")
        error = _optional_string(data["error"], "error")
        if status == SourceCollectionStatus.FAILED and not error:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "failed collections require an error",
                field="error",
            )
        if status != SourceCollectionStatus.FAILED and error:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "only failed collections may carry an error",
                field="error",
            )
        if status == SourceCollectionStatus.READY and any(
            document.status != SourceDocumentStatus.READY for document in documents
        ):
            raise ContractValidationError(
                "INVALID_COLLECTION_STATE",
                "a ready collection requires every document to be ready",
                field="documents",
            )
        return cls(
            schema_version=SCHEMA_VERSION,
            collection_id=_required_string(data["collection_id"], "collection_id"),
            owner_id=_required_string(data["owner_id"], "owner_id"),
            status=status,
            documents=documents,
            error=error,
            created_at=_timestamp(data["created_at"], "created_at"),
            updated_at=_timestamp(data["updated_at"], "updated_at"),
        )

    def with_document_status(
        self,
        document_id: str,
        status: SourceDocumentStatus,
        *,
        updated_at: str,
        error: str | None = None,
    ) -> SourceCollection:
        timestamp = _timestamp(updated_at, "updated_at")
        found = False
        documents: list[SourceDocument] = []
        for document in self.documents:
            if document.document_id != document_id:
                documents.append(document)
                continue
            found = True
            documents.append(
                replace(
                    document,
                    status=status,
                    error=error,
                    updated_at=timestamp,
                )
            )
        if not found:
            raise ContractValidationError(
                "DOCUMENT_NOT_FOUND",
                f"document {document_id} does not belong to collection {self.collection_id}",
                field="document_id",
            )
        if any(document.status == SourceDocumentStatus.FAILED for document in documents):
            collection_status = SourceCollectionStatus.FAILED
            collection_error = next(
                document.error
                for document in documents
                if document.status == SourceDocumentStatus.FAILED
            )
        elif all(document.status == SourceDocumentStatus.READY for document in documents):
            collection_status = SourceCollectionStatus.READY
            collection_error = None
        else:
            collection_status = SourceCollectionStatus.INGESTING
            collection_error = None
        return SourceCollection.from_dict(
            {
                **self.to_dict(),
                "documents": [document.to_dict() for document in documents],
                "status": collection_status.value,
                "error": collection_error,
                "updated_at": timestamp,
            }
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "collection_id": self.collection_id,
            "owner_id": self.owner_id,
            "status": self.status.value,
            "documents": [document.to_dict() for document in self.documents],
            "error": self.error,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
        }


def _raise_document_type() -> SourceDocument:
    raise ContractValidationError(
        "VALIDATION_ERROR",
        "each documents item must be an object",
        field="documents",
    )


@dataclass(frozen=True, slots=True)
class IngestionJob:
    schema_version: str
    job_id: str
    collection_id: str
    document_id: str
    owner_id: str
    idempotency_key: str
    status: IngestionJobStatus
    error: str | None
    created_at: str
    updated_at: str

    @classmethod
    def from_dict(cls, raw: Mapping[str, Any]) -> IngestionJob:
        data = dict(raw)
        _strict_keys(
            data,
            required={
                "schema_version",
                "job_id",
                "collection_id",
                "document_id",
                "owner_id",
                "idempotency_key",
                "status",
                "error",
                "created_at",
                "updated_at",
            },
            optional=set(),
            contract="IngestionJob",
        )
        if data["schema_version"] != SCHEMA_VERSION:
            raise ContractValidationError(
                "UNSUPPORTED_SCHEMA_VERSION",
                f"schema_version must be {SCHEMA_VERSION}",
                field="schema_version",
            )
        status = _enum_value(IngestionJobStatus, data["status"], "status")
        error = _optional_string(data["error"], "error")
        if status == IngestionJobStatus.FAILED and not error:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "failed ingestion jobs require an error",
                field="error",
            )
        if status != IngestionJobStatus.FAILED and error:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "only failed ingestion jobs may carry an error",
                field="error",
            )
        return cls(
            schema_version=SCHEMA_VERSION,
            job_id=_required_string(data["job_id"], "job_id"),
            collection_id=_required_string(data["collection_id"], "collection_id"),
            document_id=_required_string(data["document_id"], "document_id"),
            owner_id=_required_string(data["owner_id"], "owner_id"),
            idempotency_key=_required_string(
                data["idempotency_key"], "idempotency_key"
            ),
            status=status,
            error=error,
            created_at=_timestamp(data["created_at"], "created_at"),
            updated_at=_timestamp(data["updated_at"], "updated_at"),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            **asdict(self),
            "status": self.status.value,
        }
