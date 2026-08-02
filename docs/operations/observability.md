# Observability and incident checks

UnivAI uses `univai.health.v1`, W3C `traceparent`, `X-Request-ID`, and one-line
redacted JSON logs. Docker's rotating `json-file` driver is the selected local
log platform. The format is vendor-neutral so a later collector can ship stdout
without changing application fields.

At the public edge, accept or create a request ID and trace context. Every
internal HTTP/MCP call forwards both headers. A receiving service keeps the
trace ID, creates a child span ID, and returns `X-Request-ID` to the caller.

```bash
docker compose --env-file env.production -f infra/deploy/docker-compose.prod.yml logs --since 10m \
  | grep '"request_id":"REQUEST_ID_FROM_RESPONSE"'
curl --fail https://$DOMAIN/health/live
curl --fail https://$DOMAIN/health/ready
```

`healthy` means all checks passed. `degraded` means only an optional dependency
failed or a dependency reported degraded. `unavailable` means a required
dependency failed and readiness returns HTTP 503. Liveness does not inspect
dependencies, so an orchestrator does not restart a healthy process during a
database outage.

The logger redacts secret-shaped keys, bearer credentials, URL credentials,
email, phone, government ID, payment card, IP address, transcripts, recordings,
and binary media. Never add prompt text or raw private audio as a trace attribute.
Trace metadata is operational data: restrict log access and use the rotation in
the production Compose file.

The in-memory rate limiter is process-local and suitable for the documented
single instance per service. Multiple replicas require a shared atomic backend
before they are exposed through the same public route.

Resolve the client IP at the trusted Caddy boundary. An application must not use
an arbitrary client-supplied `X-Forwarded-For` value as the limiter identity.
