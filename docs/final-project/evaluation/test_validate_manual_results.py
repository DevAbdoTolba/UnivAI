from __future__ import annotations

import csv
import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path


HERE = Path(__file__).resolve().parent
MODULE_PATH = HERE / "validate_manual_results.py"
MODULE_SPEC = importlib.util.spec_from_file_location(
    "validate_manual_results", MODULE_PATH
)
if MODULE_SPEC is None or MODULE_SPEC.loader is None:
    raise RuntimeError(f"cannot load {MODULE_PATH}")
validator = importlib.util.module_from_spec(MODULE_SPEC)
MODULE_SPEC.loader.exec_module(validator)


GOOD_HASH = "a" * 64


def evidence(reference: str = "artifacts/run-1/screenshot.png") -> str:
    return json.dumps([{"artifact_ref": reference, "sha256": GOOD_HASH}])


def make_rows() -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for case_id, family in validator.CASE_FAMILIES.items():
        row = {field: "" for field in validator.EXPECTED_HEADER}
        row.update(
            {
                "case_id": case_id,
                "test_type": family,
                "title": f"Protocol {case_id}",
                "persona": "Authorized synthetic tester",
                "preconditions": "Isolated release-candidate environment",
                "procedure": "Execute the documented protocol.",
                "expected_result": "The documented outcome is observed.",
                "evidence_required": "Hashed recording and request trace",
                "severity": "high",
                "status": "NOT_RUN",
            }
        )
        rows.append(row)
    return rows


def mark_executed(row: dict[str, str], status: str) -> None:
    row.update(
        {
            "status": status,
            "tester_id": "tester-01",
            "execution_date": "2026-08-10",
            "environment": "staging-isolated",
            "revision": "0123456789abcdef",
            "observed_result": "Observed behavior recorded in the evidence.",
            "evidence_refs_json": evidence(),
        }
    )


class ManualResultValidatorTests(unittest.TestCase):
    def assert_valid(self, rows: list[dict[str, str]]) -> None:
        self.assertEqual(
            validator.validate_manual_rows(validator.EXPECTED_HEADER, rows), []
        )

    def assert_invalid(
        self, rows: list[dict[str, str]], expected_fragment: str
    ) -> None:
        errors = validator.validate_manual_rows(validator.EXPECTED_HEADER, rows)
        self.assertTrue(
            any(expected_fragment in error for error in errors),
            f"{expected_fragment!r} not found in {errors!r}",
        )

    def test_pristine_44_case_not_run_inventory_is_valid(self) -> None:
        self.assert_valid(make_rows())

    def test_valid_pass_and_fail_with_completed_retest(self) -> None:
        rows = make_rows()
        mark_executed(rows[0], "PASS")
        rows[0].update(
            {
                "approver_id": "approver-01",
                "signoff_date": "2026-08-11",
                "signoff_decision": "APPROVE",
                "result_notes": "Signed after evidence review.",
            }
        )
        mark_executed(rows[1], "FAIL")
        rows[1].update(
            {
                "defect_ids": "SEC-101|SEC-102",
                "disposition": "REMEDIATED",
                "remediation": "Patched both authorization checks.",
                "retest_status": "PASS",
                "retest_date": "2026-08-12",
                "retest_evidence_refs_json": evidence(
                    "artifacts/run-1/retest-trace.json"
                ),
                "approver_id": "approver-02",
                "signoff_date": "2026-08-13",
                "signoff_decision": "APPROVE",
            }
        )
        self.assert_valid(rows)

    def test_header_must_be_exact_without_unknowns_or_reordering(self) -> None:
        rows = make_rows()
        headers = list(validator.EXPECTED_HEADER)
        headers[-1] = "mystery"
        errors = validator.validate_manual_rows(headers, rows)
        self.assertTrue(any("missing column" in error for error in errors))
        self.assertTrue(any("unknown column" in error for error in errors))

        reordered = list(validator.EXPECTED_HEADER)
        reordered[0], reordered[1] = reordered[1], reordered[0]
        errors = validator.validate_manual_rows(reordered, rows)
        self.assertTrue(any("required order" in error for error in errors))

    def test_duplicate_missing_and_unknown_case_ids_are_rejected(self) -> None:
        rows = make_rows()
        rows[1]["case_id"] = rows[0]["case_id"]
        self.assert_invalid(rows, "duplicate case_id")
        self.assert_invalid(rows, "missing case_id")

        rows = make_rows()
        rows[0]["case_id"] = "UAT-99"
        self.assert_invalid(rows, "unknown case_id")

    def test_family_and_status_must_match_the_contract(self) -> None:
        rows = make_rows()
        rows[0]["test_type"] = "Usability"
        self.assert_invalid(rows, "test_type must be 'UAT'")

        rows = make_rows()
        rows[0]["status"] = "PENDING"
        self.assert_invalid(rows, "status must be FAIL, NOT_RUN, or PASS")

    def test_not_run_rejects_any_result_or_signoff_material(self) -> None:
        for field, value in (
            ("tester_id", "tester-01"),
            ("evidence_refs_json", "[]"),
            ("defect_ids", "BUG-1"),
            ("signoff_decision", "APPROVE"),
            ("result_notes", "Started"),
        ):
            with self.subTest(field=field):
                rows = make_rows()
                rows[0][field] = value
                self.assert_invalid(rows, "NOT_RUN must leave all result fields blank")

    def test_pass_requires_execution_evidence_and_approval(self) -> None:
        required_cases = (
            ("tester_id", "tester_id is required"),
            ("execution_date", "execution_date is required"),
            ("environment", "environment is required"),
            ("revision", "revision is required"),
            ("observed_result", "observed_result is required"),
            ("evidence_refs_json", "requires a nonempty JSON array"),
            ("approver_id", "approver_id is required"),
            ("signoff_date", "signoff_date is required"),
        )
        for field, expected in required_cases:
            with self.subTest(field=field):
                rows = make_rows()
                mark_executed(rows[0], "PASS")
                rows[0].update(
                    {
                        "approver_id": "approver-01",
                        "signoff_date": "2026-08-11",
                        "signoff_decision": "APPROVE",
                    }
                )
                rows[0][field] = ""
                self.assert_invalid(rows, expected)

        rows = make_rows()
        mark_executed(rows[0], "PASS")
        rows[0].update(
            {
                "approver_id": "approver-01",
                "signoff_date": "2026-08-11",
                "signoff_decision": "REJECT",
            }
        )
        self.assert_invalid(rows, "PASS requires signoff_decision APPROVE")

    def test_pass_rejects_defects_remediation_and_retest_fields(self) -> None:
        for field, value, expected in (
            ("defect_ids", "BUG-1", "PASS must not list defect_ids"),
            ("disposition", "OPEN", "PASS must leave disposition blank"),
            ("remediation", "Patch pending", "PASS must leave remediation blank"),
            ("retest_status", "NOT_RUN", "PASS must not contain retest fields"),
        ):
            with self.subTest(field=field):
                rows = make_rows()
                mark_executed(rows[0], "PASS")
                rows[0].update(
                    {
                        "approver_id": "approver-01",
                        "signoff_date": "2026-08-11",
                        "signoff_decision": "APPROVE",
                        field: value,
                    }
                )
                self.assert_invalid(rows, expected)

    def test_fail_requires_defect_ids_and_disposition(self) -> None:
        rows = make_rows()
        mark_executed(rows[0], "FAIL")
        self.assert_invalid(rows, "FAIL requires at least one defect_id")
        self.assert_invalid(rows, "disposition is required")

    def test_evidence_is_nonempty_strict_json_with_hashes(self) -> None:
        bad_values = (
            ("[]", "at least one evidence reference"),
            ("{}", "must decode to a JSON array"),
            ("not-json", "is invalid JSON"),
            (
                json.dumps([{"artifact_ref": "trace.json", "sha256": "bad"}]),
                "64 hexadecimal digits",
            ),
            (
                json.dumps(
                    [{"artifact_ref": "trace.json", "sha256": GOOD_HASH, "x": 1}]
                ),
                "unknown key",
            ),
        )
        for value, expected in bad_values:
            with self.subTest(value=value):
                rows = make_rows()
                mark_executed(rows[0], "PASS")
                rows[0].update(
                    {
                        "approver_id": "approver-01",
                        "signoff_date": "2026-08-11",
                        "signoff_decision": "APPROVE",
                        "evidence_refs_json": value,
                    }
                )
                self.assert_invalid(rows, expected)

    def test_retest_fields_are_internally_consistent(self) -> None:
        rows = make_rows()
        mark_executed(rows[0], "FAIL")
        rows[0].update(
            {
                "defect_ids": "BUG-1",
                "disposition": "REMEDIATION_PLANNED",
                "remediation": "Apply the authorization patch.",
                "retest_status": "PASS",
            }
        )
        self.assert_invalid(rows, "completed retest requires retest_date")
        self.assert_invalid(rows, "requires a nonempty JSON array")

        rows[0].update(
            {
                "retest_status": "NOT_RUN",
                "retest_date": "2026-08-12",
                "retest_evidence_refs_json": evidence(),
            }
        )
        self.assert_invalid(rows, "NOT_RUN retest must not have retest_date")
        self.assert_invalid(rows, "NOT_RUN retest must not have retest evidence")

    def test_dates_are_real_and_chronological(self) -> None:
        rows = make_rows()
        mark_executed(rows[0], "PASS")
        rows[0].update(
            {
                "execution_date": "2026-02-30",
                "approver_id": "approver-01",
                "signoff_date": "2026-02-01",
                "signoff_decision": "APPROVE",
            }
        )
        self.assert_invalid(rows, "execution_date must use a valid YYYY-MM-DD date")

        rows[0]["execution_date"] = "2026-08-10"
        self.assert_invalid(rows, "signoff_date cannot precede execution_date")

    def test_schema_header_stays_in_sync_with_validator(self) -> None:
        schema_path = Path(__file__).with_name("manual_result_schema.json")
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        self.assertEqual(schema["$schema"], "https://json-schema.org/draft/2020-12/schema")
        self.assertEqual(schema["x-csv-header"], list(validator.EXPECTED_HEADER))
        self.assertFalse(schema["additionalProperties"])

    def test_file_validator_and_cli_are_read_only(self) -> None:
        rows = make_rows()
        buffer = io.StringIO(newline="")
        writer = csv.DictWriter(buffer, fieldnames=validator.EXPECTED_HEADER)
        writer.writeheader()
        writer.writerows(rows)
        content = buffer.getvalue()

        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "manual.csv"
            path.write_text(content, encoding="utf-8", newline="")
            before = path.read_bytes()
            self.assertEqual(validator.validate_manual_file(path), [])
            with redirect_stdout(io.StringIO()):
                self.assertEqual(validator.main([str(path)]), 0)
            self.assertEqual(path.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
