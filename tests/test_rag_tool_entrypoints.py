import json
import os
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]


def test_rag_tool_entrypoints_bootstrap_campus_imports(tmp_path: Path) -> None:
    # Core CI intentionally installs only pytest. Supply the one optional
    # import needed while loading rag_client; MCP itself is imported lazily.
    (tmp_path / "dotenv.py").write_text(
        "def load_dotenv(*args, **kwargs):\n    return False\n",
        encoding="utf-8",
    )
    environment = os.environ.copy()
    environment["PYTHONPATH"] = str(tmp_path)

    for relative_path, usage in (
        ("services/rag-tools/rag_ingest.py", "usage: rag_ingest.py"),
        ("services/rag-tools/rag_admin.py", "usage: rag_admin.py"),
        ("services/rag-tools/rag_delete.py", "usage: rag_delete.py"),
    ):
        result = subprocess.run(
            [sys.executable, str(ROOT / relative_path)],
            cwd=tmp_path,
            env=environment,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )

        assert result.returncode == 2
        assert "Traceback" not in result.stderr
        assert usage in json.loads(result.stdout)["error"]
