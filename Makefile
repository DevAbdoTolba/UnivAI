# UnivAI — one entry point for the whole stack.
#
# Windows has no `make` by default. Either install it
#   (winget install ezwinports.make), or use the PowerShell twin:
#   ./run.ps1 <target>          — same target names, same behaviour.
#
# Run `make` on its own to see every target.

SHELL := /bin/bash
.DEFAULT_GOAL := help

COMPOSE  := docker compose -f infra/docker-compose.yml
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
DB       := docker exec -i univai-db psql -U univai -d univai
# 3100, not 3000: the exam system's "back to UnivAI" buttons point at 3100
# (UNIVAI_APP_URL in UnivAI-exam_system/.env.local). Keep them in step.
APP_PORT ?= 3100

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

.PHONY: help install install-node node-check setup env models up down schema reset rag app worker exams slides dev status clean

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

	@echo "==> submodules"
	git submodule update --init --recursive

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

# One light local model, no fallback (LLM_FALLBACK stays empty in .env).
# Swap with:  make models MODELS_LLM=gemma3:4b
MODELS_LLM ?= gemma3:1b
KOKORO_URL := https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0
PIPER_URL  := https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium

# The voice model files belong to the Mouth cave (UnivAI-live), not the campus root.
VOICE_DIR := UnivAI-live/models

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
	$(COMPOSE) up -d
	@echo "==> waiting for Postgres"
	@until docker exec univai-db pg_isready -U univai -d univai >/dev/null 2>&1; do sleep 1; done
	@$(MAKE) --no-print-directory schema
	@echo "Postgres :5433   Qdrant :6333   Mongo :27017   LiveKit :7880"

down: ## Stop Postgres + Qdrant (data is kept)
	$(COMPOSE) down

schema: ## Apply infra/schema.sql (idempotent)
	@$(DB) < infra/schema.sql > /dev/null && echo "schema applied"

reset: ## Wipe lectures, attendance, grades, Q&A and reset the virtual clock
	@$(DB) -c "TRUNCATE attendance, lectures, grades, qa_log RESTART IDENTITY CASCADE; UPDATE clock_state SET offset_ms = 0;" > /dev/null
	@echo "data cleared, virtual clock back to real time"

# ---------------------------------------------------------------- the three processes

rag: ## Run the team's RAG MCP server (needs Qdrant) — :8000
	cd UnivAI-Agent && uv run python mcp_server.py

app: ## Run the Next.js app — :$(APP_PORT)
	cd UnivAI-app && npx next dev -p $(APP_PORT)

worker: ## Run the live-lecture voice agent (TTS + STT). Needs LIVEKIT_* keys
	$(PY) UnivAI-live/worker.py dev

exams: ## Run the exam system (UnivAI-exam_system) - :3200
	cd UnivAI-exam_system && npm run dev

slides: ## Build the Slidev decks to UnivAI-app/public/slides/
	node scripts/build-slides.mjs

# ---------------------------------------------------------------- everything at once

dev: up ## Start infra, then RAG + app + worker + exams, each in its own terminal
	@echo "==> launching RAG, app, worker and exams in separate windows"
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
	@($(MAKE) rag &) ; ($(MAKE) app &) ; ($(MAKE) worker &) ; ($(MAKE) exams &)
endif
	@echo ""
	@echo "  app    http://localhost:$(APP_PORT)"
	@echo "  admin  http://localhost:$(APP_PORT)/admin   (move the virtual clock here)"
	@echo "  exams  http://localhost:3200"
	@echo "  RAG    http://localhost:8000/mcp"
	@echo ""
	@echo "  Ollama wakes automatically on Windows. The course generator and"
	@echo "  lecture Q&A call it at :11434 (gemma3:1b - one light model, no fallback)."

status: ## Show what is running
	@echo "containers:" && docker ps --filter name=univai --format "  {{.Names}}  {{.Status}}  {{.Ports}}"
	@printf "app    :$(APP_PORT)  " && (curl -s -o /dev/null -m 2 http://localhost:$(APP_PORT)/api/clock && echo "up") || echo "down"
	@printf "exams  :3200  " && (curl -s -o /dev/null -m 2 http://localhost:3200 && echo "up") || echo "down"
	@printf "RAG    :8000  " && (curl -s -o /dev/null -m 2 http://localhost:8000/mcp && echo "up") || echo "down"
	@printf "livekit:7880  " && (curl -s -o /dev/null -m 2 http://127.0.0.1:7880 && echo "up") || echo "down"
	@printf "clock  " && (curl -s -m 2 http://localhost:$(APP_PORT)/api/clock || echo "(app down)") && echo ""

clean: ## Remove containers AND their volumes. Destroys the database and the vectors
	$(COMPOSE) down -v
	@echo "containers and volumes removed"
