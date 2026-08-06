# UnivAI - PowerShell twin of the Makefile, for Windows machines without `make`.
#
#   ./run.ps1              list the targets
#   ./run.ps1 setup        install node deps, python venv, RAG deps
#   ./run.ps1 up           start Postgres + Qdrant and apply the schema
#   ./run.ps1 dev          start everything (RAG + app + worker), each in its own window
#   ./run.ps1 dev-restart  restart the complete dev stack after editing .env
#
# Same target names as the Makefile. Keep the two in step.

param(
    [Parameter(Position = 0)]
    [string]$Target = "help",

    # 3100, not 3000: the exam system's "back to UnivAI" buttons point at 3100
    # (UNIVAI_APP_URL in UnivAI-exam_system/.env.local). Keep them in step.
    [int]$AppPort = 3100
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$Compose = @("compose", "-f", "infra/docker-compose.yml")
$MongoPort = 27018
$env:MONGO_PORT = "$MongoPort"
$Py      = ".\.venv\Scripts\python.exe"
$Pip     = ".\.venv\Scripts\pip.exe"

function Say($text)  { Write-Host "==> $text" -ForegroundColor Cyan }
function Warn($text) { Write-Host $text -ForegroundColor Yellow }

function Invoke-Sql($sqlFile) {
    Get-Content $sqlFile -Raw | docker exec -i univai-db psql -U univai -d univai -v ON_ERROR_STOP=1 | Out-Null
}

function Invoke-SqlText($sql, $psqlArgs = @()) {
    $sql | docker exec -i univai-db psql -U univai -d univai -v ON_ERROR_STOP=1 @psqlArgs
}

function Read-DotEnvValue($name) {
    if (-not (Test-Path ".env")) { return "" }
    $line = Get-Content ".env" | Where-Object { $_ -match "^\s*$([regex]::Escape($name))\s*=" } | Select-Object -Last 1
    if (-not $line) { return "" }
    return (($line -replace "^\s*$([regex]::Escape($name))\s*=\s*", "") -replace '^\s*["'']?|["'']?\s*$', "").Trim()
}

function Test-Url($url) {
    try { Invoke-WebRequest -Uri $url -TimeoutSec 2 -UseBasicParsing | Out-Null; return $true }
    catch { return $false }
}

function Test-TcpPort($port) {
    return [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)
}

function Wait-Url($url, [int]$Seconds = 10) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-Url $url) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Target-Help {
    Write-Host ""
    Write-Host "  UnivAI - targets" -ForegroundColor White
    Write-Host ""
    $rows = @(
        @("install","Install missing system tools: node, python, uv, docker, ollama"),
        @("setup",  "Install everything: node deps, python venv, RAG deps"),
        @("env",    "Create .env from .env.example if missing"),
        @("models", "Download the voice models + the one local LLM (qwen3:4b-instruct)"),
        @("up",     "Start Postgres + Qdrant, apply the schema"),
        @("down",   "Stop the containers and the RAG server (data is kept)"),
        @("schema", "Apply infra/schema.sql (idempotent)"),
        @("migrate","Apply database migrations/schema"),
        @("seed",   "Apply seed data and super-admin bootstrap"),
        @("seed-demo","Apply deterministic integration-demo records"),
        @("submodules-check","Verify pinned submodule SHAs and clean state"),
        @("contract-check","Validate cross-repository contracts"),
        @("sprint3-smoke","Run Sprint 3 mock contracts and fail-closed paths"),
        @("integration-smoke","Run bounded integration checkpoints"),
        @("seed-auth","Promote SUPER_ADMIN_EMAIL if the user exists"),
        @("rag-models","Download/preload RAG embedding models"),
        @("rag-cache-clean","Remove broken RAG model cache"),
        @("reset",  "Wipe lectures, attendance, grades, questions; reset the clock"),
        @("rag",    "Start the whole RAG stack - Qdrant + MCP, in the background"),
        @("rag-db", "Start just the Qdrant vector database (:6333)"),
        @("rag-down","Stop the RAG MCP server and the Qdrant container"),
        @("rag-logs","Follow the background RAG MCP server log"),
        @("app",    "Run the Next.js app            (:$AppPort)"),
        @("worker", "Run the live-lecture voice agent (needs LIVEKIT_* keys)"),
        @("exams",  "Run the exam system (:3200)"),
        @("slides", "Build the Slidev decks to UnivAI-app/public/slides/"),
        @("dev",    "Check prerequisites, then start RAG + app + worker + exams"),
        @("dev-stop","Stop app, worker and exams; keep RAG and containers running"),
        @("dev-restart","Restart everything launched by dev"),
        @("dev-integration","Explicit full integrated-stack alias"),
        @("status", "Show what is running"),
        @("clean",  "Remove containers AND volumes (destroys the DB and the vectors)")
    )
    foreach ($r in $rows) { "    {0,-8} {1}" -f $r[0], $r[1] | Write-Host }
    Write-Host ""
    Write-Host "  Typical first run:  ./run.ps1 install ; ./run.ps1 setup ; ./run.ps1 models ; ./run.ps1 up ; ./run.ps1 dev" -ForegroundColor DarkGray
    Write-Host ""
}

function Target-Env {
    if (-not (Test-Path ".env")) {
        Copy-Item ".env.example" ".env"
        Warn "Created .env - defaults run fully local, no keys needed."
    }
}

function Target-Install {
    $tools = @(
        @("node",   "OpenJS.NodeJS.LTS"),
        @("python", "Python.Python.3.12"),
        @("uv",     "astral-sh.uv"),
        @("docker", "Docker.DockerDesktop"),
        @("ollama", "Ollama.Ollama")
    )
    foreach ($t in $tools) {
        if (Get-Command $t[0] -ErrorAction SilentlyContinue) {
            Write-Host ("  {0,-8} already installed" -f $t[0])
        } else {
            Say "installing $($t[0])"
            winget install -e --id $t[1]
        }
    }
    Warn "NOTE: Docker Desktop and Ollama may need one manual first launch,"
    Warn "      and a new shell so PATH picks the tools up."
    Say "next: ./run.ps1 setup ; ./run.ps1 models"
}

# One light local model, no fallback (LLM_FALLBACK stays empty in .env).
$ModelsLlm  = "qwen3:4b-instruct"
$KokoroUrl  = "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
$PiperUrl   = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium"

function Target-Models {
    # The voice model files belong to the Mouth cave (UnivAI-live), not the campus root.
    $voiceDir = "UnivAI-live/models"
    New-Item -ItemType Directory -Force "$voiceDir/kokoro", "$voiceDir/piper" | Out-Null
    $files = @(
        @("$voiceDir/kokoro/kokoro-v1.0.onnx",           "$KokoroUrl/kokoro-v1.0.onnx"),
        @("$voiceDir/kokoro/voices-v1.0.bin",            "$KokoroUrl/voices-v1.0.bin"),
        @("$voiceDir/piper/en_US-lessac-medium.onnx",      "$PiperUrl/en_US-lessac-medium.onnx?download=true"),
        @("$voiceDir/piper/en_US-lessac-medium.onnx.json", "$PiperUrl/en_US-lessac-medium.onnx.json?download=true")
    )
    foreach ($f in $files) {
        if (Test-Path $f[0]) { Write-Host ("  {0} already there" -f $f[0]) }
        else { Say "downloading $($f[0])"; curl.exe -L --fail -o $f[0] $f[1] }
    }
    Say "pulling local LLM '$ModelsLlm'"
    ollama pull $ModelsLlm
    Say "done (whisper downloads itself on first run)"
}

function Target-Setup {
    Target-Env
    Say "app dependencies (UnivAI-app submodule)"
    Push-Location UnivAI-app; npm install; Pop-Location

    Say "python venv + voice (UnivAI-live) dependencies"
    if (-not (Test-Path ".venv")) { python -m venv .venv }
    & $Pip install --upgrade pip
    & $Pip install -r services/requirements.txt

    Say "exam system (UnivAI-exam_system submodule)"
    Push-Location UnivAI-exam_system; npm install; Pop-Location

    Say "RAG service (UnivAI-Agent submodule)"
    Push-Location UnivAI-Agent; uv sync; Pop-Location

    Write-Host ""
    Say "Done. Now: ./run.ps1 up  then  ./run.ps1 dev"
}

function Target-Up {
    docker @Compose up -d --wait --wait-timeout 120
    if ($LASTEXITCODE -ne 0) { throw "Infrastructure failed to become healthy" }
    Say "waiting for Postgres"
    do { Start-Sleep -Milliseconds 700 }
    until (docker exec univai-db pg_isready -U univai -d univai 2>$null)
    Target-Schema
    Write-Host "Postgres :5433   Qdrant :6333   Mongo :$MongoPort   LiveKit :7880" -ForegroundColor Green
}

# Both stop the RAG server first: it is detached, so taking its Qdrant away
# without stopping it leaves it answering :8000 against a store that is gone.
function Target-Down   { Target-RagStop; docker @Compose down }
function Target-Clean  { Target-RagStop; docker @Compose down -v; Warn "containers and volumes removed" }
function Target-Schema {
    Invoke-Sql "infra/schema.sql"
    Invoke-Sql "infra/migrations/002_final_mvp.sql"
    Invoke-SqlText "INSERT INTO core_schema_migrations (version, name) VALUES (2, 'final_mvp') ON CONFLICT (version) DO NOTHING;" | Out-Null
    Invoke-Sql "infra/migrations/003_sprint3_learning_flow.sql"
    Invoke-SqlText "INSERT INTO core_schema_migrations (version, name) VALUES (3, 'sprint3_learning_flow') ON CONFLICT (version) DO NOTHING;" | Out-Null
    Invoke-Sql "infra/migrations/004_app_library.sql"
    Invoke-SqlText "INSERT INTO core_schema_migrations (version, name) VALUES (4, 'app_library') ON CONFLICT (version) DO NOTHING;" | Out-Null
    Invoke-Sql "infra/migrations/005_lecture_artifact_keys.sql"
    Invoke-SqlText "INSERT INTO core_schema_migrations (version, name) VALUES (5, 'lecture_artifact_keys') ON CONFLICT (version) DO NOTHING;" | Out-Null
    Invoke-Sql "infra/migrations/006_resumable_course_generation.sql"
    Invoke-SqlText "INSERT INTO core_schema_migrations (version, name) VALUES (6, 'resumable_course_generation') ON CONFLICT (version) DO NOTHING;" | Out-Null
    Write-Host "base schema and migrations 002-006 applied" -ForegroundColor Green
}
function Target-Migrate { Target-Schema }
function Target-SeedData { Invoke-Sql "infra/seed.sql"; Write-Host "seed data applied" -ForegroundColor Green }
function Target-SeedAuth {
    $email = Read-DotEnvValue "SUPER_ADMIN_EMAIL"
    if (-not $email) {
        Warn "SUPER_ADMIN_EMAIL is empty in .env; skipping auth seed."
        return
    }

    $sql = @'
UPDATE "user"
SET
  "role" = 'super_admin',
  "studentId" = COALESCE(
    "studentId",
    'S-' || EXTRACT(YEAR FROM CURRENT_DATE)::int || '-' || LPAD(nextval('student_id_seq')::text, 6, '0')
  ),
  "updatedAt" = CURRENT_TIMESTAMP
WHERE lower("email") = lower(:'admin_email')
RETURNING "email", "role", "studentId";
'@
    $result = Invoke-SqlText $sql @("-v", "admin_email=$email")
    if ($result -match "(0 rows)") {
        Warn "No user exists yet for SUPER_ADMIN_EMAIL=$email. Sign up with that email, then rerun seed-auth."
    } else {
        Write-Host $result
        Write-Host "auth seed applied" -ForegroundColor Green
    }
}
function Target-Seed {
    Target-Migrate
    Target-SeedData
    Target-SeedAuth
}
function Target-SeedDemo {
    Target-Migrate
    Invoke-Sql "infra/demo-seed.sql"
    npm --prefix UnivAI-app run seed:integration
    if ($LASTEXITCODE -ne 0) { throw "App integration seed failed" }
    npm --prefix UnivAI-exam_system run seed:integration
    if ($LASTEXITCODE -ne 0) { throw "Exam integration seed failed" }
    Write-Host "integration demo seed applied" -ForegroundColor Green
}
function Target-SubmodulesCheck { node scripts/submodules-check.mjs }
function Target-ContractCheck {
    node scripts/contract-check.mjs
    if ($LASTEXITCODE -ne 0) { throw "Cross-repository contract check failed" }
}
function Target-Sprint3Smoke { node scripts/sprint3-smoke.mjs --mode mock }
function Target-IntegrationSmoke { node scripts/integration-smoke.mjs }

function Target-Reset {
    $sql = "TRUNCATE attendance, lectures, grades, qa_log RESTART IDENTITY CASCADE; UPDATE clock_state SET offset_ms = 0;"
    $sql | docker exec -i univai-db psql -U univai -d univai | Out-Null
    Write-Host "data cleared, virtual clock back to real time" -ForegroundColor Green
}

# ---- RAG stack (UnivAI-Agent submodule + its Qdrant vector database) ----
# logs/ is gitignored, so the log and the pid handle stay out of git.
$RagPort    = 8000
$RagMcp     = "http://localhost:$RagPort/mcp"
# Probed over 127.0.0.1, not localhost: the server binds IPv4 only, and a
# localhost lookup that answers ::1 first wastes the timeout before falling back.
$RagProbe   = "http://127.0.0.1:$RagPort/mcp"
$QdrantUrl  = "http://127.0.0.1:6333"
$RagLog     = "logs/rag-mcp.log"
$RagOutLog  = "logs/rag-mcp.out.log"
$RagPidFile = "logs/rag-mcp.pid"
$RagDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "UnivAI-Agent"))
$RagScript    = Join-Path $RagDirectory "mcp_server.py"

function Test-QdrantReady {
    return (Test-Url "$QdrantUrl/readyz") -or (Test-Url "$QdrantUrl/collections")
}

# FastMCP returns HTTP 406 to a plain GET without the MCP Accept headers. That
# still proves the endpoint is answering, just as curl without -f does in the
# Makefile. Network failures have no response and remain false.
function Test-RagEndpoint {
    try {
        Invoke-WebRequest -Uri $RagProbe -TimeoutSec 2 -UseBasicParsing | Out-Null
        return $true
    } catch {
        return $null -ne $_.Exception.Response
    }
}

function Target-RagDb {
    docker @Compose up -d qdrant
    if ($LASTEXITCODE -ne 0) { throw "Could not start the Qdrant container" }
    Say "waiting for Qdrant on $QdrantUrl"
    $deadline = (Get-Date).AddSeconds(60)
    while ((Get-Date) -lt $deadline) {
        if (Test-QdrantReady) { Write-Host "Qdrant ready" -ForegroundColor Green; return }
        Start-Sleep -Milliseconds 500
    }
    throw "Qdrant did not become ready within 60s. Check: docker logs univai-qdrant"
}

# $Wait = 0 starts the server and returns immediately (what `dev` does).
function Target-Rag([int]$Wait = 300) {
    Target-RagDb
    Target-RagServer -Wait $Wait
}

# Process-only RAG launcher used by dev after infrastructure is verified.
function Target-RagServer([int]$Wait = 300) {
    if (Test-RagEndpoint) {
        if (Get-RagListenerProcess) {
            Write-Host "RAG MCP server is already answering on :$RagPort" -ForegroundColor Green
            return
        }
        throw ("Something is already listening on :$RagPort, but it is not the RAG " +
               "MCP server. Free the port before starting RAG.")
    }
    if (-not (Test-Path "UnivAI-Agent/.venv")) {
        throw "UnivAI-Agent/.venv is missing. Run: ./run.ps1 setup"
    }

    New-Item -ItemType Directory -Force -Path "logs" | Out-Null
    Say "starting the RAG MCP server (log: $RagLog)"
    # FastMCP reads its bind address from the environment; Start-Process inherits it.
    $env:FASTMCP_HOST = "127.0.0.1"
    $env:FASTMCP_PORT = "$RagPort"
    $ragArguments = @("run", "python", "`"$RagScript`"")
    $proc = Start-Process -FilePath "uv" `
        -ArgumentList $ragArguments `
        -WorkingDirectory $RagDirectory `
        -RedirectStandardOutput $RagOutLog `
        -RedirectStandardError $RagLog `
        -WindowStyle Hidden -PassThru
    $proc.Id | Set-Content $RagPidFile

    if ($Wait -le 0) {
        Write-Host "starting in the background - follow it with: ./run.ps1 rag-logs" -ForegroundColor DarkGray
        return
    }

    Say "waiting for :$RagPort (the first run downloads the embedding and reranker"
    Say "models, so this can take minutes - ./run.ps1 rag-logs to watch)"
    $deadline = (Get-Date).AddSeconds($Wait)
    while ((Get-Date) -lt $deadline) {
        if (Test-RagEndpoint) {
            Write-Host ""
            Write-Host "  RAG MCP  $RagMcp"        -ForegroundColor Green
            Write-Host "  Qdrant   $QdrantUrl"     -ForegroundColor Green
            Write-Host "  log      $RagLog      stop with: ./run.ps1 rag-down"
            Write-Host ""
            return
        }
        if ($proc.HasExited) {
            Write-Host "The MCP server exited during startup. Last 20 log lines:" -ForegroundColor Red
            foreach ($file in @($RagLog, $RagOutLog)) {
                if (Test-Path $file) { Get-Content $file -Tail 20 }
            }
            Remove-Item $RagPidFile -ErrorAction SilentlyContinue
            throw "RAG MCP server failed to start"
        }
        Start-Sleep -Seconds 1
    }
    throw ":$RagPort did not answer within ${Wait}s. It may still be loading models - check: ./run.ps1 rag-logs"
}

# Stops the MCP server by its recorded pid, then sweeps any stray process still
# running mcp_server.py - `dev` and a hand-started server can both leave one
# behind, and a half-dead server holding :8000 is worse than none.
function Get-RagProcess {
    $listenerIds = @(
        Get-NetTCPConnection -LocalPort $RagPort -State Listen -ErrorAction SilentlyContinue |
            ForEach-Object { [int]$_.OwningProcess }
    )
    $scriptPattern = [regex]::Escape($RagScript)
    return Get-CimInstance Win32_Process -Filter "Name = 'python.exe' OR Name = 'uv.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and (
                $_.CommandLine -match $scriptPattern -or
                ($listenerIds -contains [int]$_.ProcessId -and $_.CommandLine -match 'mcp_server\.py')
            )
        }
}

function Get-RagListenerProcess {
    $listenerIds = @(
        Get-NetTCPConnection -LocalPort $RagPort -State Listen -ErrorAction SilentlyContinue |
            ForEach-Object { [int]$_.OwningProcess }
    )
    return Get-RagProcess | Where-Object { $listenerIds -contains [int]$_.ProcessId }
}

# Stop just the MCP server process (no containers). Shared by rag-down, down and
# clean: the server runs detached now, so anything that takes its Qdrant away has
# to stop it too, or it survives answering :8000 against a store that is gone.
function Target-RagStop {
    if (Test-Path $RagPidFile) {
        $pidValue = (Get-Content $RagPidFile -Raw).Trim()
        if ($pidValue) {
            $existing = Get-RagProcess | Where-Object { [int]$_.ProcessId -eq [int]$pidValue }
            if ($existing) {
                Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue
                Write-Host "stopped the RAG MCP server (pid $pidValue)" -ForegroundColor Yellow
            } else {
                Write-Host "ignored stale RAG pid file (pid $pidValue is not owned by this checkout)" -ForegroundColor DarkGray
            }
        }
        Remove-Item $RagPidFile -ErrorAction SilentlyContinue
    }

    foreach ($stray in Get-RagProcess) {
        Stop-Process -Id $stray.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "stopped a stray mcp_server.py process (pid $($stray.ProcessId))" -ForegroundColor Yellow
    }

    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline -and (Test-RagEndpoint)) { Start-Sleep -Milliseconds 500 }
    if (Test-RagEndpoint) { Warn "WARNING: :$RagPort is still answering." }
}

function Target-RagDown {
    Target-RagStop
    docker @Compose rm -sf qdrant | Out-Null
    Write-Host "stopped and removed the univai-qdrant container" -ForegroundColor Yellow
    Write-Host "vectors are kept in the univai-qdrant volume - './run.ps1 clean' destroys them" -ForegroundColor DarkGray
}

function Target-RagLogs {
    $logs = @($RagLog, $RagOutLog) | Where-Object { Test-Path $_ }
    if (-not $logs) {
        throw "no log yet at $RagLog - start it with: ./run.ps1 rag"
    }
    Get-Content -Path $logs -Tail 50 -Wait
}
function Target-RagModels {
    Say "preloading RAG embedding models"
    Push-Location UnivAI-Agent
    try {
        uv run python -c "from vector_store.qdrant_client import get_dense_embedder, get_sparse_embedder; print('loading dense embedder'); get_dense_embedder(); print('loading sparse embedder'); get_sparse_embedder(); print('RAG models ready')"
    } finally {
        Pop-Location
    }
}
function Target-RagCacheClean {
    $cacheRoot = Join-Path $env:TEMP "fastembed_cache"
    $targets = @(
        "models--xenova--jina-embeddings-v2-base-en",
        "models--jinaai--jina-embeddings-v2-base-en"
    )
    foreach ($target in $targets) {
        $path = Join-Path $cacheRoot $target
        if (Test-Path $path) {
            $resolvedCacheRoot = [System.IO.Path]::GetFullPath($cacheRoot)
            $resolvedPath = [System.IO.Path]::GetFullPath($path)
            if (-not $resolvedPath.StartsWith($resolvedCacheRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Refusing to remove unexpected path: $resolvedPath"
            }
            Remove-Item -LiteralPath $resolvedPath -Recurse -Force
            Write-Host "removed $resolvedPath" -ForegroundColor Yellow
        }
    }
}
function Target-App    { Push-Location UnivAI-app; npx next dev -p $AppPort; Pop-Location }
function Target-Worker { & $Py UnivAI-live/worker.py dev }
function Target-Slides { node scripts/build-slides.mjs }
function Target-Exams  { Push-Location UnivAI-exam_system; node --env-file=../.env --import tsx server.ts dev; Pop-Location }

function Assert-DevPrerequisites {
    $setupPaths = @(".env", $Py, "UnivAI-app/node_modules", "UnivAI-exam_system/node_modules", "UnivAI-Agent/.venv")
    $missing = @($setupPaths | Where-Object { -not (Test-Path $_) })
    if ($missing.Count -gt 0) {
        throw "Project setup is incomplete (missing: $($missing -join ', ')). Run: ./run.ps1 install ; ./run.ps1 setup"
    }

    $modelPaths = @(
        "UnivAI-live/models/kokoro/kokoro-v1.0.onnx",
        "UnivAI-live/models/kokoro/voices-v1.0.bin",
        "UnivAI-live/models/piper/en_US-lessac-medium.onnx",
        "UnivAI-live/models/piper/en_US-lessac-medium.onnx.json"
    )
    $missing = @($modelPaths | Where-Object { -not (Test-Path $_) })
    if ($missing.Count -gt 0) {
        throw "Model setup is incomplete (missing: $($missing -join ', ')). Run: ./run.ps1 models"
    }

    docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker is not running. Start Docker, then run: ./run.ps1 up"
    }

    $notReady = @()
    foreach ($container in @("univai-db", "univai-qdrant", "univai-mongo", "univai-livekit")) {
        $state = docker inspect --format "{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}" $container 2>$null
        if ($LASTEXITCODE -ne 0 -or $state -ne "running/healthy") {
            $notReady += "$container($(if ($state) { $state } else { 'missing' }))"
        }
    }
    $published = docker port univai-mongo 27017/tcp 2>$null
    if ($LASTEXITCODE -ne 0 -or -not ($published -match ":$MongoPort$")) {
        $notReady += "univai-mongo(host-port-not-published)"
    }
    if ($notReady.Count -gt 0) {
        throw "Development infrastructure is not ready: $($notReady -join ', '). Run: ./run.ps1 up"
    }
}

function Target-Dev {
    Assert-DevPrerequisites
    if (-not (Test-Url "http://127.0.0.1:11434")) {
        Say "waking Ollama"
        $ollama = Get-Command ollama -ErrorAction SilentlyContinue
        if ($ollama) {
            $proc = Start-Process -FilePath $ollama.Source -ArgumentList "list" -WindowStyle Hidden -PassThru
            if (-not $proc.WaitForExit(5000)) {
                Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            }
            if (-not (Wait-Url "http://127.0.0.1:11434" 10)) {
                Warn "WARNING: Ollama did not answer on :11434 within 10 seconds; continuing anyway."
            }
        } else {
            Warn "WARNING: Ollama is not installed or not on PATH; continuing without waking it."
        }
    }
    Say "launching RAG, app and worker in separate windows"
    $root = $PSScriptRoot
    New-Item -ItemType Directory -Force -Path "logs" | Out-Null
    # RAG detaches itself and logs to a file, so it needs no window and no wait.
    Target-RagServer -Wait 0
    $appProcess = Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$root'; ./run.ps1 app -AppPort $AppPort" -PassThru
    $workerProcess = Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$root'; ./run.ps1 worker" -PassThru
    $examProcess = Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$root'; ./run.ps1 exams" -PassThru
    $appProcess.Id | Set-Content "logs/app.pid"
    $workerProcess.Id | Set-Content "logs/worker.pid"
    $examProcess.Id | Set-Content "logs/exams.pid"

    Write-Host ""
    Write-Host "  app    http://localhost:$AppPort"           -ForegroundColor Green
    Write-Host "  admin  http://localhost:$AppPort/admin   (move the virtual clock here)"
    Write-Host "  RAG    $RagMcp"
    Write-Host ""
    Write-Host "  RAG runs detached - './run.ps1 rag-logs' to watch it, './run.ps1 rag-down' to stop it." -ForegroundColor DarkGray
}

function Stop-DevProcess([string]$Name) {
    $pidFile = Join-Path $PSScriptRoot "logs/$Name.pid"
    if (-not (Test-Path -LiteralPath $pidFile)) {
        Write-Host "  $Name  was not started by ./run.ps1 dev" -ForegroundColor DarkGray
        return
    }

    $recorded = (Get-Content -LiteralPath $pidFile -Raw).Trim()
    $processId = 0
    if (-not [int]::TryParse($recorded, [ref]$processId)) {
        Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
        Write-Host "  $Name  ignored invalid pid file" -ForegroundColor DarkGray
        return
    }

    $rootProcess = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction SilentlyContinue
    $rootPattern = [regex]::Escape($PSScriptRoot)
    $targetPattern = [regex]::Escape("run.ps1 $Name")
    if (-not $rootProcess -or -not $rootProcess.CommandLine -or
        $rootProcess.CommandLine -notmatch $rootPattern -or
        $rootProcess.CommandLine -notmatch $targetPattern) {
        Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
        Write-Host "  $Name  ignored stale pid $processId (not owned by this checkout)" -ForegroundColor DarkGray
        return
    }

    # Stop descendants before their recorded PowerShell parent so next/node and
    # the worker cannot survive holding ports after the visible window closes.
    $snapshot = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    $pending = [System.Collections.Generic.Queue[int]]::new()
    $pending.Enqueue($processId)
    $tree = [System.Collections.Generic.List[int]]::new()
    while ($pending.Count -gt 0) {
        $parentId = $pending.Dequeue()
        $tree.Add($parentId)
        foreach ($child in $snapshot | Where-Object { [int]$_.ParentProcessId -eq $parentId }) {
            $pending.Enqueue([int]$child.ProcessId)
        }
    }
    $ids = $tree.ToArray()
    [array]::Reverse($ids)
    foreach ($id in $ids) {
        Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
    Write-Host "  $Name  stopped" -ForegroundColor Yellow
}

function Target-DevStop {
    foreach ($name in @("app", "exams", "worker")) { Stop-DevProcess $name }
}

function Target-DevRestart {
    Target-DevStop
    Target-RagStop
    Target-Dev
}

function Target-Status {
    Write-Host "containers:"
    docker ps --filter name=univai --format "  {{.Names}}  {{.Status}}  {{.Ports}}"

    $appUp   = Test-Url "http://localhost:$AppPort/api/clock"
    $examsUp = Test-Url "http://127.0.0.1:3200"
    $ragUp   = Test-TcpPort $RagPort
    $qdrantUp = Test-QdrantReady
    $lkUp    = Test-Url "http://127.0.0.1:7880"
    Write-Host ("app    :{0}  {1}" -f $AppPort, $(if ($appUp) { "up" } else { "down" }))
    Write-Host ("exams  :3200  {0}" -f $(if ($examsUp) { "up" } else { "down" }))
    Write-Host ("RAG    :{0}  {1}"  -f $RagPort, $(if ($ragUp) { "up" } else { "down" }))
    Write-Host ("qdrant :6333  {0}"  -f $(if ($qdrantUp) { "up" } else { "down" }))
    Write-Host ("livekit:7880  {0}"  -f $(if ($lkUp) { "up" } else { "down" }))

    if ($appUp) {
        $clock = Invoke-RestMethod "http://localhost:$AppPort/api/clock"
        Write-Host ("clock  virtual now = {0}  (offset {1} min)" -f $clock.now, [math]::Round($clock.offsetMs / 60000))
    }
}

switch ($Target.ToLower()) {
    "help"   { Target-Help }
    "install" { Target-Install }
    "setup"  { Target-Setup }
    "env"    { Target-Env }
    "models" { Target-Models }
    "up"     { Target-Up }
    "down"   { Target-Down }
    "schema" { Target-Schema }
    "migrate" { Target-Migrate }
    "seed"   { Target-Seed }
    "seed-data" { Target-SeedData }
    "seed-auth" { Target-SeedAuth }
    "seed-demo" { Target-SeedDemo }
    "submodules-check" { Target-SubmodulesCheck }
    "contract-check" { Target-ContractCheck }
    "sprint3-smoke" { Target-Sprint3Smoke }
    "integration-smoke" { Target-IntegrationSmoke }
    "reset"  { Target-Reset }
    "rag"    { Target-Rag }
    "rag-db" { Target-RagDb }
    "rag-down" { Target-RagDown }
    "rag-stop" { Target-RagStop }
    "rag-logs" { Target-RagLogs }
    "rag-models" { Target-RagModels }
    "rag-cache-clean" { Target-RagCacheClean }
    "app"    { Target-App }
    "worker" { Target-Worker }
    "exams"  { Target-Exams }
    "slides" { Target-Slides }
    "dev"    { Target-Dev }
    "dev-stop" { Target-DevStop }
    "dev-restart" { Target-DevRestart }
    "dev-integration" { Target-Dev }
    "status" { Target-Status }
    "clean"  { Target-Clean }
    default  { Warn "Unknown target '$Target'"; Target-Help; exit 1 }
}
