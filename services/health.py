"""Versioned service/dependency health contract and a small HTTP endpoint."""

from __future__ import annotations

import json
import os
import socket
import urllib.request
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from enum import Enum
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Callable, Iterable
from urllib.parse import urlparse

from services.observability.redaction import redact_text
from services.observability.tracing import configure_json_logging

HEALTH_SCHEMA_VERSION = "univai.health.v1"


class HealthStatus(str, Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNAVAILABLE = "unavailable"


@dataclass(frozen=True)
class DependencyStatus:
    name: str
    status: HealthStatus
    required: bool = True
    detail: str | None = None

    def to_dict(self) -> dict[str, object]:
        value = asdict(self)
        value["status"] = self.status.value
        return {key: item for key, item in value.items() if item is not None}


@dataclass(frozen=True)
class DependencyCheck:
    name: str
    check: Callable[[], HealthStatus | bool]
    required: bool = True


@dataclass(frozen=True)
class HealthReport:
    service: str
    status: HealthStatus
    dependencies: tuple[DependencyStatus, ...]
    checked_at: str
    schema_version: str = HEALTH_SCHEMA_VERSION

    def to_dict(self) -> dict[str, object]:
        return {
            "schema_version": self.schema_version,
            "service": self.service,
            "status": self.status.value,
            "checked_at": self.checked_at,
            "dependencies": [item.to_dict() for item in self.dependencies],
        }


def evaluate_health(
    service: str, checks: Iterable[DependencyCheck] = ()
) -> HealthReport:
    dependencies: list[DependencyStatus] = []
    for dependency in checks:
        try:
            result = dependency.check()
            status = (
                result
                if isinstance(result, HealthStatus)
                else HealthStatus.HEALTHY
                if result
                else HealthStatus.UNAVAILABLE
            )
            detail = None
        except Exception as exc:
            status = HealthStatus.UNAVAILABLE
            detail = redact_text(f"{type(exc).__name__}: {exc}")
        dependencies.append(
            DependencyStatus(dependency.name, status, dependency.required, detail)
        )

    if any(
        item.required and item.status is HealthStatus.UNAVAILABLE
        for item in dependencies
    ):
        overall = HealthStatus.UNAVAILABLE
    elif any(item.status is not HealthStatus.HEALTHY for item in dependencies):
        overall = HealthStatus.DEGRADED
    else:
        overall = HealthStatus.HEALTHY
    return HealthReport(
        service=service,
        status=overall,
        dependencies=tuple(dependencies),
        checked_at=datetime.now(timezone.utc).isoformat(),
    )


def endpoint_check(url: str, timeout: float = 2.0) -> Callable[[], bool]:
    parsed = urlparse(url)
    if parsed.scheme == "tcp":
        if not parsed.hostname or parsed.port is None:
            raise ValueError(f"invalid TCP health URL: {url}")

        def check_tcp() -> bool:
            with socket.create_connection((parsed.hostname, parsed.port), timeout):
                return True

        return check_tcp
    if parsed.scheme not in {"http", "https"}:
        raise ValueError(f"unsupported health URL scheme: {url}")

    def check_http() -> bool:
        request = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return 200 <= response.status < 400

    return check_http


def checks_from_json(value: str) -> list[DependencyCheck]:
    """Parse [{"name", "url", "required"}] without logging configured URLs."""

    raw = json.loads(value or "[]")
    if not isinstance(raw, list):
        raise ValueError("health dependencies must be a JSON array")
    checks: list[DependencyCheck] = []
    for item in raw:
        if not isinstance(item, dict) or not isinstance(item.get("name"), str):
            raise ValueError("each health dependency needs a string name")
        if not isinstance(item.get("url"), str):
            raise ValueError("each health dependency needs a string url")
        checks.append(
            DependencyCheck(
                item["name"],
                endpoint_check(item["url"], float(item.get("timeout", 2))),
                bool(item.get("required", True)),
            )
        )
    return checks


def make_handler(
    service: str, checks: Iterable[DependencyCheck]
) -> type[BaseHTTPRequestHandler]:
    configured_checks = tuple(checks)

    class HealthHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:  # noqa: N802 - stdlib handler contract
            if self.path == "/health/live":
                report = evaluate_health(service)
            elif self.path in {"/health", "/health/ready"}:
                report = evaluate_health(service, configured_checks)
            else:
                self.send_error(HTTPStatus.NOT_FOUND)
                return
            payload = json.dumps(report.to_dict(), separators=(",", ":")).encode()
            code = (
                HTTPStatus.SERVICE_UNAVAILABLE
                if report.status is HealthStatus.UNAVAILABLE
                else HTTPStatus.OK
            )
            self.send_response(code)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, format: str, *args: object) -> None:
            return

    return HealthHandler


def main() -> None:
    configure_json_logging(os.getenv("LOG_LEVEL", "INFO"))
    host = os.getenv("HEALTH_HOST", "0.0.0.0")
    port = int(os.getenv("HEALTH_PORT", "8080"))
    service = os.getenv("SERVICE_NAME", "univai-core")
    checks = checks_from_json(os.getenv("HEALTH_DEPENDENCIES_JSON", "[]"))
    server = ThreadingHTTPServer((host, port), make_handler(service, checks))
    server.serve_forever()


if __name__ == "__main__":
    main()
