"""Validated, immutable programme-plan contract produced from source collections."""

from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
from typing import Any, Mapping, Sequence

from services.contracts.source_collection import (
    ContractValidationError,
    _optional_string,
    _required_string,
    _strict_keys,
    _timestamp,
)

SCHEMA_VERSION = "programme-plan-v1"


class ProgrammePlanStatus(StrEnum):
    PROPOSED = "proposed"
    APPROVED = "approved"


def _sequence(value: Any, field: str) -> Sequence[Any]:
    if not isinstance(value, Sequence) or isinstance(value, (str, bytes)):
        raise ContractValidationError(
            "VALIDATION_ERROR",
            f"{field} must be an array",
            field=field,
        )
    return value


def _positive_number(value: Any, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or value <= 0:
        raise ContractValidationError(
            "VALIDATION_ERROR",
            f"{field} must be greater than zero",
            field=field,
        )
    return float(value)


def _confidence(value: Any, field: str = "confidence") -> float:
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or value < 0
        or value > 1
    ):
        raise ContractValidationError(
            "VALIDATION_ERROR",
            f"{field} must be between 0 and 1",
            field=field,
        )
    return float(value)


def _positive_integer(value: Any, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        raise ContractValidationError(
            "VALIDATION_ERROR",
            f"{field} must be a positive integer",
            field=field,
        )
    return value


@dataclass(frozen=True, slots=True)
class PageRange:
    start: int
    end: int

    @classmethod
    def from_dict(cls, raw: Mapping[str, Any]) -> PageRange:
        data = dict(raw)
        _strict_keys(
            data,
            required={"start", "end"},
            optional=set(),
            contract="PageRange",
        )
        start = _positive_integer(data["start"], "start")
        end = _positive_integer(data["end"], "end")
        if end < start:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "page range end must be greater than or equal to start",
                field="end",
            )
        return cls(start=start, end=end)


@dataclass(frozen=True, slots=True)
class SourceCoverage:
    document_id: str
    page_ranges: tuple[PageRange, ...]
    sections: tuple[str, ...]

    @classmethod
    def from_dict(cls, raw: Mapping[str, Any]) -> SourceCoverage:
        data = dict(raw)
        _strict_keys(
            data,
            required={"document_id", "page_ranges", "sections"},
            optional=set(),
            contract="SourceCoverage",
        )
        ranges = tuple(
            PageRange.from_dict(item)
            if isinstance(item, Mapping)
            else _raise_item_type("page_ranges")
            for item in _sequence(data["page_ranges"], "page_ranges")
        )
        if not ranges:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "source coverage requires at least one page range",
                field="page_ranges",
            )
        sections = tuple(
            _required_string(item, "sections")
            for item in _sequence(data["sections"], "sections")
        )
        if not sections:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "source coverage requires at least one section",
                field="sections",
            )
        return cls(
            document_id=_required_string(data["document_id"], "document_id"),
            page_ranges=ranges,
            sections=sections,
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "document_id": self.document_id,
            "page_ranges": [asdict(page_range) for page_range in self.page_ranges],
            "sections": list(self.sections),
        }


@dataclass(frozen=True, slots=True)
class LectureOutline:
    lecture_id: str
    title: str
    topics: tuple[str, ...]
    source_coverage: tuple[SourceCoverage, ...]
    workload_hours: float
    confidence: float

    @classmethod
    def from_dict(cls, raw: Mapping[str, Any]) -> LectureOutline:
        data = dict(raw)
        _strict_keys(
            data,
            required={
                "lecture_id",
                "title",
                "topics",
                "source_coverage",
                "workload_hours",
                "confidence",
            },
            optional=set(),
            contract="LectureOutline",
        )
        topics = tuple(
            _required_string(item, "topics")
            for item in _sequence(data["topics"], "topics")
        )
        coverage = _parse_coverage(data["source_coverage"])
        if not topics:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "a lecture requires at least one topic",
                field="topics",
            )
        return cls(
            lecture_id=_required_string(data["lecture_id"], "lecture_id"),
            title=_required_string(data["title"], "title"),
            topics=topics,
            source_coverage=coverage,
            workload_hours=_positive_number(
                data["workload_hours"], "workload_hours"
            ),
            confidence=_confidence(data["confidence"]),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "lecture_id": self.lecture_id,
            "title": self.title,
            "topics": list(self.topics),
            "source_coverage": [
                coverage.to_dict() for coverage in self.source_coverage
            ],
            "workload_hours": self.workload_hours,
            "confidence": self.confidence,
        }


@dataclass(frozen=True, slots=True)
class AssessmentOutline:
    assessment_id: str
    title: str
    kind: str
    source_coverage: tuple[SourceCoverage, ...]
    weight_percent: float
    workload_hours: float
    confidence: float

    @classmethod
    def from_dict(cls, raw: Mapping[str, Any]) -> AssessmentOutline:
        data = dict(raw)
        _strict_keys(
            data,
            required={
                "assessment_id",
                "title",
                "kind",
                "source_coverage",
                "weight_percent",
                "workload_hours",
                "confidence",
            },
            optional=set(),
            contract="AssessmentOutline",
        )
        kind = _required_string(data["kind"], "kind")
        if kind not in {"quiz", "midterm", "final", "project"}:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "kind must be quiz, midterm, final, or project",
                field="kind",
            )
        weight = _positive_number(data["weight_percent"], "weight_percent")
        if weight > 100:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "weight_percent cannot exceed 100",
                field="weight_percent",
            )
        return cls(
            assessment_id=_required_string(
                data["assessment_id"], "assessment_id"
            ),
            title=_required_string(data["title"], "title"),
            kind=kind,
            source_coverage=_parse_coverage(data["source_coverage"]),
            weight_percent=weight,
            workload_hours=_positive_number(
                data["workload_hours"], "workload_hours"
            ),
            confidence=_confidence(data["confidence"]),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "assessment_id": self.assessment_id,
            "title": self.title,
            "kind": self.kind,
            "source_coverage": [
                coverage.to_dict() for coverage in self.source_coverage
            ],
            "weight_percent": self.weight_percent,
            "workload_hours": self.workload_hours,
            "confidence": self.confidence,
        }


@dataclass(frozen=True, slots=True)
class Course:
    course_id: str
    title: str
    prerequisites: tuple[str, ...]
    lectures: tuple[LectureOutline, ...]
    assessments: tuple[AssessmentOutline, ...]
    workload_hours: float
    confidence: float

    @classmethod
    def from_dict(cls, raw: Mapping[str, Any]) -> Course:
        data = dict(raw)
        _strict_keys(
            data,
            required={
                "course_id",
                "title",
                "prerequisites",
                "lectures",
                "assessments",
                "workload_hours",
                "confidence",
            },
            optional=set(),
            contract="Course",
        )
        lectures = tuple(
            LectureOutline.from_dict(item)
            if isinstance(item, Mapping)
            else _raise_item_type("lectures")
            for item in _sequence(data["lectures"], "lectures")
        )
        assessments = tuple(
            AssessmentOutline.from_dict(item)
            if isinstance(item, Mapping)
            else _raise_item_type("assessments")
            for item in _sequence(data["assessments"], "assessments")
        )
        if not lectures:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "a course requires at least one lecture",
                field="lectures",
            )
        if not assessments:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "a course requires at least one assessment",
                field="assessments",
            )
        return cls(
            course_id=_required_string(data["course_id"], "course_id"),
            title=_required_string(data["title"], "title"),
            prerequisites=tuple(
                _required_string(item, "prerequisites")
                for item in _sequence(data["prerequisites"], "prerequisites")
            ),
            lectures=lectures,
            assessments=assessments,
            workload_hours=_positive_number(
                data["workload_hours"], "workload_hours"
            ),
            confidence=_confidence(data["confidence"]),
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "course_id": self.course_id,
            "title": self.title,
            "prerequisites": list(self.prerequisites),
            "lectures": [lecture.to_dict() for lecture in self.lectures],
            "assessments": [
                assessment.to_dict() for assessment in self.assessments
            ],
            "workload_hours": self.workload_hours,
            "confidence": self.confidence,
        }


@dataclass(frozen=True, slots=True)
class Semester:
    semester_id: str
    title: str
    sequence: int
    courses: tuple[Course, ...]

    @classmethod
    def from_dict(cls, raw: Mapping[str, Any]) -> Semester:
        data = dict(raw)
        _strict_keys(
            data,
            required={"semester_id", "title", "sequence", "courses"},
            optional=set(),
            contract="Semester",
        )
        courses = tuple(
            Course.from_dict(item)
            if isinstance(item, Mapping)
            else _raise_item_type("courses")
            for item in _sequence(data["courses"], "courses")
        )
        if not courses:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "a semester requires at least one course",
                field="courses",
            )
        return cls(
            semester_id=_required_string(data["semester_id"], "semester_id"),
            title=_required_string(data["title"], "title"),
            sequence=_positive_integer(data["sequence"], "sequence"),
            courses=courses,
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "semester_id": self.semester_id,
            "title": self.title,
            "sequence": self.sequence,
            "courses": [course.to_dict() for course in self.courses],
        }


@dataclass(frozen=True, slots=True)
class ProgrammePlan:
    schema_version: str
    plan_id: str
    collection_id: str
    owner_id: str
    plan_version: int
    parent_plan_version: int | None
    status: ProgrammePlanStatus
    semesters: tuple[Semester, ...]
    workload_hours: float
    confidence: float
    approved_by: str | None
    approved_at: str | None
    created_at: str
    updated_at: str

    @classmethod
    def from_dict(cls, raw: Mapping[str, Any]) -> ProgrammePlan:
        data = dict(raw)
        _strict_keys(
            data,
            required={
                "schema_version",
                "plan_id",
                "collection_id",
                "owner_id",
                "plan_version",
                "parent_plan_version",
                "status",
                "semesters",
                "workload_hours",
                "confidence",
                "approved_by",
                "approved_at",
                "created_at",
                "updated_at",
            },
            optional=set(),
            contract="ProgrammePlan",
        )
        if data["schema_version"] != SCHEMA_VERSION:
            raise ContractValidationError(
                "UNSUPPORTED_SCHEMA_VERSION",
                f"schema_version must be {SCHEMA_VERSION}",
                field="schema_version",
            )
        plan_version = _positive_integer(data["plan_version"], "plan_version")
        parent = data["parent_plan_version"]
        if parent is not None:
            parent = _positive_integer(parent, "parent_plan_version")
            if parent >= plan_version:
                raise ContractValidationError(
                    "VALIDATION_ERROR",
                    "parent_plan_version must be lower than plan_version",
                    field="parent_plan_version",
                )
        if plan_version == 1 and parent is not None:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "plan version 1 cannot have a parent version",
                field="parent_plan_version",
            )
        if plan_version > 1 and parent != plan_version - 1:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "a revised plan must name the immediately previous version",
                field="parent_plan_version",
            )
        try:
            status = ProgrammePlanStatus(data["status"])
        except (TypeError, ValueError) as exc:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "status must be proposed or approved",
                field="status",
            ) from exc
        approved_by = _optional_string(data["approved_by"], "approved_by")
        approved_at = (
            _timestamp(data["approved_at"], "approved_at")
            if data["approved_at"] is not None
            else None
        )
        if status == ProgrammePlanStatus.APPROVED and not (
            approved_by and approved_at
        ):
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "approved plans require approved_by and approved_at",
            )
        if status == ProgrammePlanStatus.PROPOSED and (
            approved_by is not None or approved_at is not None
        ):
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "proposed plans cannot contain approval metadata",
            )
        semesters = tuple(
            Semester.from_dict(item)
            if isinstance(item, Mapping)
            else _raise_item_type("semesters")
            for item in _sequence(data["semesters"], "semesters")
        )
        if not semesters:
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "a programme plan requires at least one semester",
                field="semesters",
            )
        sequences = [semester.sequence for semester in semesters]
        if sequences != list(range(1, len(semesters) + 1)):
            raise ContractValidationError(
                "VALIDATION_ERROR",
                "semester sequence must be contiguous and start at 1",
                field="semesters",
            )
        _assert_unique_ids(semesters)
        return cls(
            schema_version=SCHEMA_VERSION,
            plan_id=_required_string(data["plan_id"], "plan_id"),
            collection_id=_required_string(data["collection_id"], "collection_id"),
            owner_id=_required_string(data["owner_id"], "owner_id"),
            plan_version=plan_version,
            parent_plan_version=parent,
            status=status,
            semesters=semesters,
            workload_hours=_positive_number(
                data["workload_hours"], "workload_hours"
            ),
            confidence=_confidence(data["confidence"]),
            approved_by=approved_by,
            approved_at=approved_at,
            created_at=_timestamp(data["created_at"], "created_at"),
            updated_at=_timestamp(data["updated_at"], "updated_at"),
        )

    def source_document_ids(self) -> frozenset[str]:
        return frozenset(
            coverage.document_id
            for semester in self.semesters
            for course in semester.courses
            for outline in (*course.lectures, *course.assessments)
            for coverage in outline.source_coverage
        )

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "plan_id": self.plan_id,
            "collection_id": self.collection_id,
            "owner_id": self.owner_id,
            "plan_version": self.plan_version,
            "parent_plan_version": self.parent_plan_version,
            "status": self.status.value,
            "semesters": [semester.to_dict() for semester in self.semesters],
            "workload_hours": self.workload_hours,
            "confidence": self.confidence,
            "approved_by": self.approved_by,
            "approved_at": self.approved_at,
            "created_at": self.created_at,
            "updated_at": self.updated_at,
        }


def _parse_coverage(value: Any) -> tuple[SourceCoverage, ...]:
    coverage = tuple(
        SourceCoverage.from_dict(item)
        if isinstance(item, Mapping)
        else _raise_item_type("source_coverage")
        for item in _sequence(value, "source_coverage")
    )
    if not coverage:
        raise ContractValidationError(
            "UNGROUNDED_OUTLINE",
            "every lecture and assessment requires source coverage",
            field="source_coverage",
        )
    return coverage


def _raise_item_type(field: str) -> Any:
    raise ContractValidationError(
        "VALIDATION_ERROR",
        f"each {field} item must be an object",
        field=field,
    )


def _assert_unique_ids(semesters: tuple[Semester, ...]) -> None:
    identifiers: list[str] = []
    for semester in semesters:
        identifiers.append(semester.semester_id)
        for course in semester.courses:
            identifiers.append(course.course_id)
            identifiers.extend(lecture.lecture_id for lecture in course.lectures)
            identifiers.extend(
                assessment.assessment_id for assessment in course.assessments
            )
    if len(identifiers) != len(set(identifiers)):
        raise ContractValidationError(
            "DUPLICATE_OUTLINE_ID",
            "semester, course, lecture, and assessment IDs must be unique",
        )
