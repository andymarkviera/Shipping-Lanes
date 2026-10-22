#requires -Version 7.4
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Python)
$ErrorActionPreference = 'Stop'
# Reuses pinned PostgreSQL/psycopg and cryptography from the preceding proofs.
# All services are disposable, owned children bound to loopback.
& $Python (Join-Path $PSScriptRoot 'public_handoff/probe.py')
if ($LASTEXITCODE -ne 0) { throw 'Public handoff proof failed; inspect output/handoff.' }
