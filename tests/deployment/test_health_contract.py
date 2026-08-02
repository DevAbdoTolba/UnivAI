import json
import threading
import urllib.error
import urllib.request
from http.server import ThreadingHTTPServer

import pytest

from services.health import (
    HEALTH_SCHEMA_VERSION,
    DependencyCheck,
    HealthStatus,
    evaluate_health,
    make_handler,
)


def test_health_distinguishes_all_three_states() -> None:
    healthy = evaluate_health("core", [DependencyCheck("db", lambda: True)])
    degraded = evaluate_health(
        "core", [DependencyCheck("exam", lambda: False, required=False)]
    )
    unavailable = evaluate_health(
        "core", [DependencyCheck("db", lambda: False, required=True)]
    )

    assert healthy.status is HealthStatus.HEALTHY
    assert degraded.status is HealthStatus.DEGRADED
    assert unavailable.status is HealthStatus.UNAVAILABLE
    assert healthy.to_dict()["schema_version"] == HEALTH_SCHEMA_VERSION


def test_failed_check_is_reported_without_exposing_configuration() -> None:
    def fail() -> bool:
        raise TimeoutError("dependency timed out")

    report = evaluate_health("core", [DependencyCheck("rag", fail)])
    dependency = report.to_dict()["dependencies"][0]
    assert report.status is HealthStatus.UNAVAILABLE
    assert dependency["status"] == "unavailable"
    assert dependency["detail"] == "TimeoutError: dependency timed out"


def test_http_readiness_returns_503_but_liveness_stays_200() -> None:
    handler = make_handler("core", [DependencyCheck("db", lambda: False)])
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    base = f"http://127.0.0.1:{server.server_port}"
    try:
        with urllib.request.urlopen(f"{base}/health/live", timeout=2) as response:
            assert response.status == 200
            assert json.load(response)["status"] == "healthy"
        with pytest.raises(urllib.error.HTTPError) as error:
            urllib.request.urlopen(f"{base}/health/ready", timeout=2)
        assert error.value.code == 503
        assert json.load(error.value)["status"] == "unavailable"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)
