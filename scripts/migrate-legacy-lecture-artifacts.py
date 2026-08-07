"""Backfill legacy generated lecture files into PostgreSQL once.

This is a migration utility, not a runtime fallback. Integrated generation and
delivery never call it and never read ``lectures/`` after the backfill.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "services"))

from common.db import connect  # noqa: E402


def _json(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def _structured_slides(markdown: str, script: dict, week: int) -> tuple[dict, dict]:
    title = str(script.get("title") or f"Week {week}").strip()
    segments = script.get("segments") if isinstance(script.get("segments"), list) else []
    narration = {
        int(segment["slide"]): str(segment.get("text") or "").strip()
        for segment in segments
        if isinstance(segment, dict) and isinstance(segment.get("slide"), int)
    }
    slides: list[dict] = []
    for block in re.split(r"(?m)^---\s*$", markdown):
        heading = re.search(r"(?m)^#\s+(.+?)\s*$", block)
        bullets = [match.strip() for match in re.findall(r"(?m)^-\s+(.+?)\s*$", block)]
        page = re.search(r"Source:\s*p\.(\d+)", block, re.IGNORECASE)
        if not heading or not bullets or not page:
            continue
        slide_number = len(slides) + 2
        slides.append(
            {
                "slide": slide_number,
                "heading": heading.group(1).strip(),
                "bullets": bullets,
                "page": int(page.group(1)),
                "narration": narration.get(slide_number, ""),
            }
        )
    if not slides:
        for segment in segments:
            if not isinstance(segment, dict) or int(segment.get("slide") or 0) <= 1:
                continue
            citations = segment.get("citations") or []
            page = citations[0].get("page", 1) if citations and isinstance(citations[0], dict) else 1
            slides.append(
                {
                    "slide": int(segment["slide"]),
                    "heading": f"Slide {segment['slide']}",
                    "bullets": [str(segment.get("text") or "").strip()],
                    "page": int(page),
                    "narration": str(segment.get("text") or "").strip(),
                }
            )
    if not slides:
        raise ValueError(f"week {week} has no usable slides")

    intro = narration.get(1, "")
    duration = int(script.get("durationMinutes") or 45)
    lecture_payload = {
        "title": title,
        "intro": intro,
        "durationMinutes": duration,
        "slides": [
            {
                "heading": slide["heading"],
                "bullets": slide["bullets"],
                "narration": slide["narration"],
                "page": slide["page"],
            }
            for slide in slides
        ],
    }
    slides_payload = {
        "week": week,
        "title": title,
        "slides": [
            {key: slide[key] for key in ("slide", "heading", "bullets", "page")}
            for slide in slides
        ],
    }
    return lecture_payload, slides_payload


def migrate(root: Path, *, dry_run: bool) -> tuple[int, int]:
    learner_count = 0
    week_count = 0
    with connect() as connection, connection.transaction(), connection.cursor() as cursor:
        for learner_root in sorted(root.glob("S-*/")):
            cursor.execute(
                "SELECT id FROM books WHERE student_id = %s ORDER BY id DESC LIMIT 1",
                (learner_root.name,),
            )
            book = cursor.fetchone()
            if not book:
                continue
            learner_weeks = 0
            plan_path = learner_root / "semester-plan.json"
            if plan_path.is_file() and not dry_run:
                cursor.execute(
                    "UPDATE books SET semester_plan = %s::jsonb WHERE id = %s",
                    (json.dumps(_json(plan_path)), book["id"]),
                )

            for week_root in sorted(learner_root.glob("week-*")):
                match = re.fullmatch(r"week-(\d+)", week_root.name)
                required = [week_root / name for name in ("script.json", "slides.md", "quiz.json")]
                if not match or not all(path.is_file() for path in required):
                    continue
                week = int(match.group(1))
                script = _json(required[0])
                lecture, slides = _structured_slides(
                    required[1].read_text(encoding="utf-8"), script, week
                )
                quiz = _json(required[2])
                if not dry_run:
                    cursor.execute(
                        """
                        INSERT INTO lecture_artifacts
                          (artifact_id, book_id, student_id, week, title,
                           lecture_payload, script_payload, slides_payload, quiz_payload)
                        SELECT artifact_id, %s, %s, %s, %s, %s::jsonb,
                               %s::jsonb || jsonb_build_object('lectureId', artifact_id::text),
                               %s::jsonb, %s::jsonb
                          FROM (SELECT gen_random_uuid() AS artifact_id) generated
                        ON CONFLICT (book_id, week) DO UPDATE SET
                          student_id = EXCLUDED.student_id,
                          title = EXCLUDED.title,
                          lecture_payload = EXCLUDED.lecture_payload,
                          script_payload = (EXCLUDED.script_payload - 'lectureId')
                            || jsonb_build_object('lectureId', lecture_artifacts.artifact_id::text),
                          slides_payload = EXCLUDED.slides_payload,
                          quiz_payload = EXCLUDED.quiz_payload,
                          updated_at = CURRENT_TIMESTAMP
                        RETURNING artifact_id
                        """,
                        (
                            book["id"],
                            learner_root.name,
                            week,
                            script.get("title") or f"Week {week}",
                            json.dumps(lecture, ensure_ascii=False),
                            json.dumps(script, ensure_ascii=False),
                            json.dumps(slides, ensure_ascii=False),
                            json.dumps(quiz, ensure_ascii=False),
                        ),
                    )
                    artifact_id = cursor.fetchone()["artifact_id"]
                    cursor.execute(
                        """UPDATE lectures
                              SET lecture_artifact_id = %s, book_id = %s, title = %s
                            WHERE student_id = %s AND week = %s""",
                        (
                            artifact_id,
                            book["id"],
                            script.get("title") or f"Week {week}",
                            learner_root.name,
                            week,
                        ),
                    )
                learner_weeks += 1
                week_count += 1
            if learner_weeks:
                learner_count += 1
    return learner_count, week_count


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=ROOT / "lectures")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    learners, weeks = migrate(args.root.resolve(), dry_run=args.dry_run)
    mode = "validated" if args.dry_run else "migrated"
    print(json.dumps({"ok": True, "mode": mode, "learners": learners, "weeks": weeks}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
