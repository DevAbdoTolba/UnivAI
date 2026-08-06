# UnivAI — one entry point for the whole stack.
#
# Windows has no `make` by default. Either install it
#   (winget install ezwinports.make), or use the PowerShell twin:
#   ./run.ps1 <target>          — same target names, same behaviour.
#
# Run `make` on its own to see every target.

SHELL := /bin/bash
.DEFAULT_GOAL := help

ifeq ($(OS),Windows_NT)

POWERSHELL ?= powershell
WIN_TARGETS := help install setup env models up down schema migrate seed seed-data seed-auth seed-demo submodules-check contract-check sprint3-smoke integration-smoke rag-models rag-cache-clean reset rag rag-db rag-down rag-logs rag-stop app worker exams slides dev dev-integration dev-stop dev-restart status clean
WIN_ALIAS_TARGETS := install_w setup_w env_w models_w up_w down_w schema_w migrate_w seed_w seed-data_w seed-auth_w seed-demo_w submodules-check_w contract-check_w sprint3-smoke_w integration-smoke_w rag-models_w rag-cache-clean_w reset_w rag_w rag-db_w rag-down_w rag-logs_w rag-stop_w app_w worker_w exams_w slides_w dev_w dev-integration_w dev-stop_w dev-restart_w status_w clean_w

.PHONY: $(WIN_TARGETS) $(WIN_ALIAS_TARGETS) install-node node-check

help: ## Show this help
	@$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File .\run.ps1 help
	@echo.
	@echo Windows aliases are also available: make up_w, make dev_w, make migrate_w, make seed_w, etc.

install setup env models up down schema migrate seed seed-data seed-auth seed-demo submodules-check contract-check sprint3-smoke integration-smoke rag-models rag-cache-clean reset rag rag-db rag-down rag-logs rag-stop app worker exams slides dev dev-integration dev-stop dev-restart status clean:
	@$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File .\run.ps1 $@

install-node node-check:
	@$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File .\run.ps1 install

install_w setup_w env_w models_w up_w down_w schema_w migrate_w seed_w seed-data_w seed-auth_w seed-demo_w submodules-check_w contract-check_w sprint3-smoke_w integration-smoke_w rag-models_w rag-cache-clean_w reset_w rag_w rag-db_w rag-down_w rag-logs_w rag-stop_w app_w worker_w exams_w slides_w dev_w dev-integration_w dev-stop_w dev-restart_w status_w clean_w:
	@$(POWERSHELL) -NoProfile -ExecutionPolicy Bypass -File .\run.ps1 $(patsubst %_w,%,$@)

else

COMPOSE  := docker compose -f infra/docker-compose.yml
MONGO_PORT ?= 27018
export MONGO_PORT
# SYSPY: whatever python the machine has (ubuntu ships python3 only, some
# windows only the py launcher). Its single job is creating the venv;
# after that everything goes through $(PY), and pip is always $(PY) -m pip.
# Probed by running, not by PATH lookup: Windows plants a fake python3 stub
# in WindowsApps that only opens the Microsoft Store.
SYSPY := $(shell for p in python3 python py; do $$p -c "" >/dev/null 2>&1 && { echo $$p; break; }; done)
ifeq ($(SYSPY),)
SYSPY := python3
endif
ifeq ($(OS),Windows_NT)
PY := .venv/Scripts/python.exe
else
PY := .venv/bin/python
endif
DB       := docker exec -i univai-db psql -U univai -d univai -v ON_ERROR_STOP=1
# 3100, not 3000: the exam system's "back to UnivAI" buttons point at 3100
# (UNIVAI_APP_URL in UnivAI-exam_system/.env.local). Keep them in step.
APP_PORT ?= 3100

# ---- RAG stack (UnivAI-Agent submodule + its Qdrant vector database) ----
RAG_DIR     := UnivAI-Agent
RAG_ABS_DIR := $(abspath $(RAG_DIR))
RAG_PORT    ?= 8000
RAG_MCP     := http://localhost:$(RAG_PORT)/mcp
# Probed over 127.0.0.1, not localhost: the server binds IPv4 only, and a
# localhost lookup that answers ::1 first wastes the timeout before falling back.
RAG_PROBE   := http://127.0.0.1:$(RAG_PORT)/mcp
QDRANT_URL  ?= http://localhost:6333
# logs/ is gitignored, so the log and the pid handle stay out of git.
RAG_LOG     := logs/rag-mcp.log
RAG_PIDFILE := logs/rag-mcp.pid
# Seconds `make rag` waits for the MCP server before giving up. The first run
# downloads the embedding and reranker models, which is minutes. RAG_WAIT=0
# returns immediately and leaves it starting in the background (what `dev` does).
RAG_WAIT    ?= 300
# PIDs owned by this checkout's RAG server. Matching on the command line alone
# is not enough: it also finds shells and mcp_server.py processes from other
# projects. The executable and /proc working directory keep shutdown scoped to
# this UnivAI-Agent checkout.
RAG_PIDS := for p in $$(pgrep -f 'mcp_server\.py' 2>/dev/null || true); do \
		case "$$(ps -o comm= -p $$p 2>/dev/null)" in \
			python*|uv) [ "$$(readlink -f /proc/$$p/cwd 2>/dev/null)" = "$(RAG_ABS_DIR)" ] && echo $$p;; \
		esac; \
	done

# Minimum Node version accepted by UnivAI.
# Versions above NODE_TESTED_MAJOR are accepted, but produce a warning.
NODE_MIN_MAJOR    ?= 20
NODE_TESTED_MAJOR ?= 24

# The Windows MSI normally installs Node here. Git Bash may have an old PATH
# even though Windows already has Node installed, so recover that directory.
ifeq ($(OS),Windows_NT)
WINDOWS_NODE_DIR := $(shell [ -x "/c/Program Files/nodejs/node.exe" ] && printf '%s' "/c/Program Files/nodejs")
ifneq ($(WINDOWS_NODE_DIR),)
export PATH := $(WINDOWS_NODE_DIR):$(PATH)
endif
endif

.PHONY: help install install-node node-check setup env models up down schema migrate seed seed-data seed-auth seed-demo submodules-check contract-check sprint3-smoke integration-smoke rag-models rag-cache-clean reset rag rag-server rag-db rag-down rag-logs rag-stop app worker exams slides dev-check dev dev-integration dev-stop dev-restart status clean

help: ## Show this help
	@echo ""
	@echo "  UnivAI — targets"
	@echo ""
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Typical first run:   make install && make setup && make models && make up && make dev"
	@echo ""

# ---------------------------------------------------------------- setup

node-check: ## Verify that Node.js and npm are usable
	@set -eu; \
	version="$$(node -p 'process.versions.node' 2>/dev/null || true)"; \
	if [ -z "$$version" ]; then \
		echo "ERROR: Node.js is missing or is not visible to this shell."; \
		if [ "$(OS)" = "Windows_NT" ]; then \
			echo "Close and reopen Git Bash/PowerShell, then run: make node-check"; \
		fi; \
		exit 1; \
	fi; \
	major="$${version%%.*}"; \
	case "$$major" in ''|*[!0-9]*) \
		echo "ERROR: Could not parse Node.js version '$$version'."; \
		exit 1;; \
	esac; \
	if [ "$$major" -lt "$(NODE_MIN_MAJOR)" ]; then \
		echo "ERROR: Node.js v$$version found; UnivAI requires Node.js $(NODE_MIN_MAJOR)+."; \
		exit 1; \
	fi; \
	if ! command -v npm >/dev/null 2>&1; then \
		echo "ERROR: Node.js v$$version is available, but npm is missing."; \
		exit 1; \
	fi; \
	if [ "$$major" -gt "$(NODE_TESTED_MAJOR)" ]; then \
		echo "WARNING: Node.js v$$version is newer than the tested Node $(NODE_TESTED_MAJOR) release."; \
	fi; \
	echo "Node.js v$$version and npm $$(npm --version) are ready"

install-node:
ifeq ($(OS),Windows_NT)
	@set -eu; \
	version="$$(node -p 'process.versions.node' 2>/dev/null || true)"; \
	if [ -n "$$version" ]; then \
		major="$${version%%.*}"; \
		if [ "$$major" -ge "$(NODE_MIN_MAJOR)" ]; then \
			echo "Node.js v$$version already satisfies $(NODE_MIN_MAJOR)+"; \
			if [ "$$major" -gt "$(NODE_TESTED_MAJOR)" ]; then \
				echo "WARNING: Node.js v$$version is newer than tested Node $(NODE_TESTED_MAJOR)."; \
			fi; \
			exit 0; \
		fi; \
		echo "ERROR: Node.js v$$version is installed but is too old."; \
		echo "Upgrade Node.js to $(NODE_MIN_MAJOR)+, then rerun make install."; \
		exit 1; \
	fi; \
	echo "==> installing Node.js LTS"; \
	if ! winget install -e --id OpenJS.NodeJS.LTS \
		--accept-package-agreements \
		--accept-source-agreements \
		--disable-interactivity; then \
		if [ -x "/c/Program Files/nodejs/node.exe" ]; then \
			echo "winget returned an error, but Node.js exists in the standard installation directory."; \
		else \
			if winget list -e --name "Node.js" \
				--accept-source-agreements 2>/dev/null | grep -qi "Node.js"; then \
				echo "ERROR: Windows reports Node.js as installed, but this shell cannot find it."; \
				echo "Reopen the terminal or add the Node.js installation directory to PATH."; \
			else \
				echo "ERROR: Node.js installation failed."; \
			fi; \
			exit 1; \
		fi; \
	fi; \
	$(MAKE) --no-print-directory node-check
else
	@set -eu; \
	version="$$(node -p 'process.versions.node' 2>/dev/null || true)"; \
	if [ -n "$$version" ]; then \
		major="$${version%%.*}"; \
		if [ "$$major" -ge "$(NODE_MIN_MAJOR)" ]; then \
			echo "Node.js v$$version already satisfies $(NODE_MIN_MAJOR)+"; \
			if [ "$$major" -gt "$(NODE_TESTED_MAJOR)" ]; then \
				echo "WARNING: Node.js v$$version is newer than tested Node $(NODE_TESTED_MAJOR)."; \
			fi; \
			exit 0; \
		fi; \
		echo "Node.js v$$version is too old; trying the configured APT repositories."; \
	else \
		echo "==> installing Node.js and npm"; \
	fi; \
	sudo apt-get update; \
	sudo apt-get install -y nodejs npm; \
	if ! $(MAKE) --no-print-directory node-check; then \
		echo "ERROR: Your Linux repository did not provide Node.js $(NODE_MIN_MAJOR)+."; \
		echo "Install a newer Node.js release using your distribution's supported method."; \
		exit 1; \
	fi
endif


install: install-node ## Install missing system tools: node, python, uv, docker, ollama
ifeq ($(OS),Windows_NT)
	@python -c "" >/dev/null 2>&1 || py -c "" >/dev/null 2>&1 || \
		winget install -e --id Python.Python.3.12 \
			--accept-package-agreements \
			--accept-source-agreements \
			--disable-interactivity
	@command -v uv >/dev/null 2>&1 || \
		winget install -e --id astral-sh.uv \
			--accept-package-agreements \
			--accept-source-agreements \
			--disable-interactivity
	@command -v docker >/dev/null 2>&1 || \
		winget install -e --id Docker.DockerDesktop \
			--accept-package-agreements \
			--accept-source-agreements \
			--disable-interactivity
	@command -v ollama >/dev/null 2>&1 || \
		winget install -e --id Ollama.Ollama \
			--accept-package-agreements \
			--accept-source-agreements \
			--disable-interactivity
	@echo "NOTE: Docker Desktop and Ollama may need one manual first launch,"
	@echo "      and a new shell so PATH picks the tools up."
else
	@command -v python3 >/dev/null 2>&1 || { \
		sudo apt-get update && \
		sudo apt-get install -y python3 python3-venv python3-pip; \
	}
	@command -v uv >/dev/null 2>&1 || \
		curl -LsSf https://astral.sh/uv/install.sh | sh
	@command -v docker >/dev/null 2>&1 || \
		curl -fsSL https://get.docker.com | sh
	@command -v ollama >/dev/null 2>&1 || \
		curl -fsSL https://ollama.com/install.sh | sh
endif
	@echo "tools ready — next: make setup && make models"
setup: env ## Install everything: node deps, python venv, exam deps, RAG deps
	@$(MAKE) --no-print-directory node-check

	@echo "==> app dependencies (UnivAI-app submodule)"
	cd UnivAI-app && npm install

	@echo "==> python venv + voice (UnivAI-live) dependencies"
	$(SYSPY) -m venv .venv
	$(PY) -m pip install --upgrade pip
	$(PY) -m pip install -r services/requirements.txt

	@echo "==> exam system (UnivAI-exam_system submodule)"
	cd UnivAI-exam_system && npm install

	@echo "==> RAG service (UnivAI-Agent submodule)"
	cd UnivAI-Agent && uv sync

	@echo ""
	@echo "Done. Now: make up && make dev"

env: ## Create .env from .env.example if it does not exist
	@test -f .env || (cp .env.example .env && echo "Created .env — defaults run fully local, no keys needed")

# One local model, no fallback (LLM_FALLBACK stays empty in .env). Sub-2B models
# (gemma3:1b, qwen2.5:0.5b) cannot hold the JSON schema course generation asks
# for — they fail every retry with "model never produced valid JSON" — so the
# default is the smallest model measured to survive it.
# Swap with:  make models MODELS_LLM=gemma3:4b
MODELS_LLM ?= qwen3:4b-instruct
KOKORO_URL := https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0
PIPER_URL  := https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium

# The voice model files belong to the Mouth cave (UnivAI-live), not the campus root.
VOICE_DIR := UnivAI-live/models
VOICE_MODELS := \
	$(VOICE_DIR)/kokoro/kokoro-v1.0.onnx \
	$(VOICE_DIR)/kokoro/voices-v1.0.bin \
	$(VOICE_DIR)/piper/en_US-lessac-medium.onnx \
	$(VOICE_DIR)/piper/en_US-lessac-medium.onnx.json

models: ## Download the voice models + the one local LLM (MODELS_LLM)
	@mkdir -p $(VOICE_DIR)/kokoro $(VOICE_DIR)/piper
	@test -f $(VOICE_DIR)/kokoro/kokoro-v1.0.onnx || curl -L --fail -o $(VOICE_DIR)/kokoro/kokoro-v1.0.onnx $(KOKORO_URL)/kokoro-v1.0.onnx
	@test -f $(VOICE_DIR)/kokoro/voices-v1.0.bin  || curl -L --fail -o $(VOICE_DIR)/kokoro/voices-v1.0.bin $(KOKORO_URL)/voices-v1.0.bin
	@test -f $(VOICE_DIR)/piper/en_US-lessac-medium.onnx      || curl -L --fail -o $(VOICE_DIR)/piper/en_US-lessac-medium.onnx "$(PIPER_URL)/en_US-lessac-medium.onnx?download=true"
	@test -f $(VOICE_DIR)/piper/en_US-lessac-medium.onnx.json || curl -L --fail -o $(VOICE_DIR)/piper/en_US-lessac-medium.onnx.json "$(PIPER_URL)/en_US-lessac-medium.onnx.json?download=true"
	@ollama pull $(MODELS_LLM)
	@echo "voice models in $(VOICE_DIR)/, local LLM '$(MODELS_LLM)' ready (whisper downloads itself on first run)"

# ---------------------------------------------------------------- infrastructure

up: ## Start Postgres + Qdrant + Mongo, then apply the schema
	$(COMPOSE) up -d --wait --wait-timeout 120
	@$(MAKE) --no-print-directory schema
	@echo "Postgres :5433   Qdrant :6333   Mongo :$(MONGO_PORT)   LiveKit :7880"

down: rag-stop ## Stop Postgres + Qdrant + the RAG server (data is kept)
	$(COMPOSE) down

schema: ## Apply infra/schema.sql (idempotent)
	@$(DB) < infra/schema.sql > /dev/null
	@$(DB) < infra/migrations/002_final_mvp.sql > /dev/null
	@$(DB) -c "INSERT INTO core_schema_migrations (version, name) VALUES (2, 'final_mvp') ON CONFLICT (version) DO NOTHING" > /dev/null
	@$(DB) < infra/migrations/003_sprint3_learning_flow.sql > /dev/null
	@$(DB) -c "INSERT INTO core_schema_migrations (version, name) VALUES (3, 'sprint3_learning_flow') ON CONFLICT (version) DO NOTHING" > /dev/null
	@$(DB) < infra/migrations/004_app_library.sql > /dev/null
	@$(DB) -c "INSERT INTO core_schema_migrations (version, name) VALUES (4, 'app_library') ON CONFLICT (version) DO NOTHING" > /dev/null
	@$(DB) < infra/migrations/005_lecture_artifact_keys.sql > /dev/null
	@$(DB) -c "INSERT INTO core_schema_migrations (version, name) VALUES (5, 'lecture_artifact_keys') ON CONFLICT (version) DO NOTHING" > /dev/null
	@$(DB) < infra/migrations/006_resumable_course_generation.sql > /dev/null
	@$(DB) -c "INSERT INTO core_schema_migrations (version, name) VALUES (6, 'resumable_course_generation') ON CONFLICT (version) DO NOTHING" > /dev/null
	@echo "base schema and migrations 002-006 applied"

migrate: schema ## Apply database migrations/schema

seed: migrate seed-data seed-auth ## Apply seed data and super-admin bootstrap

seed-demo: migrate ## Apply the deterministic integration-demo scenario
	@$(DB) < infra/demo-seed.sql > /dev/null && echo "integration demo seed applied"
	npm --prefix UnivAI-app run seed:integration
	npm --prefix UnivAI-exam_system run seed:integration

submodules-check: ## Verify pinned submodule SHAs and clean working trees
	node scripts/submodules-check.mjs

contract-check: ## Validate cross-repository contracts and canonical fixtures
	node scripts/contract-check.mjs

sprint3-smoke: ## Run deterministic Sprint 3 contracts and negative paths (no real SLO claim)
	node scripts/sprint3-smoke.mjs --mode mock

integration-smoke: ## Run bounded static and live integration checkpoints
	node scripts/integration-smoke.mjs

seed-data: ## Apply infra/seed.sql (idempotent)
	@$(DB) < infra/seed.sql > /dev/null && echo "seed data applied"

seed-auth: ## Promote SUPER_ADMIN_EMAIL to super_admin if that user exists
	@email="$$(awk -F= '/^[[:space:]]*SUPER_ADMIN_EMAIL[[:space:]]*=/{gsub(/^[[:space:]]+|[[:space:]]+$$/, "", $$2); gsub(/^["'\'']|["'\'']$$/, "", $$2); value=$$2} END{print value}' .env 2>/dev/null)"; \
	if [ -z "$$email" ]; then \
		echo "SUPER_ADMIN_EMAIL is empty in .env; skipping auth seed."; \
	else \
		echo "==> promoting $$email if it exists"; \
		printf '%s\n' 'UPDATE "user" SET "role" = '\''super_admin'\'', "studentId" = COALESCE("studentId", '\''S-'\'' || EXTRACT(YEAR FROM CURRENT_DATE)::int || '\''-'\'' || LPAD(nextval('\''student_id_seq'\'')::text, 6, '\''0'\'')), "updatedAt" = CURRENT_TIMESTAMP WHERE lower("email") = lower(:'\''admin_email'\'') RETURNING "email", "role", "studentId";' | $(DB) -v admin_email="$$email"; \
	fi

reset: ## Wipe lectures, attendance, grades, Q&A and reset the virtual clock
	@$(DB) -c "TRUNCATE attendance, lectures, grades, qa_log RESTART IDENTITY CASCADE; UPDATE clock_state SET offset_ms = 0;" > /dev/null
	@echo "data cleared, virtual clock back to real time"

# ---------------------------------------------------------------- the three processes

rag: rag-db rag-server ## Start the whole RAG stack — Qdrant + the MCP server, in the background

# Start only the RAG process. dev uses this after dev-check has proved that
# make up already started Qdrant; it must not mutate infrastructure itself.
rag-server:
	@mkdir -p logs
	@set -u; \
	running="$$($(RAG_PIDS))"; \
	if curl -s -o /dev/null -m 2 $(RAG_PROBE); then \
		if [ -n "$$running" ]; then \
			echo "RAG MCP server is already answering on :$(RAG_PORT)"; \
			exit 0; \
		fi; \
		echo "ERROR: something is already listening on :$(RAG_PORT), but it is not"; \
		echo "       the RAG MCP server. Free the port, or pick another one:"; \
		echo "       make rag RAG_PORT=8001"; \
		exit 1; \
	fi; \
	if [ ! -d "$(RAG_DIR)/.venv" ]; then \
		echo "ERROR: $(RAG_DIR)/.venv is missing. Run: make setup"; \
		exit 1; \
	fi; \
	echo "==> starting the RAG MCP server (log: $(RAG_LOG))"; \
	( cd $(RAG_DIR) && FASTMCP_HOST=127.0.0.1 FASTMCP_PORT=$(RAG_PORT) \
		exec uv run python mcp_server.py ) >> $(RAG_LOG) 2>&1 & \
	echo $$! > $(RAG_PIDFILE); \
	if [ "$(RAG_WAIT)" -le 0 ]; then \
		echo "starting in the background — follow it with: make rag-logs"; \
		exit 0; \
	fi; \
	echo "==> waiting for :$(RAG_PORT) (the first run downloads the embedding and"; \
	echo "    reranker models, so this can take minutes — make rag-logs to watch)"; \
	for i in $$(seq 1 $(RAG_WAIT)); do \
		if curl -s -o /dev/null -m 2 $(RAG_PROBE); then \
			echo ""; \
			echo "  RAG MCP  $(RAG_MCP)"; \
			echo "  Qdrant   $(QDRANT_URL)"; \
			echo "  log      $(RAG_LOG)      stop with: make rag-down"; \
			echo ""; \
			exit 0; \
		fi; \
		if ! kill -0 "$$(cat $(RAG_PIDFILE) 2>/dev/null)" 2>/dev/null; then \
			echo "ERROR: the MCP server exited during startup. Last 20 log lines:"; \
			tail -n 20 $(RAG_LOG) 2>/dev/null; \
			rm -f $(RAG_PIDFILE); \
			exit 1; \
		fi; \
		sleep 1; \
	done; \
	echo "ERROR: :$(RAG_PORT) did not answer within $(RAG_WAIT)s. It may still be"; \
	echo "       loading models — check with: make rag-logs"; \
	exit 1

rag-db: ## Start just the Qdrant vector database — :6333
	@$(COMPOSE) up -d qdrant
	@echo "==> waiting for Qdrant on $(QDRANT_URL)"
	@for i in $$(seq 1 60); do \
		if curl -sf -m 2 $(QDRANT_URL)/readyz >/dev/null 2>&1 || \
		   curl -sf -m 2 $(QDRANT_URL)/collections >/dev/null 2>&1; then \
			echo "Qdrant ready"; \
			exit 0; \
		fi; \
		sleep 1; \
	done; \
	echo "ERROR: Qdrant did not become ready within 60s. Check: docker logs univai-qdrant"; \
	exit 1

# Stops the MCP server by its recorded pid, then sweeps any stray process still
# running mcp_server.py — `make dev` and a hand-started server can both leave one
# behind, and a half-dead server holding :8000 is worse than none.
#
# Deliberately has no ## description: it is the shared building block behind
# rag-down, down and clean rather than something to reach for directly. The
# server runs detached, so anything that takes its Qdrant away has to stop it
# too, or it survives answering :8000 against a vector store that is gone.
rag-stop:
	@set -u; \
	known=""; \
	if [ -f $(RAG_PIDFILE) ]; then \
		pid="$$(cat $(RAG_PIDFILE) 2>/dev/null || true)"; \
		owned="$$($(RAG_PIDS))"; \
		if [ -n "$$pid" ] && printf '%s\n' "$$owned" | grep -qx "$$pid"; then \
			kill -TERM "$$pid" 2>/dev/null || true; \
			known="$$pid"; \
			echo "stopped the RAG MCP server (pid $$pid)"; \
		elif [ -n "$$pid" ]; then \
			echo "ignored stale RAG pid file (pid $$pid is not owned by this checkout)"; \
		fi; \
		rm -f $(RAG_PIDFILE); \
	fi; \
	for pid in $$($(RAG_PIDS)); do \
		[ "$$pid" = "$$known" ] && continue; \
		kill -TERM "$$pid" 2>/dev/null && echo "stopped a stray mcp_server.py process (pid $$pid)" || true; \
	done; \
	for i in 1 2 3 4 5 6 7 8 9 10; do \
		curl -s -o /dev/null -m 1 $(RAG_PROBE) || break; \
		sleep 1; \
	done; \
	if curl -s -o /dev/null -m 1 $(RAG_PROBE); then \
		echo "WARNING: :$(RAG_PORT) is still answering; sending SIGKILL"; \
		for pid in $$($(RAG_PIDS)); do kill -KILL "$$pid" 2>/dev/null || true; done; \
	fi

rag-down: rag-stop ## Stop the RAG MCP server and the Qdrant container (vectors are kept)
	@$(COMPOSE) rm -sf qdrant >/dev/null 2>&1 && echo "stopped and removed the univai-qdrant container"
	@echo "vectors are kept in the univai-qdrant volume — 'make clean' destroys them"

rag-logs: ## Follow the background RAG MCP server log
	@test -f $(RAG_LOG) || { echo "no log yet at $(RAG_LOG) — start it with: make rag"; exit 1; }
	@tail -n 50 -f $(RAG_LOG)

app: ## Run the Next.js app — :$(APP_PORT)
	cd UnivAI-app && npx next dev -p $(APP_PORT)

worker: ## Run the live-lecture voice agent (TTS + STT). Needs LIVEKIT_* keys
	$(PY) UnivAI-live/worker.py dev

exams: ## Run the exam system (UnivAI-exam_system) - :3200
	cd UnivAI-exam_system && node --env-file=../.env --import tsx server.ts dev

slides: ## Build the Slidev decks to UnivAI-app/public/slides/
	node scripts/build-slides.mjs

rag-models: ## Download/preload RAG embedding models
	cd UnivAI-Agent && uv run python -c "from vector_store.qdrant_client import get_dense_embedder, get_sparse_embedder; print('loading dense embedder'); get_dense_embedder(); print('loading sparse embedder'); get_sparse_embedder(); print('RAG models ready')"

rag-cache-clean: ## Remove broken RAG Jina embedding model cache
	@cache="$${TMPDIR:-/tmp}/fastembed_cache"; \
	rm -rf "$$cache/models--xenova--jina-embeddings-v2-base-en" "$$cache/models--jinaai--jina-embeddings-v2-base-en"; \
	echo "removed broken RAG model cache under $$cache"

# ---------------------------------------------------------------- everything at once

dev-check:
	@set -eu; \
	missing=""; \
	for path in .env $(PY) UnivAI-app/node_modules UnivAI-exam_system/node_modules UnivAI-Agent/.venv; do \
		[ -e "$$path" ] || missing="$$missing $$path"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "ERROR: project setup is incomplete (missing:$$missing)."; \
		echo "Run: make install && make setup"; \
		exit 1; \
	fi; \
	missing=""; \
	for path in $(VOICE_MODELS); do \
		[ -s "$$path" ] || missing="$$missing $$path"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "ERROR: model setup is incomplete (missing:$$missing)."; \
		echo "Run: make models"; \
		exit 1; \
	fi; \
	if ! docker info >/dev/null 2>&1; then \
		echo "ERROR: Docker is not running."; \
		echo "Start Docker, then run: make up"; \
		exit 1; \
	fi; \
	missing=""; \
	for container in univai-db univai-qdrant univai-mongo univai-livekit; do \
		state="$$(docker inspect --format '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$$container" 2>/dev/null || true)"; \
		[ "$$state" = "running/healthy" ] || missing="$$missing $$container($${state:-missing})"; \
	done; \
	if ! docker port univai-mongo 27017/tcp 2>/dev/null | grep -Eq ':$(MONGO_PORT)$$'; then \
		missing="$$missing univai-mongo(host-port-not-published)"; \
	fi; \
	if [ -n "$$missing" ]; then \
		echo "ERROR: development infrastructure is not ready:$$missing"; \
		echo "Run: make up"; \
		exit 1; \
	fi; \
	echo "development prerequisites are ready"

dev: dev-check ## Start RAG + app + worker + exams; requires setup, models and infra
	@echo "==> launching RAG, app, worker and exams"
ifeq ($(OS),Windows_NT)
# On Windows the ollama CLI starts the daemon app when it is not running.
	@curl -s -m 2 http://127.0.0.1:11434 >/dev/null 2>&1 || (echo "==> waking Ollama" && ollama list >/dev/null 2>&1)
# Git Bash mangles single-slash cmd switches (/k -> K:/) and its `start`
# wrapper breaks && chains, so: // switches, /D for the workdir, no &&.
	@start "UnivAI RAG"    //D UnivAI-Agent cmd //k "uv run python mcp_server.py"
	@start "UnivAI app"    //D UnivAI-app cmd //k "npx next dev -p $(APP_PORT)"
	@start "UnivAI worker" cmd //k ".venv\Scripts\python.exe UnivAI-live\worker.py dev"
	@start "UnivAI exams"  //D UnivAI-exam_system cmd //k "npm run dev"
else
	@mkdir -p logs
	@$(MAKE) --no-print-directory rag-server RAG_WAIT=0
	@set -u; \
	release_owned_listener() { \
		port="$$1"; expected_cwd="$$2"; label="$$3"; target="$$4"; root="$(abspath .)"; \
		pids="$$(fuser "$$port/tcp" 2>/dev/null || true)"; \
		[ -n "$$pids" ] || return 0; \
		for pid in $$pids; do \
			cwd="$$(readlink -f /proc/$$pid/cwd 2>/dev/null || true)"; \
			command="$$(ps -o comm= -p $$pid 2>/dev/null || true)"; \
			if [ "$$cwd" != "$$expected_cwd" ]; then \
				echo "ERROR: :$$port is held by pid $$pid outside this checkout ($$cwd)."; \
				echo "Stop that process, then rerun: make dev"; \
				return 1; \
			fi; \
			case "$$command" in next-server*) ;; *) \
				echo "ERROR: :$$port is held by unexpected owned process '$$command' (pid $$pid)."; \
				return 1;; \
			esac; \
			owned="$$pid"; ancestor="$$(ps -o ppid= -p $$pid 2>/dev/null | tr -d ' ')"; \
			while [ -n "$$ancestor" ] && [ "$$ancestor" -gt 1 ]; do \
				ancestor_cwd="$$(readlink -f /proc/$$ancestor/cwd 2>/dev/null || true)"; \
				ancestor_args="$$(ps -o args= -p $$ancestor 2>/dev/null || true)"; \
				if [ "$$ancestor_cwd" = "$$expected_cwd" ]; then \
					owned="$$owned $$ancestor"; \
				elif [ "$$ancestor_cwd" = "$$root" ]; then \
					case "$$ancestor_args" in *make*" $$target"*) owned="$$owned $$ancestor";; *) break;; esac; \
				else \
					break; \
				fi; \
				ancestor="$$(ps -o ppid= -p $$ancestor 2>/dev/null | tr -d ' ')"; \
			done; \
			echo "==> stopping stale $$label listener on :$$port (owned pids:$$owned)"; \
			kill -TERM $$owned; \
		done; \
		for i in $$(seq 1 20); do \
			fuser "$$port/tcp" >/dev/null 2>&1 || return 0; \
			sleep 0.25; \
		done; \
		echo "ERROR: stale $$label listener did not release :$$port"; \
		return 1; \
	}; \
	if curl -sf -m 2 http://127.0.0.1:$(APP_PORT)/api/clock >/dev/null 2>&1; then \
		echo "app is already answering on :$(APP_PORT)"; \
	else \
		release_owned_listener "$(APP_PORT)" "$(abspath UnivAI-app)" "app" "app" || exit 1; \
		echo "==> starting app (log: logs/app.log)"; \
		nohup setsid sh -c 'cd UnivAI-app && exec npx next dev -p $(APP_PORT)' </dev/null > logs/app.log 2>&1 & echo $$! > logs/app.pid; \
	fi; \
	if curl -sf -m 2 http://127.0.0.1:3200 >/dev/null 2>&1; then \
		echo "exams are already answering on :3200"; \
	else \
		release_owned_listener "3200" "$(abspath UnivAI-exam_system)" "exam" "exams" || exit 1; \
		echo "==> starting exams (log: logs/exams.log)"; \
		nohup setsid sh -c 'cd UnivAI-exam_system && exec node --env-file=../.env --import tsx server.ts dev' </dev/null > logs/exams.log 2>&1 & echo $$! > logs/exams.pid; \
	fi; \
	worker=""; \
	for pid in $$(pgrep -f 'UnivAI-live/[w]orker\.py dev' 2>/dev/null || true); do \
		[ "$$(readlink -f /proc/$$pid/cwd 2>/dev/null)" = "$(abspath .)" ] || continue; \
		case "$$(ps -o comm= -p $$pid 2>/dev/null)" in python*) ;; *) continue;; esac; \
		worker="$$pid"; break; \
	done; \
	if [ -n "$$worker" ]; then \
		echo "voice worker is already running (pid $$worker)"; \
	else \
		echo "==> starting voice worker (log: logs/worker.log)"; \
		nohup setsid $(PY) UnivAI-live/worker.py dev </dev/null > logs/worker.log 2>&1 & echo $$! > logs/worker.pid; \
	fi
	@set -eu; \
	for i in $$(seq 1 60); do \
		curl -sf -m 2 http://127.0.0.1:$(APP_PORT)/api/clock >/dev/null 2>&1 && break; \
		if [ "$$i" -eq 60 ]; then echo "ERROR: app failed to start. See logs/app.log"; exit 1; fi; \
		sleep 1; \
	done; \
	for i in $$(seq 1 60); do \
		curl -sf -m 2 http://127.0.0.1:3200 >/dev/null 2>&1 && break; \
		if [ "$$i" -eq 60 ]; then echo "ERROR: exams failed to start. See logs/exams.log"; exit 1; fi; \
		sleep 1; \
	done
endif
	@echo ""
	@echo "  app    http://localhost:$(APP_PORT)"
	@echo "  admin  http://localhost:$(APP_PORT)/admin   (move the virtual clock here)"
	@echo "  exams  http://localhost:3200"
	@echo "  RAG    $(RAG_MCP)"
	@echo ""
	@echo "  logs   logs/app.log, logs/exams.log, logs/worker.log, $(RAG_LOG)"
	@echo "  RAG runs detached — 'make rag-logs' to watch it, 'make rag-down' to stop it."
	@echo ""
	@echo "  Ollama wakes automatically on Windows. The course generator and"
	@echo "  lecture Q&A call it at :11434 ($(MODELS_LLM) - one local model, no fallback)."

dev-integration: dev ## Explicit alias for the full real local integration stack

# `make dev` starts app, exams and worker detached with setsid, so each one is
# its own process GROUP and the recorded pid is the group leader. Signalling the
# group is what actually stops the server underneath — killing the pid alone
# leaves the real next/node/python child orphaned and still holding its port.
#
# The trailing wait is for the worker specifically: its group leader dies first,
# but livekit takes seconds more to unwind its child processes. `make dev` finds
# the worker by pattern, so returning while one is still exiting makes it decide
# a worker is already running and start none — leaving lectures with no voice.
dev-stop: ## Stop app, exams and worker (containers and RAG keep running)
	@set -u; \
	for name in app exams worker; do \
		pidfile="logs/$$name.pid"; \
		if [ ! -f "$$pidfile" ]; then echo "  $$name  was not started by make dev"; continue; fi; \
		pid="$$(cat "$$pidfile" 2>/dev/null || true)"; \
		if [ -z "$$pid" ] || ! kill -0 "$$pid" 2>/dev/null; then \
			echo "  $$name  not running"; rm -f "$$pidfile"; continue; \
		fi; \
		cwd="$$(readlink -f /proc/$$pid/cwd 2>/dev/null || true)"; \
		args="$$(ps -o args= -p "$$pid" 2>/dev/null || true)"; \
		owned=""; \
		case "$$name" in \
			app) [ "$$cwd" = "$(abspath UnivAI-app)" ] && case "$$args" in *next*dev*) owned=1;; esac;; \
			exams) [ "$$cwd" = "$(abspath UnivAI-exam_system)" ] && case "$$args" in *server.ts*dev*) owned=1;; esac;; \
			worker) [ "$$cwd" = "$(abspath .)" ] && case "$$args" in *UnivAI-live/worker.py*dev*) owned=1;; esac;; \
		esac; \
		if [ -z "$$owned" ]; then \
			echo "  $$name  ignored stale pid $$pid (process is not owned by this checkout)"; \
			rm -f "$$pidfile"; continue; \
		fi; \
		pgid="$$(ps -o pgid= -p "$$pid" 2>/dev/null | tr -d ' ')"; \
		if [ -n "$$pgid" ]; then kill -TERM -"$$pgid" 2>/dev/null || true; else kill -TERM "$$pid" 2>/dev/null || true; fi; \
		for i in $$(seq 1 24); do kill -0 "$$pid" 2>/dev/null || break; sleep 0.25; done; \
		if kill -0 "$$pid" 2>/dev/null; then \
			if [ -n "$$pgid" ]; then kill -KILL -"$$pgid" 2>/dev/null || true; else kill -KILL "$$pid" 2>/dev/null || true; fi; \
		fi; \
		rm -f "$$pidfile"; \
		echo "  $$name  stopped"; \
	done; \
	for i in $$(seq 1 40); do \
		alive=""; \
		for p in $$(pgrep -f 'UnivAI-live/[w]orker\.py dev' 2>/dev/null || true); do \
			[ "$$(readlink -f /proc/$$p/cwd 2>/dev/null)" = "$(abspath .)" ] && alive="$$p" && break; \
		done; \
		[ -z "$$alive" ] && break; \
		sleep 0.25; \
	done

# The RAG server reads .env at import too, so an .env change needs it restarted
# with the rest — that is the whole reason this target exists.
dev-restart: ## Restart everything `make dev` runs — use after editing .env
	@$(MAKE) --no-print-directory dev-stop
	@$(MAKE) --no-print-directory rag-stop
	@$(MAKE) --no-print-directory dev

status: ## Show what is running
	@echo "containers:" && docker ps --filter name=univai --format "  {{.Names}}  {{.Status}}  {{.Ports}}"
	@printf "app    :$(APP_PORT)  " && (curl -s -o /dev/null -m 2 http://localhost:$(APP_PORT)/api/clock && echo "up") || echo "down"
	@printf "exams  :3200  " && (curl -s -o /dev/null -m 2 http://localhost:3200 && echo "up") || echo "down"
	@printf "RAG    :$(RAG_PORT)  " && (curl -s -o /dev/null -m 2 $(RAG_MCP) && echo "up") || echo "down"
	@printf "qdrant :6333  " && (curl -sf -m 2 $(QDRANT_URL)/collections >/dev/null 2>&1 && echo "up") || echo "down"
	@printf "livekit:7880  " && (curl -s -o /dev/null -m 2 http://127.0.0.1:7880 && echo "up") || echo "down"
	@printf "clock  " && (curl -s -m 2 http://localhost:$(APP_PORT)/api/clock || echo "(app down)") && echo ""

clean: rag-stop ## Remove containers AND their volumes. Destroys the database and the vectors
	$(COMPOSE) down -v
	@echo "containers and volumes removed"

endif
