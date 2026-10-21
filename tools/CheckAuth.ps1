#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Python,
    [ValidateSet('editor','release','both','none')][string]$Runtime = 'editor',
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$manifest = Get-Content (Join-Path $PSScriptRoot 'auth_proof/dependencies.json') -Raw | ConvertFrom-Json
foreach ($name in @('java', 'keycloak')) {
    $info = $manifest.$name
    $directory = Join-Path $workspace "output/tools/auth/$name"
    $archive = Join-Path $directory 'distribution.zip'
    if ($Install -and -not (Test-Path -LiteralPath $archive)) {
        New-Item -ItemType Directory -Force $directory | Out-Null
        Invoke-WebRequest $info.url -OutFile $archive
    }
    $expected = if ($info.sha256) { $info.sha256 } else { $info.digest.Split(':')[1] }
    if (-not (Test-Path -LiteralPath $archive) -or (Get-FileHash -LiteralPath $archive).Hash -ne $expected) {
        throw "Missing or changed $name archive. Use -Install for first setup."
    }
    if ($Install -and $name -eq 'java' -and -not (Test-Path -LiteralPath (Join-Path $directory $info.runtime_directory))) {
        Expand-Archive -LiteralPath $archive -DestinationPath $directory
    }
}
# Requires the pinned PostgreSQL/psycopg fixture installed by CheckPublicStorage.ps1,
# and a Python runtime containing the exact cryptography version in the manifest.
# No global Java, certificate trust, user account, or Godot setting is changed.
& $Python (Join-Path $PSScriptRoot 'auth_proof/probe.py') --runtime $Runtime
if ($LASTEXITCODE -ne 0) { throw 'Authentication proof failed; inspect output/auth logs.' }
