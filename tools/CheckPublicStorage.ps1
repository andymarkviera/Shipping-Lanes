#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Python,
    [ValidateSet('editor','release','none')][string]$Runtime = 'editor',
    [switch]$Install
)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$pgRoot = Join-Path $workspace 'output/tools/postgresql-17.11'
$archive = Join-Path $pgRoot 'binaries.zip'
$packages = Join-Path $workspace 'output/tools/public-storage-python'
$requirements = Join-Path $PSScriptRoot 'public_storage/requirements.txt'
$expected = '4B8DB0930C38F6EF845DB919551DEDDA3B6B845AEB0927B3D79A6E8E9E4537CF'
if ($Install) {
    New-Item -ItemType Directory -Force $pgRoot | Out-Null
    if (-not (Test-Path -LiteralPath $archive)) {
        Invoke-WebRequest 'https://get.enterprisedb.com/postgresql/postgresql-17.11-3-windows-x64-binaries.zip' -OutFile $archive
    }
}
if (-not (Test-Path -LiteralPath $archive) -or (Get-FileHash -LiteralPath $archive).Hash -ne $expected) {
    throw 'Portable PostgreSQL archive missing or hash differs. Use -Install for first setup.'
}
if ($Install) {
    if (-not (Test-Path -LiteralPath (Join-Path $pgRoot 'pgsql/bin/postgres.exe'))) {
        Expand-Archive -LiteralPath $archive -DestinationPath $pgRoot
    }
    & $Python -m pip install --require-hashes --only-binary=:all: --upgrade --target $packages -r $requirements
    if ($LASTEXITCODE -ne 0) { throw 'Pinned Python dependencies failed.' }
}
# Compare runtime bin/lib/share files with the pinned distribution before execution.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($archive)
try {
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -notmatch '^pgsql/(bin|lib|share)/' -or -not $entry.Name) { continue }
        $local = Join-Path $pgRoot $entry.FullName
        if (-not (Test-Path -LiteralPath $local)) { throw "Missing PostgreSQL file: $($entry.FullName)" }
        $stream = $entry.Open()
        try { $digest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)) }
        finally { $stream.Dispose() }
        if ((Get-FileHash -LiteralPath $local).Hash -ne $digest) { throw "Changed PostgreSQL file: $($entry.FullName)" }
    }
} finally { $zip.Dispose() }
$oldPythonPath = $env:PYTHONPATH
try {
    $env:PYTHONPATH = $packages
    & $Python (Join-Path $PSScriptRoot 'public_storage/probe.py') --runtime $Runtime
    if ($LASTEXITCODE -ne 0) { throw 'Public storage proof failed; inspect output/public-storage run logs.' }
} finally { $env:PYTHONPATH = $oldPythonPath }
