# UnivAI - PowerShell twin of the Makefile, for Windows machines without `make`.
#
#   ./run.ps1              list the targets
#   ./run.ps1 setup        install node deps, python venv, RAG deps
#   ./run.ps1 up           start Postgres + Qdrant and apply the schema
#   ./run.ps1 dev          start everything (RAG + app + worker), each in its own window
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
$Py      = ".\.venv\Scripts\python.exe"
$Pip     = ".\.venv\Scripts\pip.exe"

function Say($text)  { Write-Host "==> $text" -ForegroundColor Cyan }
function Warn($text) { Write-Host $text -ForegroundColor Yellow }

function Invoke-Sql($sqlFile) {
    Get-Content $sqlFile -Raw | docker exec -i univai-db psql -U univai -d univai | Out-Null
}

function Test-Url($url) {
    try { Invoke-WebRequest -Uri $url -TimeoutSec 2 -UseBasicParsing | Out-Null; return $true }
    catch { return $false }
}

function Target-Help {
    Write-Host ""
    Write-Host "  UnivAI - targets" -ForegroundColor White
    Write-Host ""
    $rows = @(
        @("setup",  "Install everything: node deps, python venv, RAG deps"),
        @("env",    "Create .env from .env.example if missing"),
        @("up",     "Start Postgres + Qdrant, apply the schema"),
        @("down",   "Stop the containers (data is kept)"),
        @("schema", "Apply infra/schema.sql (idempotent)"),
        @("reset",  "Wipe lectures, attendance, grades, questions; reset the clock"),
        @("rag",    "Run the team's RAG MCP server  (:8000)"),
        @("app",    "Run the Next.js app            (:$AppPort)"),
        @("worker", "Run the live-lecture voice agent (needs LIVEKIT_* keys)"),
        @("exams",  "Run the exam system (:3200)"),
        @("slides", "Build the Slidev decks to app/public/slides/"),
        @("dev",    "Start infra, then RAG + app + worker in separate windows"),
        @("status", "Show what is running"),
        @("clean",  "Remove containers AND volumes (destroys the DB and the vectors)")
    )
    foreach ($r in $rows) { "    {0,-8} {1}" -f $r[0], $r[1] | Write-Host }
    Write-Host ""
    Write-Host "  Typical first run:  ./run.ps1 setup ; ./run.ps1 up ; ./run.ps1 dev" -ForegroundColor DarkGray
    Write-Host ""
}

function Target-Env {
    if (-not (Test-Path ".env")) {
        Copy-Item ".env.example" ".env"
        Warn "Created .env - fill in LIVEKIT_* before running the live lecture."
    }
}

function Target-Setup {
    Target-Env
    Say "app dependencies"
    Push-Location app; npm install; Pop-Location

    Say "python venv + voice (UnivAI-live) dependencies"
    if (-not (Test-Path ".venv")) { python -m venv .venv }
    & $Pip install --upgrade pip
    & $Pip install -r services/requirements.txt

    Say "submodules"
    git submodule update --init --recursive

    Say "exam system (UnivAI-exam_system submodule)"
    Push-Location UnivAI-exam_system; npm install; Pop-Location

    Say "RAG service (UnivAI-Agent submodule)"
    Push-Location UnivAI-Agent; uv sync; Pop-Location

    Write-Host ""
    Say "Done. Now: ./run.ps1 up  then  ./run.ps1 dev"
}

function Target-Up {
    docker @Compose up -d
    Say "waiting for Postgres"
    do { Start-Sleep -Milliseconds 700 }
    until (docker exec univai-db pg_isready -U univai -d univai 2>$null)
    Target-Schema
    Write-Host "Postgres :5433   Qdrant :6333   Mongo :27017   LiveKit :7880" -ForegroundColor Green
}

function Target-Down   { docker @Compose down }
function Target-Clean  { docker @Compose down -v; Warn "containers and volumes removed" }
function Target-Schema { Invoke-Sql "infra/schema.sql"; Write-Host "schema applied" -ForegroundColor Green }

function Target-Reset {
    $sql = "TRUNCATE attendance, lectures, grades, qa_log RESTART IDENTITY CASCADE; UPDATE clock_state SET offset_ms = 0;"
    $sql | docker exec -i univai-db psql -U univai -d univai | Out-Null
    Write-Host "data cleared, virtual clock back to real time" -ForegroundColor Green
}

function Target-Rag    { Push-Location UnivAI-Agent; uv run python mcp_server.py; Pop-Location }
function Target-App    { Push-Location app; npx next dev -p $AppPort; Pop-Location }
function Target-Worker { & $Py UnivAI-live/worker.py dev }
function Target-Slides { node scripts/build-slides.mjs }
function Target-Exams  { Push-Location UnivAI-exam_system; npm run dev; Pop-Location }

function Target-Dev {
    Target-Up
    if (-not (Test-Url "http://127.0.0.1:11434")) {
        Say "waking Ollama"
        ollama list | Out-Null
    }
    Say "launching RAG, app and worker in separate windows"
    $root = $PSScriptRoot
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$root'; ./run.ps1 rag"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$root'; ./run.ps1 app -AppPort $AppPort"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$root'; ./run.ps1 worker"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$root'; ./run.ps1 exams"

    Write-Host ""
    Write-Host "  app    http://localhost:$AppPort"           -ForegroundColor Green
    Write-Host "  admin  http://localhost:$AppPort/admin   (move the virtual clock here)"
    Write-Host "  RAG    http://localhost:8000/mcp"
}

function Target-Status {
    Write-Host "containers:"
    docker ps --filter name=univai --format "  {{.Names}}  {{.Status}}  {{.Ports}}"

    $appUp   = Test-Url "http://localhost:$AppPort/api/clock"
    $examsUp = Test-Url "http://localhost:3200"
    $ragUp   = Test-Url "http://localhost:8000/mcp"
    $lkUp    = Test-Url "http://127.0.0.1:7880"
    Write-Host ("app    :{0}  {1}" -f $AppPort, $(if ($appUp) { "up" } else { "down" }))
    Write-Host ("exams  :3200  {0}" -f $(if ($examsUp) { "up" } else { "down" }))
    Write-Host ("RAG    :8000  {0}"  -f $(if ($ragUp) { "up" } else { "down" }))
    Write-Host ("livekit:7880  {0}"  -f $(if ($lkUp) { "up" } else { "down" }))

    if ($appUp) {
        $clock = Invoke-RestMethod "http://localhost:$AppPort/api/clock"
        Write-Host ("clock  virtual now = {0}  (offset {1} min)" -f $clock.now, [math]::Round($clock.offsetMs / 60000))
    }
}

switch ($Target.ToLower()) {
    "help"   { Target-Help }
    "setup"  { Target-Setup }
    "env"    { Target-Env }
    "up"     { Target-Up }
    "down"   { Target-Down }
    "schema" { Target-Schema }
    "reset"  { Target-Reset }
    "rag"    { Target-Rag }
    "app"    { Target-App }
    "worker" { Target-Worker }
    "exams"  { Target-Exams }
    "slides" { Target-Slides }
    "dev"    { Target-Dev }
    "status" { Target-Status }
    "clean"  { Target-Clean }
    default  { Warn "Unknown target '$Target'"; Target-Help; exit 1 }
}
