#requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Config)
$ErrorActionPreference = 'Stop'
$settings = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
if (-not $settings.stop_file -or -not [IO.Path]::IsPathFullyQualified($settings.stop_file)) {
    throw 'Configure an absolute stop_file path when starting this server.'
}
# Operator-owned file signal only; no network shutdown endpoint or PID killing.
$stream = [IO.File]::Open($settings.stop_file, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::Write, [IO.FileShare]::ReadWrite)
$stream.Dispose()
'Graceful stop requested. Check the server log for PUBLIC_SERVER_DRAINED; DRAIN_FAILED means final saves were not confirmed.'
