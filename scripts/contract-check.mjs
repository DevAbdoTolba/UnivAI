import { readFileSync } from "node:fs";
import path from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

export const REQUIRED_MCP_TOOLS = [
  "retrieve_context",
  "ingest_file",
  "list_documents",
  "remove_document",
  "server_info",
];
export const LIVE_STATES = [
  "connecting",
  "preparing",
  "lecturing",
  "asking",
  "listening",
  "review",
  "answering",
  "ended",
];
export const LIVE_TO_APP = ["slide", "state", "answer", "transcript", "progress", "hand"];
export const APP_TO_LIVE = ["raise_hand", "mic", "question", "cancel"];

function requireMatch(text, pattern, label, failures) {
  if (!pattern.test(text)) failures.push(label);
}

export function validateScript(script, label, failures) {
  if (!script.lectureId || !script.title || !Array.isArray(script.segments) || !script.segments.length) {
    failures.push(`${label}: missing lectureId/title/segments`);
    return;
  }
  for (const segment of script.segments) {
    if (
      !Number.isInteger(segment.slide) ||
      !segment.text ||
      !Array.isArray(segment.citations) ||
      !segment.citations.every((item) => Number.isInteger(item.page))
    ) {
      failures.push(`${label}: invalid segment/citation`);
    }
  }
}

export function validateQuiz(quiz, label, failures) {
  if (!Array.isArray(quiz.questions) || !quiz.questions.length) {
    failures.push(`${label}: missing questions`);
    return;
  }
  for (const question of quiz.questions) {
    if (
      question.type !== "mcq" ||
      !Array.isArray(question.options) ||
      question.options.length !== 4 ||
      !["A", "B", "C", "D"].includes(question.correct_option) ||
      !["lecture", "self_study"].includes(question.source)
    ) {
      failures.push(`${label}: invalid question contract`);
    }
  }
}

export function checkContracts(root = process.cwd()) {
  const failures = [];
  const agentMcp = readFileSync(path.join(root, "UnivAI-Agent", "mcp_server.py"), "utf8");
  for (const tool of REQUIRED_MCP_TOOLS) {
    requireMatch(agentMcp, new RegExp(`def\\s+${tool}\\s*\\(`), `Agent MCP tool missing: ${tool}`, failures);
  }

  const liveProtocol = readFileSync(path.join(root, "UnivAI-live", "protocol.py"), "utf8");
  for (const state of LIVE_STATES) {
    requireMatch(liveProtocol, new RegExp(`["']${state}["']`), `Live state missing: ${state}`, failures);
  }
  for (const kind of [...LIVE_TO_APP, ...APP_TO_LIVE]) {
    requireMatch(liveProtocol, new RegExp(`["']${kind}["']`), `Live message missing: ${kind}`, failures);
  }
  requireMatch(liveProtocol, /"lecture-"/, "Live room prefix contract is missing", failures);
  requireMatch(liveProtocol, /"-week-"/, "Live room week delimiter is missing", failures);

  for (let week = 1; week <= 4; week += 1) {
    const folder = path.join(
      root,
      "UnivAI-app",
      "standalone",
      "lectures",
      "S-2026-000042",
      `week-${week}`
    );
    validateScript(
      JSON.parse(readFileSync(path.join(folder, "script.json"), "utf8")),
      `week-${week}/script.json`,
      failures
    );
    validateQuiz(
      JSON.parse(readFileSync(path.join(folder, "quiz.json"), "utf8")),
      `week-${week}/quiz.json`,
      failures
    );
  }

  const examExample = JSON.parse(
    readFileSync(
      path.join(root, "UnivAI-exam_system", "contracts", "result-webhook.example.json"),
      "utf8"
    )
  );
  for (const field of [
    "exam_id",
    "type",
    "student_id",
    "grading_status",
    "integrity_status",
    "policy_action",
    "review_status",
    "report",
  ]) {
    if (!(field in examExample)) failures.push(`Exam webhook field missing: ${field}`);
  }
  if (JSON.stringify(examExample).toLowerCase().includes("cheat")) {
    failures.push("Exam webhook uses guilt terminology");
  }

  const appSizes = readFileSync(path.join(root, "UnivAI-app", "lib", "course-size.ts"), "utf8");
  const agentSizes = readFileSync(path.join(root, "UnivAI-Agent", "contracts.py"), "utf8");
  const expectedSlides = { XS: 3, S: 5, M: 8, L: 12, XL: 16 };
  for (const [name, slides] of Object.entries(expectedSlides)) {
    requireMatch(appSizes, new RegExp(`${name}:\\s*\\{\\s*slides:\\s*${slides}`), `App course size drift: ${name}`, failures);
    requireMatch(agentSizes, new RegExp(`"${name}":\\s*\\{"slides":\\s*${slides}`), `Agent course size drift: ${name}`, failures);
  }

  const envExample = readFileSync(path.join(root, ".env.example"), "utf8");
  for (const variable of [
    "DATABASE_URL",
    "RAG_MCP_URL",
    "MONGODB_URI",
    "EXAM_SYSTEM_URL",
    "LIVEKIT_URL",
    "BETTER_AUTH_SECRET",
    "LECTURES_DIR",
  ]) {
    requireMatch(envExample, new RegExp(`^${variable}=`, "m"), `Root env variable missing: ${variable}`, failures);
  }
  return failures;
}

function main() {
  const failures = checkContracts();
  if (failures.length) {
    failures.forEach((failure) => console.error(`FAIL: ${failure}`));
    process.exitCode = 1;
  } else {
    console.log("PASS: Agent, App, Live, Exam, course-size, fixture, and environment contracts agree.");
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
