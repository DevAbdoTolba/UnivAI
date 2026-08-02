import { readFileSync, readdirSync } from "node:fs";
import { createHash } from "node:crypto";
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

const STARTUP_STAGES = [
  "dispatch",
  "metadata_valid",
  "artifact_loaded",
  "room_connected",
  "track_published",
  "ready_acknowledged",
  "first_frame",
];

function jsonEqual(left, right) {
  return canonicalJson(left) === canonicalJson(right);
}

function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

export function assessmentQuestionHash(question) {
  const immutable = {
    format: question.format,
    prompt: question.prompt,
    options: question.options,
    correct_option: question.correct_option,
    answer_key: question.answer_key,
    rubric: question.rubric,
    difficulty: question.difficulty,
    integration: question.integration,
    objective_ids: question.objective_ids,
    provenance: question.provenance,
  };
  return createHash("sha256").update(canonicalJson(immutable), "utf8").digest("hex");
}

function valueType(value) {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  if (Number.isInteger(value)) return "integer";
  if (typeof value === "number") return "number";
  return typeof value;
}

function typeMatches(value, expected) {
  const actual = valueType(value);
  if (expected === "number") return actual === "number" || actual === "integer";
  return actual === expected;
}

export function validateJsonSchema(value, schema, rootSchema = schema, pointer = "$") {
  const errors = [];
  if (schema.$ref) {
    if (!schema.$ref.startsWith("#/")) return [`${pointer}: external $ref is not supported`];
    const target = schema.$ref
      .slice(2)
      .split("/")
      .reduce((current, part) => current?.[part.replaceAll("~1", "/").replaceAll("~0", "~")], rootSchema);
    return target ? validateJsonSchema(value, target, rootSchema, pointer) : [`${pointer}: unresolved ${schema.$ref}`];
  }
  if (schema.const !== undefined && !jsonEqual(value, schema.const)) errors.push(`${pointer}: must equal ${JSON.stringify(schema.const)}`);
  if (schema.enum && !schema.enum.some((item) => jsonEqual(item, value))) errors.push(`${pointer}: value is outside enum`);
  if (schema.type) {
    const expected = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (!expected.some((type) => typeMatches(value, type))) {
      errors.push(`${pointer}: expected ${expected.join(" or ")}, got ${valueType(value)}`);
      return errors;
    }
  }
  for (const keyword of ["allOf", "anyOf", "oneOf"]) {
    if (!schema[keyword]) continue;
    const results = schema[keyword].map((candidate) => validateJsonSchema(value, candidate, rootSchema, pointer));
    if (keyword === "allOf") results.forEach((result) => errors.push(...result));
    if (keyword === "anyOf" && !results.some((result) => result.length === 0)) errors.push(`${pointer}: no anyOf branch matched`);
    if (keyword === "oneOf" && results.filter((result) => result.length === 0).length !== 1) errors.push(`${pointer}: expected exactly one oneOf match`);
  }
  if (value && typeof value === "object" && !Array.isArray(value)) {
    for (const key of schema.required ?? []) {
      if (!(key in value)) errors.push(`${pointer}: missing required property ${key}`);
    }
    const properties = schema.properties ?? {};
    for (const [key, child] of Object.entries(value)) {
      if (properties[key]) errors.push(...validateJsonSchema(child, properties[key], rootSchema, `${pointer}.${key}`));
      else if (schema.additionalProperties === false) errors.push(`${pointer}: unexpected property ${key}`);
    }
  }
  if (Array.isArray(value)) {
    if (schema.minItems !== undefined && value.length < schema.minItems) errors.push(`${pointer}: requires at least ${schema.minItems} items`);
    if (schema.maxItems !== undefined && value.length > schema.maxItems) errors.push(`${pointer}: allows at most ${schema.maxItems} items`);
    if (schema.uniqueItems) {
      const encoded = value.map(canonicalJson);
      if (new Set(encoded).size !== encoded.length) errors.push(`${pointer}: items must be unique`);
    }
    if (schema.items) value.forEach((item, index) => errors.push(...validateJsonSchema(item, schema.items, rootSchema, `${pointer}[${index}]`)));
  }
  if (typeof value === "string") {
    if (schema.minLength !== undefined && value.length < schema.minLength) errors.push(`${pointer}: shorter than ${schema.minLength}`);
    if (schema.maxLength !== undefined && value.length > schema.maxLength) errors.push(`${pointer}: longer than ${schema.maxLength}`);
    if (schema.pattern && !new RegExp(schema.pattern, "u").test(value)) errors.push(`${pointer}: does not match ${schema.pattern}`);
    if (schema.format === "date-time" && Number.isNaN(Date.parse(value))) errors.push(`${pointer}: invalid date-time`);
  }
  if (typeof value === "number") {
    if (schema.minimum !== undefined && value < schema.minimum) errors.push(`${pointer}: below minimum ${schema.minimum}`);
    if (schema.maximum !== undefined && value > schema.maximum) errors.push(`${pointer}: above maximum ${schema.maximum}`);
    if (schema.exclusiveMinimum !== undefined && value <= schema.exclusiveMinimum) errors.push(`${pointer}: must exceed ${schema.exclusiveMinimum}`);
  }
  return errors;
}

function semanticContractErrors(data) {
  const errors = [];
  const fail = (message) => errors.push(`$: ${message}`);
  if (!data || typeof data !== "object") return errors;

  if (data.schema_version === "content-artifact-v1") {
    const hash = data.content_key?.match(/^sha256:([a-f0-9]{64})\./)?.[1];
    if (hash && hash !== data.original_sha256) fail("content_key does not contain original_sha256");
  }
  if (data.schema_version === "tenant-document-grant-v1") {
    if (data.status === "active" && data.revoked_at !== null) fail("active grant cannot have revoked_at");
    if (data.status === "revoked" && !data.revoked_at) fail("revoked grant requires revoked_at");
  }
  if (data.schema_version === "learning-path-v1") {
    if ((data.path_version === 1) !== (data.parent_path_version === null)) fail("path parent version is inconsistent");
    if (data.path_version > 1 && data.parent_path_version !== data.path_version - 1) fail("path parent must be immediately previous version");
    const books = data.ordered_books ?? [];
    const ids = books.map((book) => book.document_id);
    if (new Set(ids).size !== ids.length) fail("ordered book IDs must be unique");
    books.forEach((book, index) => {
      if (book.position !== index + 1) fail("book positions must be contiguous");
      if (book.week_end < book.week_start) fail("book week boundary is reversed");
      if (index && book.week_start !== books[index - 1].week_end + 1) fail("book week boundaries must be serial");
    });
    const graph = new Map(ids.map((id) => [id, []]));
    for (const edge of data.prerequisite_edges ?? []) {
      if (!graph.has(edge.from_document_id) || !graph.has(edge.to_document_id)) fail("prerequisite edge references an unknown book");
      graph.get(edge.from_document_id)?.push(edge.to_document_id);
      if ((edge.evidence ?? []).filter((item) => item.role === "prerequisite" && item.document_id === edge.from_document_id).length !== 1 ||
          (edge.evidence ?? []).filter((item) => item.role === "dependent" && item.document_id === edge.to_document_id).length !== 1) fail("edge must cite both sides");
      if (data.status === "approved" && edge.confidence < 0.8) fail("low-confidence edge cannot be approved");
      if (ids.indexOf(edge.from_document_id) >= ids.indexOf(edge.to_document_id)) fail("approved order violates a prerequisite edge");
    }
    const visiting = new Set();
    const visited = new Set();
    const hasCycle = (id) => {
      if (visiting.has(id)) return true;
      if (visited.has(id)) return false;
      visiting.add(id);
      if ((graph.get(id) ?? []).some(hasCycle)) return true;
      visiting.delete(id);
      visited.add(id);
      return false;
    };
    if (ids.some(hasCycle)) fail("prerequisite graph contains a cycle");
    if (data.status === "approved") {
      if (data.approval?.approved_version !== data.path_version || !data.approval?.approved_by || !data.approval?.approved_at) fail("approval must bind the exact path version");
      if ((data.warnings ?? []).some((warning) => !warning.resolved)) fail("approved path has unresolved warnings");
    }
  }
  if (data.schema_version === "semester-week-plan-v1") {
    const weeks = data.weeks ?? [];
    if (weeks.length !== data.week_count) fail("week_count does not match weeks");
    weeks.forEach((week, index) => { if (week.week !== index + 1) fail("weeks must be contiguous from one"); });
    const items = data.schedule_items ?? [];
    items.forEach((item, index) => { if (item.sequence !== index + 1) fail("schedule sequence must be contiguous"); });
    for (const week of weeks) {
      const weekItems = items.filter((item) => item.week === week.week);
      const lectures = weekItems.filter((item) => item.session_type === "lecture");
      const sections = weekItems.filter((item) => item.session_type === "section");
      if (lectures.length !== 1 || lectures[0]?.artifact_id !== week.lecture_id) fail(`week ${week.week} must contain its exact lecture`);
      if (week.section_pack_id === null && sections.length) fail(`week ${week.week} has an unapproved section`);
      if (week.section_pack_id !== null) {
        if (sections.length !== 1 || sections[0]?.artifact_id !== week.section_pack_id) fail(`week ${week.week} section does not match its pack`);
        const lectureIndex = items.indexOf(lectures[0]);
        if (items[lectureIndex + 1] !== sections[0]) fail(`week ${week.week} section must immediately follow lecture`);
      }
    }
  }
  if (data.schema_version === "section-pack-v1") {
    const activities = data.activities ?? [];
    if (activities.reduce((sum, item) => sum + item.time_box_minutes, 0) !== data.duration_minutes) fail("activity time boxes must equal duration_minutes");
    activities.forEach((activity, index) => {
      if (activity.order !== index + 1) fail("activity order must be contiguous");
      if (activity.kind === "worked_example" && !(activity.steps ?? []).length) fail("worked example requires steps");
      if ((activity.steps ?? []).some((step) => !(step.provenance ?? []).length)) fail("every worked-example step requires provenance");
      if (activity.kind === "todo" && !activity.todo?.trim()) fail("TODO activity requires actionable text");
      if (!(activity.provenance ?? []).length) fail("every activity requires provenance");
    });
    if (!activities.some((item) => item.kind === "worked_example") || !activities.some((item) => item.kind === "todo")) fail("section requires an example and TODO");
  }
  if (data.schema_version === "section-session-meta-v1" || data.schema_version === "signed-spoken-name-metadata-v1") {
    if (Date.parse(data.expires_at) <= Date.parse(data.issued_at)) fail("expiry must be after issue time");
  }
  if (data.schema_version === "assessment-package-v1") {
    const questions = data.questions ?? [];
    const scope = data.scope ?? {};
    if (data.package_contract !== `${data.kind}-package-v1`) fail("assessment kind does not match package_contract");
    if (questions.length !== data.blueprint?.required_question_count) fail("question count does not match blueprint");
    if (new Set(questions.map((item) => item.question_id)).size !== questions.length || new Set(questions.map((item) => item.question_hash)).size !== questions.length) fail("question IDs and hashes must be unique");
    if (data.kind === "quiz" && (scope.week_numbers?.length !== 1 || scope.semester_complete)) fail("quiz must target exactly one non-complete week");
    if (data.kind === "midterm" && scope.semester_complete) fail("midterm cannot claim semester completion");
    if (data.kind === "final") {
      if (!scope.semester_complete) fail("final requires a complete semester");
      (scope.week_numbers ?? []).forEach((week, index) => { if (week !== index + 1) fail("final weeks must cover the complete contiguous semester"); });
    }
    for (const question of questions) {
      if (question.question_hash !== assessmentQuestionHash(question)) fail(`question ${question.question_id} hash does not match immutable content`);
      if (question.format === "mcq") {
        if (question.options?.length !== 4 || new Set(question.options).size !== 4) fail("MCQ requires four unique options");
        const expected = ["A", "B", "C", "D"];
        if (!expected.includes(question.correct_option) || question.answer_key !== question.correct_option) fail("MCQ key must name one option");
      } else if (question.options?.length || question.correct_option !== null) fail("written question cannot have MCQ options");
      if (question.format === "essay" && !question.rubric) fail("essay requires a rubric");
      for (const source of question.provenance ?? []) {
        if (!(scope.week_numbers ?? []).includes(source.week) || !(scope.chapter_ids ?? []).includes(source.chapter_id)) fail("question provenance is outside approved scope");
        if (source.page_end < source.page_start) fail("question provenance page range is reversed");
      }
      if (!(question.objective_ids ?? []).every((id) => (scope.objective_ids ?? []).includes(id))) fail("question objective is outside approved scope");
    }
    if (questions.filter((item) => item.integration).length < data.blueprint?.integration_minimum) fail("integration minimum is not met");
    const counts = new Map();
    questions.forEach((question) => {
      const week = question.provenance?.[0]?.week;
      counts.set(week, (counts.get(week) ?? 0) + 1);
    });
    if ([...counts.values()].some((count) => count / questions.length > data.blueprint?.max_week_concentration)) fail("week concentration exceeds blueprint");
  }
  if (data.schema_version === "publication-receipt-v1") {
    if (data.status === "accepted" && (data.defects?.length || !data.published_assessment_id || !data.published_version)) fail("accepted receipt must publish without defects");
    if (data.status === "rejected" && (!data.defects?.length || data.published_assessment_id !== null || data.published_version !== null)) fail("rejected receipt must contain defects and no publication");
  }
  if (data.schema_version === "personalized-prompt-manifest-v1") {
    if (data.cache_key?.includes(data.learner_id)) fail("cache key must not expose learner ID");
    if (data.state === "ready" && !(data.clips ?? []).length) fail("ready prompt manifest requires clips");
  }
  if (data.schema_version === "startup-trace-v1") {
    const stages = data.stages ?? [];
    if (!jsonEqual(stages.map((stage) => stage.name), STARTUP_STAGES)) fail("startup stages are missing or out of order");
    for (let index = 1; index < stages.length; index += 1) if (stages[index].elapsed_ms < stages[index - 1].elapsed_ms) fail("startup stage times must be monotonic");
    if (data.ready_ms !== stages.find((stage) => stage.name === "ready_acknowledged")?.elapsed_ms) fail("ready_ms must match ready_acknowledged");
    if (data.first_frame_ms !== stages.find((stage) => stage.name === "first_frame")?.elapsed_ms) fail("first_frame_ms must match first_frame stage");
    if (data.result === "ready" && data.failure_code !== null) fail("ready trace cannot have a failure code");
    if (data.result !== "ready" && !data.failure_code) fail("failed/cancelled trace requires a failure code");
  }
  if (data.schema_version === "cross-service-envelope-v1") {
    if ((data.payload === null) === (data.error === null)) fail("envelope must contain exactly one of payload or error");
  }
  return errors;
}

export function validateContractDocument(data, schema) {
  return [...validateJsonSchema(data, schema), ...semanticContractErrors(data)];
}

export function checkSprint3Contracts(root = process.cwd()) {
  const manifestPath = path.join(root, "tests", "fixtures", "sprint3", "manifest.json");
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  const failures = [];
  for (const entry of manifest) {
    const schema = JSON.parse(readFileSync(path.join(root, entry.schema), "utf8"));
    const fixture = JSON.parse(readFileSync(path.join(root, entry.fixture), "utf8"));
    const errors = validateContractDocument(fixture, schema);
    if (entry.valid && errors.length) failures.push(`${entry.name}: ${errors.join("; ")}`);
    if (!entry.valid && !errors.length) failures.push(`${entry.name}: invalid fixture was accepted`);
  }
  return failures;
}

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

  const standaloneLectureRoot = path.join(
    root,
    "UnivAI-app",
    "standalone",
    "lectures",
    "S-2026-000042"
  );
  const weekFolders = readdirSync(standaloneLectureRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory() && /^week-\d+$/.test(entry.name))
    .map((entry) => entry.name)
    .sort((left, right) => Number(left.slice(5)) - Number(right.slice(5)));
  if (!weekFolders.length) failures.push("App standalone lecture fixtures are missing");
  for (const weekFolder of weekFolders) {
    const folder = path.join(standaloneLectureRoot, weekFolder);
    validateScript(
      JSON.parse(readFileSync(path.join(folder, "script.json"), "utf8")),
      `${weekFolder}/script.json`,
      failures
    );
    validateQuiz(
      JSON.parse(readFileSync(path.join(folder, "quiz.json"), "utf8")),
      `${weekFolder}/quiz.json`,
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
  failures.push(...checkSprint3Contracts(root).map((failure) => `Sprint 3 ${failure}`));
  return failures;
}

function main() {
  if (process.argv.includes("--validate-stdin")) {
    const schemaArg = process.argv[process.argv.indexOf("--validate-stdin") + 1];
    if (!schemaArg) throw new Error("--validate-stdin requires a schema path");
    const schema = JSON.parse(readFileSync(path.resolve(schemaArg), "utf8"));
    const data = JSON.parse(readFileSync(0, "utf8"));
    const failures = validateContractDocument(data, schema);
    if (failures.length) {
      failures.forEach((failure) => console.error(`FAIL: ${failure}`));
      process.exitCode = 1;
    } else console.log("PASS: stdin document satisfies schema and semantic invariants.");
    return;
  }
  const failures = process.argv.includes("--sprint3-only") ? checkSprint3Contracts() : checkContracts();
  if (failures.length) {
    failures.forEach((failure) => console.error(`FAIL: ${failure}`));
    process.exitCode = 1;
  } else {
    console.log("PASS: Agent, App, Live, Exam, Sprint 3 schemas/fixtures, course-size, and environment contracts agree.");
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
