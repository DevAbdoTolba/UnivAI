# infra/ — containers and the database schema

```bash
docker compose -f infra/docker-compose.yml up -d     # or: make up (also applies the schema)
```

| Container | Port | Holds |
|---|---|---|
| `univai-db` (Postgres + pgvector) | **5433** | books, lectures, attendance, grades, qa_log, settings, **clock_state** (the virtual clock) |
| `univai-qdrant` | 6333 | the RAG's vectors — owned by the `UnivAI-Agent` service, never touched from here |
| `univai-livekit` | 7880 (+7881 tcp / 7882 udp) | the local LiveKit server the live lecture runs on (`--dev` keys: devkey/secret) |
| `univai-mongo` | 27017 | the exam system's world (curricula, exams, sessions, proctoring) |

`schema.sql` — idempotent, safe to re-run any time: `make schema`.

Postgres is on **5433** on purpose (5432 is usually taken). Data survives
`make down`; only `make clean` destroys the volumes.
