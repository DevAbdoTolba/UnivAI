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
PY       := .venv/Scripts/python.exe        # Linux/macOS: .venv/bin/python
PIP      := .venv/Scripts/pip.exe           # Linux/macOS: .venv/bin/pip
DB       := docker exec -i univai-db psql -U univai -d univai
# 3100, not 3000: the exam system's "back to UnivAI" buttons point at 3100
# (UNIVAI_APP_URL in UnivAI-exam_system/.env.local). Keep them in step.
APP_PORT ?= 3100

.PHONY: help setup env up down schema reset rag app worker exams slides dev status clean

help: ## Show this help
	@echo ""
	@echo "  UnivAI — targets"
	@echo ""
	@grep -E '^[a-z-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Typical first run:   make setup && make up && make dev"
	@echo ""

# ---------------------------------------------------------------- setup

setup: env ## Install everything: node deps, python venv, exam deps, RAG deps
	@echo "==> app dependencies"
	cd app && npm install
	@echo "==> python venv + voice-agent dependencies"
	python -m venv .venv
	$(PIP) install --upgrade pip
	$(PIP) install -r services/requirements.txt
	@echo "==> submodules"
	git submodule update --init --recursive
	@echo "==> exam system (UnivAI-exam_system submodule)"
	cd UnivAI-exam_system && npm install
	@echo "==> RAG service (UnivAI-Agent submodule)"
	cd UnivAI-Agent && uv sync
	@echo ""
	@echo "Done. Now: make up && make dev"

env: ## Create .env from .env.example if it does not exist
	@test -f .env || (cp .env.example .env && echo "Created .env — fill in LIVEKIT_* before the live lecture")

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
	cd app && npx next dev -p $(APP_PORT)

worker: ## Run the live-lecture voice agent (TTS + STT). Needs LIVEKIT_* keys
	$(PY) services/voice-agent/worker.py dev

exams: ## Run the exam system (UnivAI-exam_system) - :3200
	cd UnivAI-exam_system && npm run dev

slides: ## Build the Slidev decks to app/public/slides/
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
	@start "UnivAI app"    //D app cmd //k "npx next dev -p $(APP_PORT)"
	@start "UnivAI worker" cmd //k ".venv\Scripts\python.exe services\voice-agent\worker.py dev"
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
	@echo "  lecture Q&A call it at :11434 (llama3.2:3b primary, qwen2.5:7b fallback)."

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
