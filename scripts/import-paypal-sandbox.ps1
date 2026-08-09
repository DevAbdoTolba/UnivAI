param(
    [string]$SourceEnv = (Join-Path $PSScriptRoot "..\..\..\find_job_laravel\find_job\.env"),
    [string]$TargetEnv = (Join-Path $PSScriptRoot "..\.env")
)

$ErrorActionPreference = "Stop"
$sourcePath = [System.IO.Path]::GetFullPath($SourceEnv)
$targetPath = [System.IO.Path]::GetFullPath($TargetEnv)

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "PayPal source env not found: $sourcePath"
}
if (-not (Test-Path -LiteralPath $targetPath)) {
    throw "UnivAI env not found: $targetPath"
}

function Read-EnvValue([string[]]$Lines, [string]$Key) {
    foreach ($line in $Lines) {
        if ($line -match "^\s*$([regex]::Escape($Key))=(.*)$") {
            return $matches[1].Trim().Trim('"').Trim("'")
        }
    }
    return $null
}

function Set-EnvValue([System.Collections.Generic.List[string]]$Lines, [string]$Key, [string]$Value) {
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ($Lines[$index] -match "^\s*$([regex]::Escape($Key))=") {
            $Lines[$index] = "$Key=$Value"
            return
        }
    }
    $Lines.Add("$Key=$Value")
}

$sourceLines = Get-Content -LiteralPath $sourcePath
$clientId = Read-EnvValue $sourceLines "PAYPAL_CLIENT_ID"
$clientSecret = Read-EnvValue $sourceLines "PAYPAL_CLIENT_SECRET"
if (-not $clientId -or -not $clientSecret) {
    throw "The source env does not contain PayPal client credentials."
}

$targetLines = [System.Collections.Generic.List[string]]::new()
Get-Content -LiteralPath $targetPath | ForEach-Object { $targetLines.Add($_) }
Set-EnvValue $targetLines "PAYPAL_CLIENT_ID" $clientId
Set-EnvValue $targetLines "PAYPAL_CLIENT_SECRET" $clientSecret
Set-EnvValue $targetLines "PAYPAL_API_BASE" "https://api-m.sandbox.paypal.com"

[System.IO.File]::WriteAllLines(
    $targetPath,
    $targetLines,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Imported PAYPAL_CLIENT_ID and PAYPAL_CLIENT_SECRET into UnivAI's ignored .env."
Write-Host "Buyer credentials and the old webhook ID were intentionally not copied."
