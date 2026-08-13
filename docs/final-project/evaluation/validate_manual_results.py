#!/usr/bin/env python3
"""Validate the fail-closed UnivAI manual evaluation CSV contract.

The validator is read-only: it never rewrites the input or referenced evidence.
Run it with no argument to validate the adjacent manual_test_protocols.csv, or
pass another CSV path explicitly.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter
from datetime import date
from pathlib import Path
from typing import Mapping, Sequence


EXPECTED_HEADER = (
    "case_id",
    "test_type",
    "title",
    "persona",
    "preconditions",
    "procedure",
    "expected_result",
    "evidence_required",
    "severity",
    "status",
    "tester_id",
    "execution_date",
    "environment",
    "revision",
    "observed_result",
    "evidence_refs_json",
    "defect_ids",
    "disposition",
    "remediation",
    "retest_status",
    "retest_date",
    "retest_evidence_refs_json",
    "approver_id",
    "signoff_date",
    "signoff_decision",
    "result_notes",
)

CASE_FAMILIES = {
    **{f"UAT-{number:02d}": "UAT" for number in range(1, 13)},
    **{f"UX-{number:02d}": "Usability" for number in range(1, 9)},
    **{
        f"PEN-{number:02d}": "Manual penetration"
        for number in range(1, 17)
    },
    **{f"A11Y-{number:02d}": "Accessibility" for number in range(1, 9)},
}
EXPECTED_FAMILY_COUNTS = Counter(CASE_FAMILIES.values())
PROTOCOL_TEXT_FIELDS = (
    "title",
    "persona",
    "preconditions",
    "procedure",
    "expected_result",
    "evidence_required",
)
RESULT_FIELDS = (
    "tester_id",
    "execution_date",
    "environment",
    "revision",
    "observed_result",
    "evidence_refs_json",
    "defect_ids",
    "disposition",
    "remediation",
    "retest_status",
    "retest_date",
    "retest_evidence_refs_json",
    "approver_id",
    "signoff_date",
    "signoff_decision",
    "result_notes",
)
EXECUTION_REQUIRED_FIELDS = (
    "tester_id",
    "execution_date",
    "environment",
    "revision",
    "observed_result",
    "evidence_refs_json",
)
STATUSES = {"NOT_RUN", "PASS", "FAIL"}
SEVERITIES = {"critical", "high", "medium", "low"}
RETEST_STATUSES = {"NOT_RUN", "NOT_REQUIRED", "PASS", "FAIL"}
SIGNOFF_DECISIONS = {"APPROVE", "REJECT"}
DATE_RE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")
SHA256_RE = re.compile(r"^[A-Fa-f0-9]{64}$")
DEFECT_ID_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_.:-]{1,63}$")
PLACEHOLDER_RE = re.compile(
    r"(?:REPLACE[_ -]?WITH|\bTODO\b|\bTBD\b|\bCHANGEME\b)", re.IGNORECASE
)


def _duplicates(values: Sequence[str]) -> list[str]:
    counts = Counter(values)
    return sorted(value for value, count in counts.items() if count > 1)


def _header_errors(headers: Sequence[str]) -> list[str]:
    errors: list[str] = []
    duplicate_headers = _duplicates(headers)
    if duplicate_headers:
        errors.append(
            "header has duplicate column(s): " + ", ".join(duplicate_headers)
        )

    header_set = set(headers)
    missing = [column for column in EXPECTED_HEADER if column not in header_set]
    unknown = [column for column in headers if column not in EXPECTED_HEADER]
    if missing:
        errors.append("header is missing column(s): " + ", ".join(missing))
    if unknown:
        errors.append("header has unknown column(s): " + ", ".join(unknown))
    if not missing and not unknown and not duplicate_headers:
        if tuple(headers) != EXPECTED_HEADER:
            errors.append("header columns are not in the required order")
    return errors


def _value(row: Mapping[str, object], field: str) -> str:
    value = row.get(field, "")
    return value.strip() if isinstance(value, str) else ""


def _require_text(
    row: Mapping[str, object], field: str, label: str, errors: list[str]
) -> None:
    value = _value(row, field)
    if not value:
        errors.append(f"{label}: {field} is required")
    elif PLACEHOLDER_RE.search(value):
        errors.append(f"{label}: {field} contains a placeholder token")


def _parse_date(
    value: str, field: str, label: str, errors: list[str]
) -> date | None:
    if not DATE_RE.fullmatch(value):
        errors.append(f"{label}: {field} must use a valid YYYY-MM-DD date")
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        errors.append(f"{label}: {field} must use a valid YYYY-MM-DD date")
        return None


def _parse_evidence_refs(
    value: str,
    field: str,
    label: str,
    errors: list[str],
    *,
    required: bool,
) -> list[dict[str, str]]:
    if not value:
        if required:
            errors.append(f"{label}: {field} requires a nonempty JSON array")
        return []

    try:
        decoded = json.loads(value)
    except json.JSONDecodeError as exc:
        errors.append(f"{label}: {field} is invalid JSON ({exc.msg})")
        return []

    if not isinstance(decoded, list):
        errors.append(f"{label}: {field} must decode to a JSON array")
        return []
    if required and not decoded:
        errors.append(f"{label}: {field} requires at least one evidence reference")
        return []

    allowed_keys = {"artifact_ref", "sha256", "description"}
    required_keys = {"artifact_ref", "sha256"}
    parsed: list[dict[str, str]] = []
    seen_refs: set[str] = set()
    for index, item in enumerate(decoded):
        item_label = f"{label}: {field}[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{item_label} must be an object")
            continue
        keys = set(item)
        missing = sorted(required_keys - keys)
        unknown = sorted(keys - allowed_keys)
        if missing:
            errors.append(f"{item_label} is missing key(s): {', '.join(missing)}")
        if unknown:
            errors.append(f"{item_label} has unknown key(s): {', '.join(unknown)}")

        artifact_ref = item.get("artifact_ref")
        digest = item.get("sha256")
        description = item.get("description")
        if not isinstance(artifact_ref, str) or not artifact_ref.strip():
            errors.append(f"{item_label}.artifact_ref must be a nonempty string")
        elif PLACEHOLDER_RE.search(artifact_ref):
            errors.append(f"{item_label}.artifact_ref contains a placeholder token")
        elif artifact_ref in seen_refs:
            errors.append(f"{item_label}.artifact_ref duplicates an earlier reference")
        else:
            seen_refs.add(artifact_ref)
        if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
            errors.append(f"{item_label}.sha256 must be exactly 64 hexadecimal digits")
        if description is not None and (
            not isinstance(description, str) or not description.strip()
        ):
            errors.append(f"{item_label}.description must be a nonempty string")
        if isinstance(artifact_ref, str) and isinstance(digest, str):
            parsed.append({"artifact_ref": artifact_ref, "sha256": digest})
    return parsed


def _parse_defect_ids(value: str, label: str, errors: list[str]) -> list[str]:
    if not value:
        return []
    ids = [part.strip() for part in value.split("|")]
    if any(not defect_id for defect_id in ids):
        errors.append(f"{label}: defect_ids contains an empty pipe-delimited item")
    for defect_id in ids:
        if defect_id and not DEFECT_ID_RE.fullmatch(defect_id):
            errors.append(f"{label}: invalid defect ID {defect_id!r}")
    duplicates = _duplicates(ids)
    if duplicates:
        errors.append(f"{label}: duplicate defect ID(s): {', '.join(duplicates)}")
    return [defect_id for defect_id in ids if defect_id]


def _validate_signoff(
    row: Mapping[str, object],
    label: str,
    errors: list[str],
    *,
    required: bool,
) -> date | None:
    approver = _value(row, "approver_id")
    signoff_date = _value(row, "signoff_date")
    decision = _value(row, "signoff_decision")
    populated = [bool(approver), bool(signoff_date), bool(decision)]

    if required:
        _require_text(row, "approver_id", label, errors)
        if not signoff_date:
            errors.append(f"{label}: signoff_date is required")
        if decision != "APPROVE":
            errors.append(f"{label}: PASS requires signoff_decision APPROVE")
    elif any(populated) and not all(populated):
        errors.append(
            f"{label}: approver_id, signoff_date, and signoff_decision "
            "must be populated together"
        )

    parsed_date = None
    if signoff_date:
        parsed_date = _parse_date(signoff_date, "signoff_date", label, errors)
    if decision and decision not in SIGNOFF_DECISIONS:
        errors.append(
            f"{label}: signoff_decision must be APPROVE or REJECT"
        )
    if approver and PLACEHOLDER_RE.search(approver):
        errors.append(f"{label}: approver_id contains a placeholder token")
    return parsed_date


def _validate_retest(
    row: Mapping[str, object],
    label: str,
    errors: list[str],
    *,
    main_status: str,
    execution_date: date | None,
) -> date | None:
    status = _value(row, "retest_status")
    date_value = _value(row, "retest_date")
    evidence_value = _value(row, "retest_evidence_refs_json")

    if not status:
        if date_value:
            errors.append(f"{label}: retest_date requires retest_status")
        if evidence_value:
            errors.append(
                f"{label}: retest_evidence_refs_json requires retest_status"
            )
        return None

    if status not in RETEST_STATUSES:
        errors.append(
            f"{label}: retest_status must be one of "
            "FAIL, NOT_REQUIRED, NOT_RUN, PASS"
        )
        return None
    if main_status != "FAIL":
        errors.append(f"{label}: retest fields are only valid for a FAIL result")

    if status in {"NOT_RUN", "NOT_REQUIRED"}:
        if date_value:
            errors.append(f"{label}: {status} retest must not have retest_date")
        if evidence_value:
            errors.append(
                f"{label}: {status} retest must not have retest evidence"
            )
        return None

    if not _value(row, "remediation"):
        errors.append(f"{label}: a completed retest requires remediation details")
    if not date_value:
        errors.append(f"{label}: completed retest requires retest_date")
        parsed_date = None
    else:
        parsed_date = _parse_date(date_value, "retest_date", label, errors)
    _parse_evidence_refs(
        evidence_value,
        "retest_evidence_refs_json",
        label,
        errors,
        required=True,
    )
    if parsed_date and execution_date and parsed_date < execution_date:
        errors.append(f"{label}: retest_date cannot precede execution_date")
    return parsed_date


def _validate_result_fields(
    row: Mapping[str, object], label: str, errors: list[str]
) -> None:
    status = _value(row, "status")
    if status not in STATUSES:
        errors.append(f"{label}: status must be FAIL, NOT_RUN, or PASS")
        return

    if status == "NOT_RUN":
        populated = [field for field in RESULT_FIELDS if _value(row, field)]
        if populated:
            errors.append(
                f"{label}: NOT_RUN must leave all result fields blank; found: "
                + ", ".join(populated)
            )
        return

    for field in EXECUTION_REQUIRED_FIELDS:
        if field != "evidence_refs_json":
            _require_text(row, field, label, errors)
    execution_date_value = _value(row, "execution_date")
    execution_date = (
        _parse_date(execution_date_value, "execution_date", label, errors)
        if execution_date_value
        else None
    )
    _parse_evidence_refs(
        _value(row, "evidence_refs_json"),
        "evidence_refs_json",
        label,
        errors,
        required=True,
    )
    defect_ids = _parse_defect_ids(_value(row, "defect_ids"), label, errors)

    if status == "PASS":
        if defect_ids:
            errors.append(f"{label}: PASS must not list defect_ids")
        for field in ("disposition", "remediation"):
            if _value(row, field):
                errors.append(f"{label}: PASS must leave {field} blank")
        retest_populated = [
            field
            for field in (
                "retest_status",
                "retest_date",
                "retest_evidence_refs_json",
            )
            if _value(row, field)
        ]
        if retest_populated:
            errors.append(f"{label}: PASS must not contain retest fields")
        signoff_date = _validate_signoff(row, label, errors, required=True)
        if signoff_date and execution_date and signoff_date < execution_date:
            errors.append(f"{label}: signoff_date cannot precede execution_date")
        return

    if not defect_ids:
        errors.append(f"{label}: FAIL requires at least one defect_id")
    _require_text(row, "disposition", label, errors)
    retest_date = _validate_retest(
        row,
        label,
        errors,
        main_status=status,
        execution_date=execution_date,
    )
    signoff_date = _validate_signoff(row, label, errors, required=False)
    latest_result_date = retest_date or execution_date
    if signoff_date and latest_result_date and signoff_date < latest_result_date:
        errors.append(
            f"{label}: signoff_date cannot precede the latest execution/retest date"
        )


def validate_manual_rows(
    headers: Sequence[str], rows: Sequence[Mapping[str, object]]
) -> list[str]:
    """Return validation errors for an in-memory manual-result table.

    The function performs no I/O and does not mutate ``headers`` or ``rows``.
    CSV callers should pass ``reader.fieldnames`` and a materialized row list.
    """

    errors = _header_errors(headers)
    if errors:
        return errors

    materialized_rows = list(rows)
    if len(materialized_rows) != len(CASE_FAMILIES):
        errors.append(
            f"inventory must contain exactly {len(CASE_FAMILIES)} rows; "
            f"found {len(materialized_rows)}"
        )

    seen_ids: list[str] = []
    actual_family_counts: Counter[str] = Counter()
    for index, row in enumerate(materialized_rows, start=2):
        label = f"row {index}"
        row_keys = set(row)
        missing_keys = [field for field in EXPECTED_HEADER if field not in row_keys]
        unknown_keys = sorted(
            str(field) for field in row_keys if field not in EXPECTED_HEADER
        )
        if missing_keys:
            errors.append(
                f"{label}: missing field(s): " + ", ".join(missing_keys)
            )
        if unknown_keys:
            errors.append(
                f"{label}: unknown field(s): " + ", ".join(unknown_keys)
            )
        invalid_types = [
            field
            for field in EXPECTED_HEADER
            if field in row and not isinstance(row[field], str)
        ]
        if invalid_types:
            errors.append(
                f"{label}: non-string CSV value(s): " + ", ".join(invalid_types)
            )
        if missing_keys or unknown_keys or invalid_types:
            continue

        case_id = _value(row, "case_id")
        if not case_id:
            errors.append(f"{label}: case_id is required")
        elif case_id not in CASE_FAMILIES:
            errors.append(f"{label}: unknown case_id {case_id!r}")
        else:
            seen_ids.append(case_id)
            expected_family = CASE_FAMILIES[case_id]
            actual_family = _value(row, "test_type")
            actual_family_counts[actual_family] += 1
            if actual_family != expected_family:
                errors.append(
                    f"{label} ({case_id}): test_type must be {expected_family!r}"
                )
            label = f"row {index} ({case_id})"

        for field in PROTOCOL_TEXT_FIELDS:
            _require_text(row, field, label, errors)
        severity = _value(row, "severity")
        if severity not in SEVERITIES:
            errors.append(
                f"{label}: severity must be critical, high, low, or medium"
            )
        _validate_result_fields(row, label, errors)

    duplicate_ids = _duplicates(seen_ids)
    if duplicate_ids:
        errors.append("duplicate case_id(s): " + ", ".join(duplicate_ids))
    missing_ids = sorted(set(CASE_FAMILIES) - set(seen_ids))
    if missing_ids:
        errors.append("missing case_id(s): " + ", ".join(missing_ids))

    if actual_family_counts != EXPECTED_FAMILY_COUNTS:
        rendered_expected = ", ".join(
            f"{family}={count}"
            for family, count in sorted(EXPECTED_FAMILY_COUNTS.items())
        )
        rendered_actual = ", ".join(
            f"{family}={count}"
            for family, count in sorted(actual_family_counts.items())
        ) or "none"
        errors.append(
            "test_type family counts must be "
            f"{rendered_expected}; found {rendered_actual}"
        )
    return errors


def validate_manual_file(path: Path | str) -> list[str]:
    """Load and validate a CSV without changing it or referenced artifacts."""

    csv_path = Path(path)
    try:
        with csv_path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.reader(handle, strict=True)
            try:
                headers = next(reader)
            except StopIteration:
                return ["CSV is empty"]

            rows: list[dict[str, object]] = []
            shape_errors: list[str] = []
            for index, values in enumerate(reader, start=2):
                if len(values) != len(headers):
                    shape_errors.append(
                        f"row {index}: expected {len(headers)} columns; "
                        f"found {len(values)}"
                    )
                    continue
                rows.append(dict(zip(headers, values)))
    except (OSError, UnicodeError, csv.Error) as exc:
        return [f"could not read CSV: {exc}"]

    return shape_errors + validate_manual_rows(headers, rows)


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate the fail-closed UnivAI manual evaluation CSV."
    )
    parser.add_argument(
        "csv_path",
        nargs="?",
        type=Path,
        default=Path(__file__).with_name("manual_test_protocols.csv"),
        help="CSV to validate (default: adjacent manual_test_protocols.csv)",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    errors = validate_manual_file(args.csv_path)
    if errors:
        print(f"INVALID: {args.csv_path} ({len(errors)} error(s))", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(
        f"VALID: {args.csv_path} "
        f"({len(CASE_FAMILIES)} cases; all manual-result invariants satisfied)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
