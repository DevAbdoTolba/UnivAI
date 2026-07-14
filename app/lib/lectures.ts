import { promises as fs } from "fs";
import path from "path";
import { query } from "./db";
import { now } from "./clock";

/**
 * Lecture content is PREMADE and committed under lectures/week-N/:
 *   slides.md    a Slidev deck (markdown only)
 *   script.json  the narration the Lecturer agent speaks, with page citations
 * Nothing here generates content.
 */

export const REPO_ROOT = path.resolve(process.cwd(), "..");
export const LECTURES_DIR = path.join(REPO_ROOT, "lectures");
export const WEEKS = 4;

export type Segment = { slide: number; text: string; citations: { page: number }[] };
export type Script = { lectureId: string; title: string; segments: Segment[] };

export type Lecture = {
  id: number;
  week: number;
  title: string;
  startsAt: Date;
  /** derived from the VIRTUAL clock, never the wall clock */
  state: "upcoming" | "live" | "done";
};

/** A lecture is joinable from its start time until it ends. */
export const LECTURE_WINDOW_MINUTES = 60;

export async function readScript(week: number): Promise<Script | null> {
  try {
    const raw = await fs.readFile(path.join(LECTURES_DIR, `week-${week}`, "script.json"), "utf-8");
    return JSON.parse(raw) as Script;
  } catch {
    return null;
  }
}

/** Seed the 4-week schedule: one lecture a week, starting tomorrow 10:00 virtual time. */
export async function ensureSchedule(): Promise<void> {
  const existing = await query<{ count: string }>("SELECT COUNT(*)::text AS count FROM lectures");
  if (Number(existing[0]?.count ?? 0) >= WEEKS) return;

  const start = await now();
  start.setUTCDate(start.getUTCDate() + 1);
  start.setUTCHours(10, 0, 0, 0);

  for (let week = 1; week <= WEEKS; week++) {
    const script = await readScript(week);
    const startsAt = new Date(start.getTime() + (week - 1) * 7 * 24 * 60 * 60 * 1000);
    await query(
      `INSERT INTO lectures (week, title, starts_at, status) VALUES ($1, $2, $3, 'ready')
       ON CONFLICT (week) DO NOTHING`,
      [week, script?.title ?? `Week ${week}`, startsAt]
    );
  }
}

export async function getLectures(): Promise<Lecture[]> {
  await ensureSchedule();
  const virtualNow = await now();

  const rows = await query<{ id: number; week: number; title: string; starts_at: Date }>(
    "SELECT id, week, title, starts_at FROM lectures ORDER BY week ASC"
  );

  return rows.map((row) => {
    const startsAt = new Date(row.starts_at);
    const endsAt = new Date(startsAt.getTime() + LECTURE_WINDOW_MINUTES * 60_000);
    let state: Lecture["state"] = "upcoming";
    if (virtualNow >= endsAt) state = "done";
    else if (virtualNow >= startsAt) state = "live";

    return { id: row.id, week: row.week, title: row.title, startsAt, state };
  });
}
