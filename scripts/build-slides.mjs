/**
 * Build every premade Slidev deck to static HTML, served by the Next.js app at
 * /slides/week-N/ and embedded in the lecture page's iframe.
 *
 *   node scripts/build-slides.mjs
 *
 * Slidev is invoked via npx so it stays out of the app's dependency tree.
 */
import { execSync } from "child_process";
import { existsSync, mkdirSync, readdirSync } from "fs";
import path from "path";
import { fileURLToPath } from "url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const LECTURES = path.join(ROOT, "lectures");
const OUT = path.join(ROOT, "app", "public", "slides");

if (!existsSync(LECTURES)) {
  console.error("No lectures/ directory — nothing to build.");
  process.exit(1);
}

mkdirSync(OUT, { recursive: true });

const weeks = readdirSync(LECTURES).filter((name) => /^week-\d+$/.test(name));
if (!weeks.length) {
  console.error("No week-N folders in lectures/.");
  process.exit(1);
}

for (const week of weeks) {
  const deck = path.join(LECTURES, week, "slides.md");
  if (!existsSync(deck)) {
    console.warn(`${week}: no slides.md, skipping`);
    continue;
  }
  const outDir = path.join(OUT, week);
  console.log(`Building ${week} → app/public/slides/${week}/`);
  // Use the locally installed CLI: `npx --yes` cannot install the theme
  // non-interactively, and fails with "theme not found".
  execSync(`npx slidev build "${deck}" --out "${outDir}" --base "/slides/${week}/"`, {
    stdio: "inherit",
    cwd: ROOT,
  });
}

console.log("\nDone. The lecture page will serve these from /slides/week-N/.");
