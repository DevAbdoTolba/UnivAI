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

# The RAG service always returns nearest neighbours — even for a question the book
# does not cover, a vector search still hands back its closest chunks. So an empty
# result is NOT how we detect "not in the book": the model has to refuse when the
# passages it was given do not actually answer the question. Hence the blunt prompt.
#
# The model must NOT speak page numbers either: asked to, a small model invents them
# (observed: it said "page 4" for a passage that came from page 2). The true page comes
# from the RAG metadata and we append it ourselves, below.
SYSTEM = (
    "You are a university teaching assistant answering a student mid-lecture. "
    "Use ONLY the textbook passages given to you. Never add outside knowledge. "
    "The passages are the closest matches found, and they may be irrelevant: if they "
    "do not actually answer the question, reply exactly 'That is not covered in your "
    "book.' and nothing else. Otherwise answer in at most three short spoken sentences. "
    "Never state a page or chunk number — the page reference is added for you."
)

NOT_COVERED = "that is not covered in your book"

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

    # Their reranker can hand back the same chunk twice; feeding duplicates to a small
    # model just wastes its context.
    passages = []
    seen: set[str] = set()
    for hit in hits:
        text = (hit.get("text") or "").strip()
        if not text or text in seen:
            continue
        seen.add(text)
        page = hit.get("page")
        if isinstance(page, int):
            pages.append(page)
        passages.append(f"[page {page}] {text}")

    prompt = (
        f"Student's question: {question}\n\n"
        "Textbook passages:\n" + "\n\n".join(passages) + "\n\n"
        "Answer the question using only these passages, in at most three spoken sentences."
    )

    try:
        result = complete(prompt, system=SYSTEM)
        answer, model_used = result.text.strip(), result.model_used
    except LLMError as exc:
        # Both primary and fallback are down. Say something graceful and keep lecturing.
        print(f"[qa] all models failed: {exc}")
        answer = TROUBLE

    cited = sorted(set(pages))

    # The page reference is OURS, taken from the RAG metadata — never the model's word.
    refused = NOT_COVERED in answer.lower()
    if cited and not refused and answer != TROUBLE:
        where = f"page {cited[0]}" if len(cited) == 1 else f"pages {cited[0]} and {cited[1]}"
        answer = f"{answer.rstrip('.')}. You can read that on {where}."
    if refused:
        cited = []

    _log(lecture_id, question, answer, cited, model_used)
    return {"answer": answer, "pages": cited, "model_used": model_used}


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
