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
        @("install","Install missing system tools: node, python, uv, docker, ollama"),
        @("setup",  "Install everything: node deps, python venv, RAG deps"),
        @("env",    "Create .env from .env.example if missing"),
        @("models", "Download the voice models + the one local LLM (gemma3:1b)"),
        @("up",     "Start Postgres + Qdrant, apply the schema"),
        @("down",   "Stop the containers (data is kept)"),
        @("schema", "Apply infra/schema.sql (idempotent)"),
        @("reset",  "Wipe lectures, attendance, grades, questions; reset the clock"),
        @("rag",    "Run the team's RAG MCP server  (:8000)"),
        @("app",    "Run the Next.js app            (:$AppPort)"),
        @("worker", "Run the live-lecture voice agent (needs LIVEKIT_* keys)"),
        @("exams",  "Run the exam system (:3200)"),
        @("slides", "Build the Slidev decks to UnivAI-app/public/slides/"),
        @("dev",    "Start infra, then RAG + app + worker in separate windows"),
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
$ModelsLlm  = "gemma3:1b"
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
function Target-App    { Push-Location UnivAI-app; npx next dev -p $AppPort; Pop-Location }
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
    "install" { Target-Install }
    "setup"  { Target-Setup }
    "env"    { Target-Env }
    "models" { Target-Models }
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
