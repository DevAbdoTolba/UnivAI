import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import path from "node:path";
import process from "node:process";
import { pathToFileURL } from "node:url";

export function git(args, options = {}) {
  return execFileSync("git", args, {
    cwd: options.cwd ?? process.cwd(),
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

export function parseSubmodules(configText) {
  const modules = new Map();
  for (const line of configText.split(/\r?\n/)) {
    const match = line.match(/^submodule\.([^.]+)\.(path|url|branch)\s+(.+)$/);
    if (!match) continue;
    const [, name, key, value] = match;
    modules.set(name, { ...(modules.get(name) ?? { name }), [key]: value });
  }
  return [...modules.values()];
}

export function inspectSubmodules({ allowDirty = false } = {}) {
  const root = git(["rev-parse", "--show-toplevel"]);
  const configText = git([
    "config",
    "--file",
    ".gitmodules",
    "--get-regexp",
    String.raw`submodule\..*\.(path|url|branch)`,
  ]);
  const modules = parseSubmodules(configText);
  const failures = [];
  const rows = [];

  for (const module of modules) {
    const absolute = path.join(root, module.path);
    if (!existsSync(absolute) || !existsSync(path.join(absolute, ".git"))) {
      failures.push(`${module.path}: uninitialised or missing`);
      rows.push({ ...module, recorded: "missing", head: "missing", dirty: "unknown" });
      continue;
    }
    let recorded = "";
    let head = "";
    let status = "";
    try {
      const tree = git(["ls-tree", "HEAD", "--", module.path], { cwd: root });
      recorded = tree.split(/\s+/)[2] ?? "";
      head = git(["rev-parse", "HEAD"], { cwd: absolute });
      status = git(["status", "--porcelain=v1", "--untracked-files=all"], {
        cwd: absolute,
      });
    } catch (error) {
      failures.push(`${module.path}: ${error.message}`);
    }
    const dirty = Boolean(status);
    let branch = "(detached pinned commit)";
    try {
      branch = git(["symbolic-ref", "--short", "HEAD"], { cwd: absolute });
    } catch {
      // Detached HEAD is normal for a pinned submodule.
    }
    if (recorded !== head) failures.push(`${module.path}: checked out HEAD does not match gitlink`);
    if (dirty && !allowDirty) failures.push(`${module.path}: working tree is dirty`);
    rows.push({
      ...module,
      recorded,
      head,
      dirty: dirty ? "yes" : "no",
      checkout: branch,
    });
  }
  return { root, rows, failures };
}

function main() {
  const allowDirty = process.argv.includes("--allow-dirty");
  const result = inspectSubmodules({ allowDirty });
  console.table(result.rows);
  console.log(
    "A main-repository commit stores only each submodule gitlink SHA. Local files and local commits inside a submodule are not included automatically."
  );
  if (result.failures.length) {
    for (const failure of result.failures) console.error(`FAIL: ${failure}`);
    process.exitCode = 1;
  } else {
    console.log("PASS: all declared submodules are initialised and match their pinned commits.");
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) main();
