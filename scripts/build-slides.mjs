/**
 * Build a student's premade Slidev decks to static HTML, served by the Next.js
 * app at /slides/<studentId>/week-N/ and embedded in the lecture page's iframe.
 *
 *   node scripts/build-slides.mjs <studentId> [week-N] # one student/week
 *   node scripts/build-slides.mjs               # legacy global lectures/week-N
 *
 * Slidev is invoked via npx so it stays out of the app's dependency tree.
 */
import { execSync } from "child_process";
import { existsSync, mkdirSync, readdirSync } from "fs";
import path from "path";
import { fileURLToPath } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

// A studentId (S-YYYY-NNNNNN) scopes the build to that learner's course.
const sid = process.argv[2] || null;
const requestedWeek = process.argv[3] || null;
const LECTURES = sid ? path.join(ROOT, "lectures", sid) : path.join(ROOT, "lectures");
const OUT = sid
  ? path.join(ROOT, "UnivAI-app", "public", "slides", sid)
  : path.join(ROOT, "UnivAI-app", "public", "slides");
const BASE_PREFIX = sid ? `/slides/${sid}` : "/slides";

if (!existsSync(LECTURES)) {
  console.error(`No ${path.relative(ROOT, LECTURES)}/ directory — nothing to build.`);
  process.exit(1);
}

mkdirSync(OUT, { recursive: true });

const weeks = readdirSync(LECTURES).filter(
  (name) => /^week-\d+$/.test(name) && (!requestedWeek || name === requestedWeek),
);
if (!weeks.length) {
  console.error(`No week-N folders in ${path.relative(ROOT, LECTURES)}/.`);
  process.exit(1);
}

for (const week of weeks) {
  const deck = path.join(LECTURES, week, "slides.md");
  if (!existsSync(deck)) {
    console.warn(`${week}: no slides.md, skipping`);
    continue;
  }
  const outDir = path.join(OUT, week);
  console.log(`Building ${week} → ${path.relative(ROOT, outDir)}/`);
  // Use the locally installed CLI: `npx --yes` cannot install the theme
  // non-interactively, and fails with "theme not found".
  execSync(`npx slidev build "${deck}" --out "${outDir}" --base "${BASE_PREFIX}/${week}/"`, {
    stdio: "inherit",
    cwd: ROOT,
  });
}

console.log(`\nDone. The lecture page serves these from ${BASE_PREFIX}/week-N/.`);
