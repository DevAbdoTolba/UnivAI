import { execFileSync } from "node:child_process";
import path from "node:path";
import process from "node:process";

async function probe(name, url, failures, validate = () => true, expectedStatus = null) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 5000);
  try {
    const response = await fetch(url, { signal: controller.signal, cache: "no-store" });
    const text = await response.text();
    const accepted = expectedStatus === null ? response.ok : response.status === expectedStatus;
    if (!accepted || !validate(text)) throw new Error(`${response.status} ${text.slice(0, 160)}`);
    console.log(`PASS ${name}: ${url}`);
  } catch (error) {
    failures.push(`${name}: ${error.message}`);
    console.error(`FAIL ${name}: ${error.message}`);
  } finally {
    clearTimeout(timer);
  }
}

function inspectContainer(name, failures) {
  try {
    const raw = execFileSync(
      "docker",
      ["inspect", "--format", "{{json .State}}", name],
      { encoding: "utf8" }
    );
    const state = JSON.parse(raw.trim());
    const health = state.Health?.Status ?? "not-configured";
    if (state.Status !== "running" || (state.Health && health !== "healthy")) {
      throw new Error(`status=${state.Status}, health=${health}`);
    }
    console.log(`PASS infrastructure ${name}: status=${state.Status}, health=${health}`);
  } catch (error) {
    failures.push(`infrastructure ${name}: ${error.message}`);
    console.error(`FAIL infrastructure ${name}: ${error.message}`);
  }
}

function inspectPostgresRelations(names, failures) {
  try {
    const quoted = names.map((name) => `'${name}'`).join(", ");
    const sql =
      `SELECT table_name FROM information_schema.tables ` +
      `WHERE table_schema = 'public' AND table_name IN (${quoted}) ORDER BY table_name;`;
    const raw = execFileSync(
      "docker",
      ["exec", "univai-db", "psql", "-U", "univai", "-d", "univai", "-At", "-c", sql],
      { encoding: "utf8" }
    );
    const present = new Set(raw.trim().split(/\r?\n/).filter(Boolean));
    const missing = names.filter((name) => !present.has(name));
    if (missing.length) throw new Error(`missing relations: ${missing.join(", ")}`);
    console.log(`PASS App PostgreSQL relations: ${names.join(", ")}`);
  } catch (error) {
    failures.push(`App PostgreSQL relations: ${error.message}`);
    console.error(`FAIL App PostgreSQL relations: ${error.message}`);
  }
}

async function main() {
  const root = process.cwd();
  const failures = [];
  try {
    execFileSync(process.execPath, ["scripts/submodules-check.mjs"], { cwd: root, stdio: "inherit" });
  } catch {
    failures.push("static submodule validation");
  }
  try {
    execFileSync(process.execPath, ["scripts/contract-check.mjs"], { cwd: root, stdio: "inherit" });
  } catch {
    failures.push("static contract validation");
  }
  try {
    execFileSync(process.execPath, ["scripts/sprint3-smoke.mjs", "--mode", "mock"], {
      cwd: root,
      stdio: "inherit",
    });
  } catch {
    failures.push("Sprint 3 mock learning-flow validation");
  }

  for (const container of [
    "univai-db",
    "univai-qdrant",
    "univai-mongo",
    "univai-livekit",
  ]) {
    inspectContainer(container, failures);
  }
  inspectPostgresRelations(["collections", "documents", "programmes"], failures);
  await probe("App readiness", "http://127.0.0.1:3100/api/health", failures, (text) => {
    const data = JSON.parse(text);
    return data.ok === true && data.ready === true;
  });
  await probe("App virtual clock", "http://127.0.0.1:3100/api/clock", failures);
  await probe("Exam readiness", "http://127.0.0.1:3200/api/health", failures, (text) => {
    const data = JSON.parse(text);
    return data.ok === true && data.ready === true;
  });
  await probe(
    "Exam unauthenticated attempt read fails closed",
    "http://127.0.0.1:3200/api/exams/64b000000000000000000021",
    failures,
    (text) => {
      const data = JSON.parse(text);
      return data.error === "Exam access token is required";
    },
    401
  );
  await probe("LiveKit signalling", "http://127.0.0.1:7880", failures);

  try {
    execFileSync(
      "uv",
      ["run", "--directory", "UnivAI-Agent", "python", path.join(root, "scripts", "check-agent-mcp.py")],
      { cwd: root, stdio: "inherit" }
    );
  } catch {
    failures.push("Agent MCP server_info call");
  }

  try {
    execFileSync("python", ["UnivAI-live/simulate.py", "smoke"], {
      cwd: root,
      stdio: "inherit",
      env: { ...process.env, UNIVAI_MODE: "standalone" },
    });
  } catch {
    failures.push("Live deterministic message contract");
  }

  if (failures.length) {
    failures.forEach((failure) => console.error(`FAILED CHECKPOINT: ${failure}`));
    process.exitCode = 1;
  } else {
    console.log("PASS: lightweight integration smoke completed.");
  }
}

await main();
