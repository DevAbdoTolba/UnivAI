from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def test_core_contract_files_are_present() -> None:
    expected = [
        ROOT / "infra" / "docker-compose.yml",
        ROOT / "infra" / "schema.sql",
        ROOT / "services" / "common" / "db.py",
        ROOT / "services" / "common" / "llm.py",
        ROOT / "services" / "common" / "rag_client.py",
    ]

    assert all(path.is_file() for path in expected)


def test_core_compose_declares_required_services() -> None:
    compose = (ROOT / "infra" / "docker-compose.yml").read_text(encoding="utf-8")

    for service in ("db:", "qdrant:", "livekit:", "mongo:"):
        assert service in compose
