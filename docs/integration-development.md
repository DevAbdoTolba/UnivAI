# Standalone and integration development

## Choose the right checkout

A clone of one sub-repository uses that repository's explicit standalone
command. Standalone modes are deterministic and do not silently activate when
a real dependency fails.

A clone of this main repository uses the four pinned submodule commits and the
real local integration stack:

```bash
git clone --recurse-submodules https://github.com/DevAbdoTolba/UnivAI
cd UnivAI
make setup
make dev-integration
```

On Windows PowerShell:

```powershell
git clone --recurse-submodules https://github.com/DevAbdoTolba/UnivAI
Set-Location UnivAI
./run.ps1 setup
./run.ps1 dev-integration
```

`make dev` and `./run.ps1 dev` keep their existing integrated meaning.
`dev-integration` is an explicit alias, not a fixture mode.

## Integration command family

| Linux/macOS | Windows | Purpose |
|---|---|---|
| `make submodules-check` | `./run.ps1 submodules-check` | Print URL, branch hint, recorded gitlink, checked-out SHA, branch/detached state, and dirtiness. Fails on dirty/missing/mismatched submodules. |
| `make contract-check` | `./run.ps1 contract-check` | Validate Agent MCP, lecture/quiz, Live messages, Exam webhook/policy, course-size, and environment contracts. |
| `make seed-demo` | `./run.ps1 seed-demo` | Apply fixed PostgreSQL and MongoDB demo records for `S-2026-000042`, including a real Better Auth credential account. |
| `make integration-smoke` | `./run.ps1 integration-smoke` | Run strict submodule/static gates, container health, App/Exam readiness, a seeded non-consuming Exam read, virtual clock, real Agent `server_info`, LiveKit signalling, and deterministic Live message validation with bounded timeouts. |
| `make down` | `./run.ps1 down` | Stop containers and preserve volumes. |
| `make clean` | `./run.ps1 clean` | Destructively remove local integration volumes. |

The deterministic smoke never invokes a real course LLM, camera, microphone,
TTS, or STT model. Real-provider checks are optional and explicit.

After `seed-demo`, the local integration login is
`learner@univai.local` / `LearnLocal123!`. These credentials are only for the
loopback development databases.

## Required and optional services

| Component | Default integration requirement | Standalone substitute |
|---|---|---|
| PostgreSQL/Better Auth | Required | App-owned PostgreSQL on 5434 |
| Qdrant/Agent MCP | Required | Deterministic Agent token store |
| MongoDB/Exam | Required | Exam-owned MongoDB on 27018 |
| LiveKit | Required for integrated lecture rooms | Local trace transport |
| Ollama/remote LLM | Required only for real generation/Q&A | Recorded deterministic generation/Q&A |
| TTS/STT models, microphone, camera | Optional real checks | Silent/scripted events |

Local development credentials in examples are loopback-only. Real API keys,
cloud LiveKit secrets, auth secrets, books, and user data must remain outside
Git.

## Git submodule workflow

1. Commit and review work inside the owned sub-repository.
2. Merge that sub-repository change.
3. Check out the merged SHA inside its main-repository submodule path.
4. Stage the submodule path in the main repository; this stages only the new
   gitlink SHA.
5. Run submodule, contract, seed, and integration smoke checks, then commit the
   parent pointer update.

Local file changes and local commits inside a submodule are not automatically
included in a main-repository commit. All branch hints now use `main`; the
parent still pins exact commits and does not use `update --remote` as a release
mechanism.

If a submodule is uninitialised, run `git submodule update --init --recursive`.
If it is dirty, commit/stash its owned work before integration. Detached HEAD
is normal when it equals the parent-recorded gitlink. A SHA mismatch requires
checking out the reviewed recorded/approved commit, not fetching a moving
branch to force success.

## Reproducibility

Integration images are pinned to Qdrant `v1.18.2`, LiveKit Server `v1.13.1`,
MongoDB major 7, PostgreSQL/pgvector major 16. Plain
`docker compose -f infra/docker-compose.yml up -d` still starts the same full
four-service local infrastructure.

Rollback is a parent-only operation: restore the previous reviewed gitlink
SHA, initialise that exact composition, and rerun the contract and integration
smoke commands.
