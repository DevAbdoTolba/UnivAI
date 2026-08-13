"""Self-tests for the strict, offline final-project evaluation contract."""

from __future__ import annotations

import copy
import csv
import hashlib
import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path


HERE = Path(__file__).resolve().parent
PACKAGE = HERE.parent


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = load_module("univai_eval_runner", HERE / "run_evaluation.py")
evaluation_data = load_module("univai_eval_data", PACKAGE / "evaluation_data.py")


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_manifest(
    path: Path,
    *,
    dataset_path: Path,
    corpus_path: Path,
    manual_path: Path,
    cases: list[dict[str, str]],
    manual_cases: list[dict[str, str]],
) -> dict:
    manifest = {
        "schema_version": runner.MANIFEST_SCHEMA,
        "dataset_version": cases[0]["dataset_version"],
        "corpus_id": cases[0]["corpus_id"],
        "case_count": len(cases),
        "manual_case_count": len(manual_cases),
        "required_case_count": sum(case["release_gate"] == "required" for case in cases),
        "exploratory_case_count": sum(
            case["release_gate"] == "exploratory" for case in cases
        ),
        "category_counts": dict(
            __import__("collections").Counter(case["category"] for case in cases)
        ),
        "manual_type_counts": dict(
            __import__("collections").Counter(case["test_type"] for case in manual_cases)
        ),
        "ground_truth_status": "author proposed; two-person adjudication required",
        "execution_status": "NOT_RUN",
        "dataset_sha256": file_hash(dataset_path),
        "corpus_sha256": file_hash(corpus_path),
        "manual_protocols_sha256": file_hash(manual_path),
    }
    path.write_text(json.dumps(manifest, ensure_ascii=False), encoding="utf-8")
    return manifest


def captured_mapping(corpus: dict, source_hash: str = "a" * 64) -> dict:
    return {
        "schema_version": runner.CITATION_MAP_SCHEMA,
        "mapping_status": "captured",
        "dataset_version": corpus["dataset_version"],
        "corpus_id": corpus["corpus_id"],
        "captured_at": "2026-08-13T12:00:00+03:00",
        "capture_adapter": "univai-capture-adapter@1.0.0",
        "source_document_sha256": source_hash,
        "mappings": [
            {
                "fixture_id": passage["id"],
                "document_id": "captured-document-001",
                "page": passage["page"],
                "section": passage["section"],
                "excerpt_sha256": hashlib.sha256(passage["text"].encode("utf-8")).hexdigest(),
            }
            for passage in corpus["passages"]
        ],
    }


def valid_run_metadata(hash_value: str = "0" * 64) -> dict:
    return {
        "schema_version": runner.RUN_METADATA_SCHEMA,
        "capture_protocol_version": runner.CAPTURE_PROTOCOL_VERSION,
        "run_id": "eval-run-20260813-001",
        "environment": "isolated-staging",
        "operator_id": "operator-a",
        "capture_command": "python capture.py --run eval-run-20260813-001",
        "captured_at": "2026-08-13T12:00:00+03:00",
        "dataset_sha256": hash_value,
        "corpus_sha256": hash_value,
        "outputs_sha256": hash_value,
        "citation_mapping_sha256": hash_value,
        "core_git_sha": "0123456789abcdef0123456789abcdef01234567",
        "app_git_sha": "1123456789abcdef0123456789abcdef01234567",
        "agent_git_sha": "2123456789abcdef0123456789abcdef01234567",
        "live_git_sha": "3123456789abcdef0123456789abcdef01234567",
        "exam_git_sha": "4123456789abcdef0123456789abcdef01234567",
        "model_configuration": {
            "provider": "local-openai-compatible",
            "model_id": "captured-model-v1",
            "prompt_version": "prompt-v1",
            "temperature": 0,
            "embedding_model": "embedding-v1",
            "sparse_model": "sparse-v1",
            "reranker_model": "reranker-v1",
        },
    }


class EvaluationContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.corpus = json.loads((HERE / "source_fixtures.json").read_text(encoding="utf-8"))
        cls.cases = copy.deepcopy(evaluation_data.LLM_CASES)
        cls.manual_cases = copy.deepcopy(evaluation_data.MANUAL_CASES)

    def test_specification_has_required_scale_categories_and_gates(self) -> None:
        self.assertEqual(len(self.cases), runner.EXACT_CASE_COUNT)
        self.assertEqual({case["category"] for case in self.cases}, runner.REQUIRED_CATEGORIES)
        self.assertEqual(runner.validate_dataset(self.cases, self.corpus), [])
        self.assertEqual(sum(case["release_gate"] == "required" for case in self.cases), 67)
        self.assertEqual(sum(case["release_gate"] == "exploratory" for case in self.cases), 5)

    def test_pending_gold_is_a_valid_spec_but_blocks_scoring(self) -> None:
        self.assertEqual(len(runner.pending_gold_ids(self.cases)), len(self.cases))
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dataset = root / "dataset.csv"
            corpus = root / "corpus.json"
            manual = root / "manual.csv"
            manifest = root / "manifest.json"
            write_csv(dataset, self.cases)
            corpus.write_text(json.dumps(self.corpus, ensure_ascii=False), encoding="utf-8")
            write_csv(manual, self.manual_cases)
            write_manifest(
                manifest,
                dataset_path=dataset,
                corpus_path=corpus,
                manual_path=manual,
                cases=self.cases,
                manual_cases=self.manual_cases,
            )
            output = io.StringIO()
            with redirect_stdout(output), redirect_stderr(output):
                common = [
                    "--dataset",
                    str(dataset),
                    "--corpus",
                    str(corpus),
                    "--manifest",
                    str(manifest),
                    "--manual-protocols",
                    str(manual),
                ]
                validate_code = runner.main([*common, "--validate-only"])
                score_code = runner.main(common)
            self.assertEqual(validate_code, 0)
            self.assertEqual(score_code, 2)
            self.assertIn("SPEC ONLY", output.getvalue())
            self.assertIn("scoring blocked", output.getvalue())

    def test_malformed_spec_errors_are_strict_and_graceful(self) -> None:
        mutations = []

        blank = copy.deepcopy(self.cases)
        blank[0]["case_id"] = " "
        mutations.append((blank, self.corpus, "case_id must be non-empty"))

        duplicate = copy.deepcopy(self.cases)
        duplicate[1]["case_id"] = duplicate[0]["case_id"]
        mutations.append((duplicate, self.corpus, "duplicated"))

        mixed = copy.deepcopy(self.cases)
        mixed[0]["dataset_version"] = "another-version"
        mutations.append((mixed, self.corpus, "exactly one version"))

        invalid_bool = copy.deepcopy(self.cases)
        invalid_bool[0]["must_refuse"] = "yes"
        mutations.append((invalid_bool, self.corpus, "must_refuse must be exactly true or false"))

        invalid_check = copy.deepcopy(self.cases)
        invalid_check[0]["automated_checks"] += ";imaginary_entailment"
        mutations.append((invalid_check, self.corpus, "unsupported automated checks"))

        invalid_subset = copy.deepcopy(self.cases)
        invalid_subset[0]["required_citations"] = "AST-P007"
        mutations.append((invalid_subset, self.corpus, "subset of allowed sources"))

        missing_passage_id = copy.deepcopy(self.corpus)
        del missing_passage_id["passages"][0]["id"]
        mutations.append((self.cases, missing_passage_id, "missing fields"))

        duplicate_passage = copy.deepcopy(self.corpus)
        duplicate_passage["passages"][1]["id"] = duplicate_passage["passages"][0]["id"]
        mutations.append((self.cases, duplicate_passage, "passage ID is duplicated"))

        for cases, corpus, expected in mutations:
            with self.subTest(expected=expected):
                try:
                    errors = runner.validate_dataset(cases, corpus)
                except Exception as error:  # pragma: no cover - the assertion explains regressions
                    self.fail(f"malformed input caused an exception instead of validation errors: {error}")
                self.assertTrue(any(expected in error for error in errors), errors)

    def test_duplicate_outputs_are_rejected(self) -> None:
        case = self.cases[0]
        output = {field: "" for field in runner.OUTPUT_REQUIRED_COLUMNS}
        output.update(
            {
                "case_id": case["case_id"],
                "observed_behavior": case["expected_behavior"],
                "refused": case["must_refuse"],
                "citations_json": "[]",
                "tool_calls_json": "[]",
            }
        )
        errors = runner.validate_outputs([output, copy.deepcopy(output)], {case["case_id"]: case}, {})
        self.assertTrue(any("output case ID is duplicated" in error for error in errors), errors)

    def test_deceptive_lexical_answer_cannot_be_a_final_pass(self) -> None:
        case = copy.deepcopy(next(case for case in self.cases if case["case_id"] == "UAI-GF-001"))
        passage = next(item for item in self.corpus["passages"] if item["id"] == "AST-P004")
        citation = {
            "fixture_id": "AST-P004",
            "document_id": "captured-doc-001",
            "page": passage["page"],
            "section": passage["section"],
            "excerpt_sha256": hashlib.sha256(passage["text"].encode("utf-8")).hexdigest(),
        }
        output = {field: "" for field in runner.OUTPUT_REQUIRED_COLUMNS}
        output.update(
            {
                "case_id": case["case_id"],
                "response": "Discover, verify, and commit are planets; this answer is deliberately false.",
                "observed_behavior": case["expected_behavior"],
                "refused": "false",
                "citations_json": json.dumps([citation]),
                "latency_ms": "10",
                "trace_id": "trace-deceptive",
                "model_id": "test-model",
                "prompt_version": "test-prompt-v1",
                "tool_calls_json": "[]",
                "reviewer_1_id": "reviewer-a",
                "reviewer_1_date": "2026-08-13",
                "reviewer_1_verdict": "FAIL",
                "reviewer_1_semantic_correctness": "FAIL",
                "reviewer_1_claim_entailment": "FAIL",
                "reviewer_1_language_quality": "NA",
                "reviewer_1_attack_handling": "NA",
                "reviewer_2_id": "reviewer-b",
                "reviewer_2_date": "2026-08-13",
                "reviewer_2_verdict": "FAIL",
                "reviewer_2_semantic_correctness": "FAIL",
                "reviewer_2_claim_entailment": "FAIL",
                "reviewer_2_language_quality": "NA",
                "reviewer_2_attack_handling": "NA",
            }
        )
        mapping = {citation["fixture_id"]: citation}
        self.assertEqual(runner.validate_outputs([output], {case["case_id"]: case}, mapping), [])
        result = runner.score_case(case, output, mapping)
        self.assertTrue(result["automated_pass"], "the fixture must prove the lexical false-pass premise")
        self.assertEqual(result["human_status"], "FAIL")
        self.assertEqual(result["status"], "FAIL")
        self.assertFalse(result["automated_entailment_claimed"])

    def test_blank_human_reviews_remain_pending_not_passed(self) -> None:
        case = copy.deepcopy(next(case for case in self.cases if case["case_id"] == "UAI-RF-003"))
        output = {field: "" for field in runner.OUTPUT_REQUIRED_COLUMNS}
        output.update(
            {
                "case_id": case["case_id"],
                "response": case["ground_truth_answer"],
                "observed_behavior": case["expected_behavior"],
                "refused": case["must_refuse"],
                "citations_json": "[]",
                "latency_ms": "10",
                "trace_id": "trace-pending",
                "model_id": "test-model",
                "prompt_version": "test-prompt-v1",
                "tool_calls_json": "[]",
            }
        )
        result = runner.score_case(case, output, {})
        self.assertTrue(result["automated_pass"])
        self.assertEqual(result["status"], "PENDING_HUMAN_REVIEW")

    def test_failed_forbidden_tool_attempt_is_not_treated_as_safe(self) -> None:
        case = copy.deepcopy(next(case for case in self.cases if case["case_id"] == "UAI-DJ-006"))
        output = {field: "" for field in runner.OUTPUT_REQUIRED_COLUMNS}
        output.update(
            {
                "case_id": case["case_id"],
                "response": case["ground_truth_answer"],
                "observed_behavior": case["expected_behavior"],
                "refused": case["must_refuse"],
                "citations_json": "[]",
                "latency_ms": "10",
                "trace_id": "trace-tool",
                "model_id": "test-model",
                "prompt_version": "test-prompt-v1",
                "tool_calls_json": json.dumps(
                    [{"name": "delete_document", "status": "failed", "arguments_sha256": "0" * 64}]
                ),
                "tool_trace_complete": "true",
            }
        )
        result = runner.score_case(case, output, {})
        self.assertFalse(result["automated_checks"]["forbidden_tools_not_attempted"])
        self.assertEqual(result["status"], "FAIL")

    def test_injection_expectations_match_flagged_passage_policy(self) -> None:
        for case_id in ("UAI-IJ-001", "UAI-IJ-002"):
            with self.subTest(case_id=case_id):
                case = next(case for case in self.cases if case["case_id"] == case_id)
                self.assertEqual(case["expected_behavior"], "grounded_refusal")
                self.assertEqual(case["must_refuse"], "true")
                self.assertEqual(case["required_citations"], "")

    def test_dataset_shape_is_exact_not_minimum_only(self) -> None:
        extra = copy.deepcopy(self.cases)
        extra_case = copy.deepcopy(extra[0])
        extra_case["case_id"] = "UAI-GF-999"
        extra.append(extra_case)
        errors = runner.validate_dataset(extra, self.corpus)
        self.assertTrue(any("exactly 72" in error for error in errors), errors)

        gate_flip = copy.deepcopy(self.cases)
        next(case for case in gate_flip if case["release_gate"] == "required")[
            "release_gate"
        ] = "exploratory"
        errors = runner.validate_dataset(gate_flip, self.corpus)
        self.assertTrue(any("release-gate counts" in error for error in errors), errors)

        category_shift = copy.deepcopy(self.cases)
        category_shift[0]["category"] = "multi_hop"
        errors = runner.validate_dataset(category_shift, self.corpus)
        self.assertTrue(any("category counts" in error for error in errors), errors)

    def test_manifest_binds_exact_counts_distributions_and_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            dataset = root / "dataset.csv"
            corpus = root / "corpus.json"
            manual = root / "manual.csv"
            manifest_path = root / "manifest.json"
            write_csv(dataset, self.cases)
            corpus.write_text(json.dumps(self.corpus, ensure_ascii=False), encoding="utf-8")
            write_csv(manual, self.manual_cases)
            manifest = write_manifest(
                manifest_path,
                dataset_path=dataset,
                corpus_path=corpus,
                manual_path=manual,
                cases=self.cases,
                manual_cases=self.manual_cases,
            )
            common = {
                "dataset_sha256": file_hash(dataset),
                "corpus_sha256": file_hash(corpus),
                "manual_protocols_sha256": file_hash(manual),
            }
            self.assertEqual(
                runner.validate_manifest(
                    manifest, self.cases, self.corpus, self.manual_cases, **common
                ),
                [],
            )
            mutations = []
            stale_dataset = copy.deepcopy(manifest)
            stale_dataset["dataset_sha256"] = "f" * 64
            mutations.append((stale_dataset, "dataset_sha256 does not match"))
            stale_corpus = copy.deepcopy(manifest)
            stale_corpus["corpus_sha256"] = "e" * 64
            mutations.append((stale_corpus, "corpus_sha256 does not match"))
            stale_manual = copy.deepcopy(manifest)
            stale_manual["manual_protocols_sha256"] = "d" * 64
            mutations.append((stale_manual, "manual_protocols_sha256 does not match"))
            wrong_count = copy.deepcopy(manifest)
            wrong_count["case_count"] = 73
            mutations.append((wrong_count, "case_count must equal"))
            wrong_gate = copy.deepcopy(manifest)
            wrong_gate["required_case_count"] = 66
            mutations.append((wrong_gate, "required_case_count must equal"))
            wrong_category = copy.deepcopy(manifest)
            wrong_category["category_counts"]["grounded_factual"] = 13
            mutations.append((wrong_category, "category_counts"))
            for candidate, expected in mutations:
                with self.subTest(expected=expected):
                    errors = runner.validate_manifest(
                        candidate, self.cases, self.corpus, self.manual_cases, **common
                    )
                    self.assertTrue(any(expected in error for error in errors), errors)

    def test_citation_map_rejects_placeholders_wrong_locators_and_artifact_hash(self) -> None:
        source_hash = "a" * 64
        mapping = captured_mapping(self.corpus, source_hash)
        self.assertEqual(
            runner.validate_citation_map(
                mapping, self.cases, self.corpus, source_document_sha256=source_hash
            ),
            [],
        )
        mutations = []
        placeholder = copy.deepcopy(mapping)
        placeholder["mappings"][0]["document_id"] = "REPLACE_WITH_CAPTURED_DOCUMENT_ID"
        mutations.append((placeholder, source_hash, "unresolved placeholder"))
        wrong_page = copy.deepcopy(mapping)
        wrong_page["mappings"][0]["page"] = 999
        mutations.append((wrong_page, source_hash, ".page does not match"))
        wrong_section = copy.deepcopy(mapping)
        wrong_section["mappings"][0]["section"] = "wrong section"
        mutations.append((wrong_section, source_hash, ".section does not match"))
        mutations.append((mapping, "b" * 64, "source_document_sha256 does not match"))
        for candidate, actual_hash, expected in mutations:
            with self.subTest(expected=expected):
                errors = runner.validate_citation_map(
                    candidate,
                    self.cases,
                    self.corpus,
                    source_document_sha256=actual_hash,
                )
                self.assertTrue(any(expected in error for error in errors), errors)

    def test_adjudication_is_only_for_disagreement_and_never_overridden_silently(self) -> None:
        case = copy.deepcopy(next(case for case in self.cases if case["case_id"] == "UAI-GF-001"))
        citation = captured_mapping(self.corpus)["mappings"][0]
        mapping = {citation["fixture_id"]: citation}
        output = {field: "" for field in runner.OUTPUT_REQUIRED_COLUMNS}
        output.update(
            {
                "case_id": case["case_id"],
                "response": case["ground_truth_answer"],
                "observed_behavior": case["expected_behavior"],
                "refused": "false",
                "citations_json": json.dumps([citation]),
                "latency_ms": "10",
                "trace_id": "trace-review",
                "model_id": "captured-model-v1",
                "prompt_version": "prompt-v1",
                "tool_calls_json": "[]",
            }
        )
        for reviewer in (1, 2):
            output.update(
                {
                    f"reviewer_{reviewer}_id": f"reviewer-{reviewer}",
                    f"reviewer_{reviewer}_date": "2026-08-13",
                    f"reviewer_{reviewer}_verdict": "PASS",
                    f"reviewer_{reviewer}_semantic_correctness": "PASS",
                    f"reviewer_{reviewer}_claim_entailment": "PASS",
                    f"reviewer_{reviewer}_language_quality": "NA",
                    f"reviewer_{reviewer}_attack_handling": "NA",
                }
            )

        invalid_override = copy.deepcopy(output)
        invalid_override.update(
            {
                "adjudicator_id": "reviewer-3",
                "adjudication_date": "2026-08-13",
                "adjudicator_verdict": "FAIL",
                "adjudicator_notes": "attempted override",
            }
        )
        errors = runner.validate_outputs(
            [invalid_override], {case["case_id"]: case}, mapping
        )
        self.assertTrue(any("only when two completed reviewers disagree" in error for error in errors), errors)
        self.assertNotEqual(runner.score_case(case, invalid_override, mapping)["status"], "PASS")

        disagreement = copy.deepcopy(output)
        disagreement.update(
            {
                "reviewer_2_verdict": "FAIL",
                "reviewer_2_semantic_correctness": "FAIL",
            }
        )
        self.assertEqual(
            runner.validate_outputs([disagreement], {case["case_id"]: case}, mapping), []
        )
        self.assertEqual(
            runner.score_case(case, disagreement, mapping)["status"],
            "PENDING_HUMAN_REVIEW",
        )
        disagreement.update(
            {
                "adjudicator_id": "reviewer-3",
                "adjudication_date": "2026-08-13",
                "adjudicator_verdict": "FAIL",
                "adjudicator_notes": "resolved after independent review",
            }
        )
        self.assertEqual(
            runner.validate_outputs([disagreement], {case["case_id"]: case}, mapping), []
        )
        self.assertEqual(runner.score_case(case, disagreement, mapping)["status"], "FAIL")

    def test_run_metadata_rejects_placeholders_secrets_and_output_mismatch(self) -> None:
        hash_value = "0" * 64
        metadata = valid_run_metadata(hash_value)
        case = next(case for case in self.cases if "model" in case["automated_checks"])
        output = {field: "" for field in runner.OUTPUT_REQUIRED_COLUMNS}
        output.update(
            {
                "case_id": case["case_id"],
                "model_id": "captured-model-v1",
                "prompt_version": "prompt-v1",
            }
        )
        kwargs = {
            "dataset_sha256": hash_value,
            "corpus_sha256": hash_value,
            "outputs_sha256": hash_value,
            "citation_mapping_sha256": hash_value,
            "outputs": [output],
            "dataset_by_id": {case["case_id"]: case},
        }
        self.assertEqual(runner.validate_run_metadata(metadata, **kwargs), [])

        placeholder = copy.deepcopy(metadata)
        placeholder["run_id"] = "REPLACE_WITH_IMMUTABLE_RUN_ID"
        errors = runner.validate_run_metadata(placeholder, **kwargs)
        self.assertTrue(any("unresolved placeholder" in error for error in errors), errors)

        secret = copy.deepcopy(metadata)
        secret["model_configuration"]["api_key"] = "plaintext-secret"
        errors = runner.validate_run_metadata(secret, **kwargs)
        self.assertTrue(any("secret-bearing metadata" in error for error in errors), errors)

        mismatch_output = copy.deepcopy(output)
        mismatch_output["model_id"] = "different-model"
        mismatch_output["prompt_version"] = "different-prompt"
        mismatch_kwargs = {**kwargs, "outputs": [mismatch_output]}
        errors = runner.validate_run_metadata(metadata, **mismatch_kwargs)
        self.assertTrue(any("output model_id does not match" in error for error in errors), errors)
        self.assertTrue(any("output prompt_version does not match" in error for error in errors), errors)

    def test_templates_are_parseable_and_output_header_matches_contract(self) -> None:
        json.loads((HERE / "citation_mapping_template.json").read_text(encoding="utf-8"))
        json.loads((HERE / "run_metadata_template.json").read_text(encoding="utf-8"))
        json.loads((HERE / "citation_mapping_schema.json").read_text(encoding="utf-8"))
        json.loads((HERE / "run_metadata_schema.json").read_text(encoding="utf-8"))
        json.loads((HERE / "model_output_schema.json").read_text(encoding="utf-8"))
        with (HERE / "model_outputs_v2_template.csv").open(encoding="utf-8-sig", newline="") as handle:
            headers = list(csv.DictReader(handle).fieldnames or [])
        self.assertEqual(set(headers), runner.OUTPUT_REQUIRED_COLUMNS)
        self.assertEqual(len(headers), len(runner.OUTPUT_REQUIRED_COLUMNS))
        self.assertFalse((HERE / "model_outputs_template.csv").exists())


if __name__ == "__main__":
    unittest.main()
