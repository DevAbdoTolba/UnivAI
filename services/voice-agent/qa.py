"""Answering a student's spoken question during a lecture.

Path: STT text -> the team's RAG (over MCP) -> tiny LLM -> short spoken answer.

The one rule that cannot bend: if RAG returns nothing, we say the book does not
cover it. We never invent an answer. Everything is logged to qa_log with the
model that actually served it.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common.clock import now  # noqa: E402
from common.db import execute  # noqa: E402
from common.llm import complete, LLMError  # noqa: E402
from common.rag_client import search_book, RagUnavailable  # noqa: E402

SYSTEM = (
    "You are a university teaching assistant answering a student mid-lecture. "
    "Use ONLY the textbook passages given to you. Never add outside knowledge. "
    "Answer in at most three short spoken sentences, and mention the page number. "
    "If the passages do not answer the question, say so plainly."
)

NOT_IN_BOOK = (
    "That is not covered in your book, so I cannot answer it from the material. "
    "Let us stay with what the text says."
)

TROUBLE = "I had trouble looking that up. Let me continue, and we can come back to it."


async def answer_question(question: str, lecture_id: int | None) -> dict:
    """Returns {answer, pages, model_used}. Never raises: the lecture must go on."""
    pages: list[int] = []
    model_used = ""

    try:
        hits = await search_book(question, top_k=5)
    except RagUnavailable as exc:
        print(f"[qa] RAG not configured: {exc}")
        hits = []
    except Exception as exc:
        print(f"[qa] RAG failed: {exc}")
        _log(lecture_id, question, TROUBLE, [], "")
        return {"answer": TROUBLE, "pages": [], "model_used": ""}

    if not hits:
        _log(lecture_id, question, NOT_IN_BOOK, [], "")
        return {"answer": NOT_IN_BOOK, "pages": [], "model_used": ""}

    passages = []
    for hit in hits:
        page = hit.get("page")
        if isinstance(page, int):
            pages.append(page)
        passages.append(f"[page {page}] {hit.get('text', '')}")

    prompt = (
        f"Student's question: {question}\n\n"
        f"Textbook passages:\n" + "\n\n".join(passages) + "\n\n"
        "Answer the question using only these passages, in at most three spoken sentences."
    )

    try:
        result = complete(prompt, system=SYSTEM)
        answer, model_used = result.text.strip(), result.model_used
    except LLMError as exc:
        # Both primary and fallback are down. Say something graceful and keep lecturing.
        print(f"[qa] all models failed: {exc}")
        answer = TROUBLE

    _log(lecture_id, question, answer, sorted(set(pages)), model_used)
    return {"answer": answer, "pages": sorted(set(pages)), "model_used": model_used}


def _log(lecture_id: int | None, question: str, answer: str, pages: list[int], model: str) -> None:
    import json

    execute(
        "INSERT INTO qa_log (lecture_id, question, answer, citations, model_used, asked_at) "
        "VALUES (%s, %s, %s, %s, %s, %s)",
        (
            lecture_id,
            question,
            answer,
            json.dumps([{"page": p} for p in pages]),
            model or None,
            now(),
        ),
    )
