import json
import logging

from services.observability.redaction import REDACTED_MEDIA, REDACTED_SECRET, redact
from services.observability.tracing import JsonFormatter, trace_headers, trace_scope


def test_recursively_redacts_secrets_pii_and_audio() -> None:
    raw = {
        "authorization": "Bearer should-never-appear",
        "profile": {"email": "learner@example.com", "ip": "192.0.2.42"},
        "audio_bytes": b"private recording",
        "message": "password=hunter2",
    }
    safe = redact(raw)
    serialized = json.dumps(safe)

    assert safe["authorization"] == REDACTED_SECRET
    assert safe["audio_bytes"] == REDACTED_MEDIA
    for private_value in (
        "should-never-appear",
        "learner@example.com",
        "192.0.2.42",
        "private recording",
        "hunter2",
    ):
        assert private_value not in serialized


def test_trace_is_propagated_and_child_span_is_created() -> None:
    incoming = {
        "X-Request-ID": "request-123",
        "traceparent": "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01",
    }
    with trace_scope(incoming) as context:
        outgoing = trace_headers()

    assert context.request_id == "request-123"
    assert context.trace_id == "0123456789abcdef0123456789abcdef"
    assert context.span_id != "0123456789abcdef"
    assert outgoing["X-Request-ID"] == "request-123"
    assert outgoing["traceparent"].split("-")[1] == context.trace_id


def test_json_formatter_adds_trace_and_redacts_fields() -> None:
    formatter = JsonFormatter()
    record = logging.LogRecord(
        "test", logging.INFO, __file__, 1, "student=%s", ("sam@example.com",), None
    )
    record.event_fields = {"api_key": "secret-value", "result": "ok"}
    with trace_scope(request_id="request-456") as context:
        payload = json.loads(formatter.format(record))

    assert payload["request_id"] == "request-456"
    assert payload["trace_id"] == context.trace_id
    assert "sam@example.com" not in payload["message"]
    assert payload["fields"]["api_key"] == REDACTED_SECRET
