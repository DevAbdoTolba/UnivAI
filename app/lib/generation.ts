import { spawn } from "child_process";
import { openSync } from "fs";
import path from "path";
import { REPO_ROOT, VENV_PYTHON } from "./python";

/**
 * Fire course generation (services/lecture_gen.py) detached, so it outlives
 * the HTTP request that asked for it. Progress is reported through
 * books.progress; output lands in lecture-gen.log at the repo root.
 */
export function spawnGeneration(pdfPath: string, bookId: number, quizzesOnly = false): void {
  const log = openSync(path.join(REPO_ROOT, "lecture-gen.log"), "a");
  const args = [
    path.join(REPO_ROOT, "services", "lecture_gen.py"),
    pdfPath,
    String(bookId),
  ];
  if (quizzesOnly) args.push("--quizzes-only");

  const child = spawn(VENV_PYTHON, args, {
    cwd: REPO_ROOT,
    windowsHide: true,
    detached: true,
    stdio: ["ignore", log, log],
    // Log lines carry generated titles; without this, one character outside
    // the console codepage kills the whole run with UnicodeEncodeError.
    env: { ...process.env, PYTHONIOENCODING: "utf-8" },
  });
  child.unref();
}
