import assert from "node:assert/strict";
import test from "node:test";

import {
  checkContracts,
  validateQuiz,
  validateScript,
} from "../contract-check.mjs";
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
