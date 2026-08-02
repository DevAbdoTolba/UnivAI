import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import path from "node:path";
import process from "node:process";

import {
  checkSprint3Contracts,
  validateContractDocument,
} from "./contract-check.mjs";

const ROOT = process.cwd();
const VALID = path.join(ROOT, "tests", "fixtures", "sprint3", "valid");

function load(file) {
  return JSON.parse(readFileSync(file, "utf8"));
}

function fixture(name) {
  return load(path.join(VALID, name));
}

function requireInvariant(condition, message) {
  if (!condition) throw new Error(message);
}

function validate(name, data, schemaRelative) {
  const schema = load(path.join(ROOT, schemaRelative));
  const errors = validateContractDocument(data, schema);
  if (errors.length) throw new Error(`${name}: ${errors.join("; ")}`);
}

function runMock() {
  const failures = checkSprint3Contracts(ROOT);
  requireInvariant(!failures.length, failures.join("\n"));
  console.log("PASS contracts: all canonical valid fixtures pass and all adversarial fixtures fail closed");

  const artifacts = [
    fixture("content-artifact.json"),
    fixture("content-artifact-databases.json"),
    fixture("content-artifact-distributed.json"),
  ];
  const grants = [
    fixture("tenant-grant-a.json"),
    fixture("tenant-grant-a-databases.json"),
    fixture("tenant-grant-a-distributed.json"),
    fixture("tenant-grant-b.json"),
  ];
  const artifactKeys = new Set(artifacts.map((artifact) => artifact.content_key));
  requireInvariant(grants.every((grant) => artifactKeys.has(grant.content_key)), "grant does not resolve to a canonical artifact");
  requireInvariant(grants[0].content_key === grants[3].content_key, "identical bytes did not reuse one artifact");
  const canRetrieve = (tenantId, contentKey, activeGrants = grants) => activeGrants.some(
    (grant) => grant.tenant_id === tenantId && grant.status === "active" && grant.content_key === contentKey
  );
  requireInvariant(artifacts.every((artifact) => canRetrieve("tenant-a", artifact.content_key)), "tenant A multi-book library is incomplete");
  requireInvariant(canRetrieve("tenant-b", artifacts[0].content_key), "tenant B shared artifact grant was denied");
  requireInvariant(artifacts.every((artifact) => !canRetrieve("tenant-c", artifact.content_key)), "tenant without a grant could retrieve content");
  const afterTenantARemoval = grants.filter((grant) => grant.grant_id !== "grant-tenant-a-ddia");
  requireInvariant(canRetrieve("tenant-b", artifacts[0].content_key, afterTenantARemoval), "removing tenant A broke tenant B");
  console.log("PASS tenancy: three books coexist; one artifact is reused by two grants; tenant C is denied; tenant B survives A removal");

  const learningPath = fixture("learning-path.json");
  requireInvariant(
    new Set(grants.filter((grant) => grant.tenant_id === "tenant-a").map((grant) => grant.document_id)).size === learningPath.ordered_books.length &&
      learningPath.ordered_books.every((book) => grants.some((grant) => grant.tenant_id === "tenant-a" && grant.document_id === book.document_id)),
    "approved path contains a book outside tenant A's active grants"
  );
  requireInvariant(learningPath.status === "approved" && learningPath.approval.approved_version === learningPath.path_version, "path approval is stale");
  learningPath.ordered_books.slice(1).forEach((book, index) => {
    const previous = learningPath.ordered_books[index];
    requireInvariant(book.starts_at_chapter === 1 && book.week_start === previous.week_end + 1, "dependent book did not reset to chapter 1 after prerequisite");
  });
  console.log("PASS path: exact approved version preserves serial prerequisite boundaries and chapter-one resets");

  for (const count of [3, 7, 14]) {
    const plan = fixture(`week-plan-${count}.json`);
    requireInvariant(plan.week_count === count, `${count}-week fixture drifted`);
    requireInvariant(plan.schedule_items.filter((item) => item.session_type === "lecture").length === count, `${count}-week lecture count drifted`);
  }
  const plan = fixture("week-plan-7.json");
  requireInvariant(plan.schedule_items.filter((item) => item.session_type === "section").length === 2, "seven-week fixture must have two approved sections");
  console.log("PASS schedule: 3/7/14 dynamic plans have exact lecture counts and typed post-lecture sections");

  const section = fixture("section-pack.json");
  const sectionPacks = [section, fixture("section-pack-week-5.json")];
  const session = fixture("section-session-meta.json");
  requireInvariant(section.section_pack_id === session.section_pack_id && section.lecture_id === session.lecture_id, "section session identity mismatch");
  requireInvariant(section.approved_plan_version === session.approved_plan_version, "section session plan version mismatch");
  requireInvariant(section.activities.some((item) => item.kind === "worked_example") && section.activities.some((item) => item.kind === "todo"), "section lacks example/TODO");
  requireInvariant(
    new Set(plan.schedule_items.filter((item) => item.session_type === "section").map((item) => item.artifact_id)).size === sectionPacks.length &&
      sectionPacks.every((pack) => plan.schedule_items.some((item) => item.session_type === "section" && item.artifact_id === pack.section_pack_id)),
    "scheduled section lacks an approved grounded pack"
  );
  console.log("PASS section: grounded pack and resumable Live metadata bind to one lecture and exact plan version");

  const packages = [fixture("quiz-package.json"), fixture("midterm-package.json"), fixture("final-package.json")];
  requireInvariant(packages.map((item) => item.kind).join(",") === "quiz,midterm,final", "assessment family is incomplete");
  requireInvariant(packages.every((item) => item.questions.every((question) => question.provenance.length)), "ungrounded question reached publication boundary");
  const accepted = fixture("publication-receipt-accepted.json");
  const rejected = fixture("publication-receipt-rejected.json");
  requireInvariant(accepted.status === "accepted" && !accepted.defects.length, "accepted receipt is inconsistent");
  requireInvariant(rejected.status === "rejected" && rejected.defects.length && rejected.published_assessment_id === null, "rejected receipt published content");
  console.log("PASS assessment: Agent packages quiz/midterm/final; Exam receipts accept or reject without generation fallback");

  const promptManifest = fixture("personalized-prompt-manifest.json");
  const signedName = fixture("signed-spoken-name-metadata.json");
  requireInvariant(promptManifest.learner_id === signedName.learner_id && promptManifest.normalized_name_digest === signedName.name_digest, "personalized cache identity mismatch");
  requireInvariant(promptManifest.state === "ready" && promptManifest.clips.length > 0, "personalized cache is not prewarmed");
  console.log("PASS personalization: signed account name resolves to an opaque, checksummed prewarmed cache manifest");

  const traces = [fixture("startup-trace-cold-mock.json"), fixture("startup-trace-warm-mock.json")];
  requireInvariant(traces.every((trace) => trace.sample_origin === "mock"), "mock smoke used measured-looking data");
  console.log("PASS startup contract: deterministic mock traces prove stage ordering only");
  console.log("NOT RUN startup SLO: mock traces cannot satisfy the required 30 cold + 30 warm target-hardware measurements");
}

async function fetchContract(name, url, token, schemaRelative) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(url, {
      headers: { Authorization: `Bearer ${token}`, Accept: "application/json" },
      signal: controller.signal,
      cache: "no-store",
    });
    const body = await response.json();
    if (!response.ok) throw new Error(`HTTP ${response.status}: ${JSON.stringify(body).slice(0, 300)}`);
    const document = body.payload ?? body;
    validate(name, document, schemaRelative);
    console.log(`PASS integrated ${name}: ${url}`);
  } finally {
    clearTimeout(timer);
  }
}

function percentile(values, percentage) {
  const sorted = [...values].sort((left, right) => left - right);
  return sorted[Math.ceil((percentage / 100) * sorted.length) - 1];
}

function validateMeasuredStartupEvidence(file) {
  const evidence = load(path.resolve(file));
  requireInvariant(evidence.configuration && typeof evidence.configuration === "object", "startup evidence lacks the target configuration");
  requireInvariant(Array.isArray(evidence.traces), "startup evidence must contain a traces array");
  const schema = "docs/contracts/schemas/startup-trace-v1.schema.json";
  evidence.traces.forEach((trace, index) => validate(`startup trace ${index + 1}`, trace, schema));
  requireInvariant(evidence.traces.every((trace) => trace.sample_origin === "measured"), "startup evidence contains mock traces");
  const cold = evidence.traces.filter((trace) => trace.mode === "cold");
  const warm = evidence.traces.filter((trace) => trace.mode === "warm");
  requireInvariant(cold.length >= 30 && warm.length >= 30, `startup evidence has ${cold.length} cold and ${warm.length} warm traces; 30 each required`);
  const failures = evidence.traces.filter((trace) => trace.result !== "ready");
  requireInvariant(!failures.length, `startup evidence contains ${failures.length} failed/cancelled runs`);
  const coldP95 = percentile(cold.map((trace) => trace.ready_ms), 95);
  const warmP95 = percentile(warm.map((trace) => trace.ready_ms), 95);
  requireInvariant(coldP95 <= 5000, `cold ready p95 ${coldP95}ms exceeds 5000ms`);
  requireInvariant(warmP95 <= 2000, `warm ready p95 ${warmP95}ms exceeds 2000ms`);
  console.log(`PASS startup SLO: cold n=${cold.length} p50=${percentile(cold.map((item) => item.ready_ms), 50)}ms p95=${coldP95}ms max=${Math.max(...cold.map((item) => item.ready_ms))}ms; warm n=${warm.length} p50=${percentile(warm.map((item) => item.ready_ms), 50)}ms p95=${warmP95}ms max=${Math.max(...warm.map((item) => item.ready_ms))}ms; failures=0`);
}

async function runIntegrated() {
  const token = process.env.SPRINT3_TEST_BEARER_TOKEN;
  const traceFile = process.env.SPRINT3_STARTUP_EVIDENCE_FILE;
  const probes = [
    ["tenant grant", "SPRINT3_GRANT_URL", "docs/contracts/schemas/tenant-document-grant.schema.json"],
    ["learning path", "SPRINT3_LEARNING_PATH_URL", "docs/contracts/schemas/learning-path-v1.schema.json"],
    ["week plan", "SPRINT3_WEEK_PLAN_URL", "docs/contracts/schemas/semester-week-plan.schema.json"],
    ["section pack", "SPRINT3_SECTION_PACK_URL", "docs/contracts/schemas/section-pack-v1.schema.json"],
    ["section session", "SPRINT3_SECTION_SESSION_URL", "docs/contracts/schemas/section-session-meta-v1.schema.json"],
    ["assessment package", "SPRINT3_ASSESSMENT_PACKAGE_URL", "docs/contracts/schemas/assessment-package.schema.json"],
    ["publication receipt", "SPRINT3_PUBLICATION_RECEIPT_URL", "docs/contracts/schemas/publication-receipt.schema.json"],
    ["prompt manifest", "SPRINT3_PROMPT_MANIFEST_URL", "docs/contracts/schemas/personalized-prompt-manifest-v1.schema.json"],
    ["signed name metadata", "SPRINT3_SIGNED_NAME_URL", "docs/contracts/schemas/signed-spoken-name-metadata-v1.schema.json"],
  ];
  const missing = [];
  if (!token) missing.push("SPRINT3_TEST_BEARER_TOKEN");
  if (!traceFile) missing.push("SPRINT3_STARTUP_EVIDENCE_FILE");
  probes.forEach(([, variable]) => { if (!process.env[variable]) missing.push(variable); });
  requireInvariant(!missing.length, `integrated Sprint 3 gate is not configured; missing ${missing.join(", ")}`);
  console.log("Running existing real-stack health and Sprint 3 mock smoke before real probes...");
  execFileSync(process.execPath, ["scripts/integration-smoke.mjs"], { cwd: ROOT, stdio: "inherit" });
  for (const [name, variable, schema] of probes) await fetchContract(name, process.env[variable], token, schema);
  validateMeasuredStartupEvidence(traceFile);
}

const modeIndex = process.argv.indexOf("--mode");
const mode = modeIndex >= 0 ? process.argv[modeIndex + 1] : "mock";
if (!new Set(["mock", "integrated"]).has(mode)) throw new Error("--mode must be mock or integrated");

try {
  if (mode === "mock") runMock();
  else await runIntegrated();
  console.log(`PASS: Sprint 3 ${mode} smoke completed.`);
} catch (error) {
  console.error(`FAIL: Sprint 3 ${mode} smoke: ${error.message}`);
  process.exitCode = 1;
}
