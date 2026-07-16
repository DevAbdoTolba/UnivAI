"""Postgres access for the Python services. Reads the single root .env."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any, Iterable

import psycopg
from psycopg.rows import dict_row
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://univai:univai@localhost:5433/univai"
)


def connect() -> psycopg.Connection:
    # libpq's default connect timeout is INFINITE. Under load this Postgres
    # (Docker, :5433) answers slowly; a caller must never hang on it forever.
    return psycopg.connect(
        DATABASE_URL, row_factory=dict_row, autocommit=True, connect_timeout=5
    )


def fetch_all(sql: str, params: Iterable[Any] = ()) -> list[dict[str, Any]]:
    with connect() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchall()


def fetch_one(sql: str, params: Iterable[Any] = ()) -> dict[str, Any] | None:
    with connect() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
        return cur.fetchone()


def execute(sql: str, params: Iterable[Any] = ()) -> None:
    with connect() as conn, conn.cursor() as cur:
        cur.execute(sql, params)
