import assert from "node:assert/strict";
import test from "node:test";

import {
  checkContracts,
  checkSprint3Contracts,
  validateContractDocument,
  validateQuiz,
  validateScript,
} from "../contract-check.mjs";
import { readFileSync } from "node:fs";
import path from "node:path";
import { parseSubmodules } from "../submodules-check.mjs";

test("gitmodules parser keeps path, URL, and branch", () => {
  const parsed = parseSubmodules(
    "submodule.demo.path Demo\nsubmodule.demo.url https://example.test/demo\nsubmodule.demo.branch main"
  );
  assert.deepEqual(parsed, [
    {
      name: "demo",
      path: "Demo",
      url: "https://example.test/demo",
      branch: "main",
    },
  ]);
});

test("current working contracts validate", () => {
  assert.deepEqual(checkContracts(process.cwd()), []);
});

test("Sprint 3 valid and adversarial fixtures agree with their schemas", () => {
  assert.deepEqual(checkSprint3Contracts(process.cwd()), []);
});

test("Sprint 3 semantic validation rejects stale exact-version approval", () => {
  const root = process.cwd();
  const schema = JSON.parse(
    readFileSync(path.join(root, "docs/contracts/schemas/learning-path-v1.schema.json"), "utf8")
  );
  const fixture = JSON.parse(
    readFileSync(path.join(root, "tests/fixtures/sprint3/valid/learning-path.json"), "utf8")
  );
  fixture.approval.approved_version -= 1;
  assert.match(validateContractDocument(fixture, schema).join("\n"), /exact path version/);
});

test("invalid lecture and quiz fixtures are rejected", () => {
  const failures = [];
  validateScript({ lectureId: 1, title: "Broken", segments: [] }, "script", failures);
  validateQuiz(
    {
      questions: [
        {
          type: "mcq",
          options: ["A", "B"],
          correct_option: "Z",
          source: "invented",
        },
      ],
    },
    "quiz",
    failures
  );
  assert.deepEqual(failures, [
    "script: missing lectureId/title/segments",
    "quiz: invalid question contract",
  ]);
});
