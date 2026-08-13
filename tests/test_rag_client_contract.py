from __future__ import annotations

import asyncio
from html import escape
import json

import pytest

from services.common import rag_client


def _quoted_passage(citation: str, content: str) -> str:
    payload = json.dumps(
        {
            "schema_name": "univai.rag.retrieved-passage",
            "schema_version": "1.0.0",
            "citation": citation,
            "content": content,
        },
        ensure_ascii=False,
        sort_keys=True,
    )
    return (
        '<untrusted-data name="retrieved-passage" encoding="html-escaped">\n'
        f"{escape(payload, quote=True)}\n"
        "</untrusted-data>"
    )


def test_parse_hits_decodes_current_mcp_trust_boundary() -> None:
    rendered = _quoted_passage(
        "[1] Source: systems.pdf | Page: 12 | Chunk: 4/20 | Score: 7.1250",
        "A mutex protects the critical section.",
    )

    assert rag_client.parse_hits(rendered) == [
        {
            "source": "systems.pdf",
            "page": 12,
            "score": 7.125,
            "text": "A mutex protects the critical section.",
            "chunk_id": "4/20",
        }
    ]


def test_parse_hits_preserves_rolling_upgrade_legacy_format() -> None:
    rendered = (
        "[1] Source: systems.pdf | Page: 8 | Chunk: 2/20 | Score: 0.7500\n"
        "Content: Deadlock requires circular wait."
    )

    assert rag_client.parse_hits(rendered)[0] == {
        "source": "systems.pdf",
        "page": 8,
        "score": 0.75,
        "text": "Deadlock requires circular wait.",
        "chunk_id": "2/20",
    }


def test_parse_hits_accepts_structured_grounded_contract() -> None:
    rendered = json.dumps(
        {
            "grounded": True,
            "passages": [
                {
                    "content": "Virtual memory maps pages to frames.",
                    "score": 4.2,
                    "citation": {
                        "book_title": "Operating Systems",
                        "source_filename": "os.pdf",
                        "page": 31,
                        "chunk_index": 9,
                    },
                }
            ],
        }
    )

    assert rag_client.parse_hits(rendered)[0] == {
        "source": "os.pdf",
        "page": 31,
        "score": 4.2,
        "text": "Virtual memory maps pages to frames.",
        "chunk_id": "9",
    }


def test_search_book_does_not_turn_unknown_mcp_output_into_no_evidence(monkeypatch) -> None:
    async def malformed(*_args, **_kwargs) -> str:
        return "Error during retrieval: qdrant unavailable"

    monkeypatch.setattr(rag_client, "_call_tool", malformed)

    with pytest.raises(rag_client.RagUnavailable, match="failed"):
        asyncio.run(rag_client.search_book("What is a mutex?", user_id="S-2026-000001"))


def test_search_book_returns_current_mcp_passages(monkeypatch) -> None:
    rendered = _quoted_passage(
        "[1] Source: systems.pdf | Page: 12 | Chunk: 4/20 | Score: 1.5000",
        "A mutex protects the critical section.",
    )

    async def retrieve(*_args, **_kwargs) -> str:
        return rendered

    monkeypatch.setattr(rag_client, "_call_tool", retrieve)

    hits = asyncio.run(
        rag_client.search_book("What is a mutex?", user_id="S-2026-000001")
    )
    assert len(hits) == 1
    assert hits[0]["page"] == 12


def test_zero_score_setting_keeps_top_ranked_negative_cross_encoder_hit(monkeypatch) -> None:
    rendered = _quoted_passage(
        "[1] Source: systems.pdf | Page: 18 | Chunk: 7/20 | Score: -1.2400",
        "A page fault loads a missing virtual page.",
    )

    async def retrieve(*_args, **_kwargs) -> str:
        return rendered

    monkeypatch.setattr(rag_client, "_call_tool", retrieve)
    monkeypatch.setattr(rag_client, "RAG_MIN_SCORE", None)

    hits = asyncio.run(
        rag_client.search_book("What is a page fault?", user_id="S-2026-000001")
    )
    assert [hit["score"] for hit in hits] == [-1.24]
