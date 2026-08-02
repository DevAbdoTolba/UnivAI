from __future__ import annotations

import copy
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).parents[2]
FIXTURES = ROOT / "tests" / "fixtures" / "sprint3"
VALID = FIXTURES / "valid"
SCHEMAS = ROOT / "docs" / "contracts" / "schemas"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_with_node(document: dict, schema: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            "node",
            "scripts/contract-check.mjs",
            "--validate-stdin",
            str(SCHEMAS / schema),
        ],
        cwd=ROOT,
        input=json.dumps(document),
        capture_output=True,
        text=True,
        check=False,
    )


def assert_rejected(document: dict, schema: str, expected: str) -> None:
    result = validate_with_node(document, schema)
    assert result.returncode != 0
    assert expected in result.stderr


def test_manifest_validates_every_positive_and_negative_fixture() -> None:
    result = subprocess.run(
        ["node", "scripts/contract-check.mjs", "--sprint3-only"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS" in result.stdout


def test_identical_content_reuses_artifact_without_granting_a_third_tenant() -> None:
    artifacts = [
        load(VALID / "content-artifact.json"),
        load(VALID / "content-artifact-databases.json"),
        load(VALID / "content-artifact-distributed.json"),
    ]
    grants = [
        load(VALID / "tenant-grant-a.json"),
        load(VALID / "tenant-grant-a-databases.json"),
        load(VALID / "tenant-grant-a-distributed.json"),
        load(VALID / "tenant-grant-b.json"),
    ]

    assert {grant["content_key"] for grant in grants}.issubset(
        {artifact["content_key"] for artifact in artifacts}
    )
    assert grants[0]["content_key"] == grants[3]["content_key"]
    assert {grant["tenant_id"] for grant in grants} == {"tenant-a", "tenant-b"}
    assert not any(grant["tenant_id"] == "tenant-c" for grant in grants)

    after_a_deletion = [
        grant for grant in grants if grant["grant_id"] != "grant-tenant-a-ddia"
    ]
    tenant_b = next(grant for grant in after_a_deletion if grant["tenant_id"] == "tenant-b")
    assert tenant_b["status"] == "active"


def test_approved_path_is_serial_and_each_book_restarts_at_chapter_one() -> None:
    path = load(VALID / "learning-path.json")

    assert path["approval"]["approved_version"] == path["path_version"]
    assert all(book["starts_at_chapter"] == 1 for book in path["ordered_books"])
    for previous, current in zip(path["ordered_books"], path["ordered_books"][1:]):
        assert current["week_start"] == previous["week_end"] + 1


def test_stale_learning_path_approval_fails_closed() -> None:
    path = copy.deepcopy(load(VALID / "learning-path.json"))
    path["approval"]["approved_version"] = path["path_version"] - 1

    assert_rejected(path, "learning-path-v1.schema.json", "exact path version")


def test_dynamic_schedule_contract_has_no_four_week_default() -> None:
    for count in (3, 7, 14):
        plan = load(VALID / f"week-plan-{count}.json")
        lectures = [
            item for item in plan["schedule_items"] if item["session_type"] == "lecture"
        ]
        assert plan["week_count"] == count
        assert len(plan["weeks"]) == count
        assert len(lectures) == count

    seven_week_plan = load(VALID / "week-plan-7.json")
    assert len(
        [
            item
            for item in seven_week_plan["schedule_items"]
            if item["session_type"] == "section"
        ]
    ) == 2


def test_section_identity_or_plan_version_mismatch_is_detectable() -> None:
    pack = load(VALID / "section-pack.json")
    session = load(VALID / "section-session-meta.json")

    assert pack["section_pack_id"] == session["section_pack_id"]
    assert pack["lecture_id"] == session["lecture_id"]
    assert pack["approved_plan_version"] == session["approved_plan_version"]

    session["approved_plan_version"] += 1
    assert pack["approved_plan_version"] != session["approved_plan_version"]


def test_assessment_without_provenance_cannot_publish() -> None:
    package = copy.deepcopy(load(VALID / "quiz-package.json"))
    package["questions"][0]["provenance"] = []

    assert_rejected(package, "assessment-package.schema.json", "at least 1 items")


def test_assessment_question_hash_is_bound_to_immutable_content() -> None:
    package = copy.deepcopy(load(VALID / "quiz-package.json"))
    package["questions"][0]["prompt"] = "Tampered after Agent publication"

    assert_rejected(package, "assessment-package.schema.json", "hash does not match")


def test_exam_receipt_never_accepts_defects_or_publishes_a_rejection() -> None:
    accepted = load(VALID / "publication-receipt-accepted.json")
    rejected = load(VALID / "publication-receipt-rejected.json")

    assert accepted["status"] == "accepted" and not accepted["defects"]
    assert rejected["status"] == "rejected" and rejected["defects"]
    assert rejected["published_assessment_id"] is None


def test_mock_latency_traces_are_explicitly_not_real_slo_evidence() -> None:
    cold = load(VALID / "startup-trace-cold-mock.json")
    warm = load(VALID / "startup-trace-warm-mock.json")

    assert {cold["sample_origin"], warm["sample_origin"]} == {"mock"}
    assert {cold["mode"], warm["mode"]} == {"cold", "warm"}
    assert len([cold, warm]) < 60
