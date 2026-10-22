#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Python,
    [ValidateSet('Editor', 'Release')][string]$Runtime = 'Editor'
)
$ErrorActionPreference = 'Stop'
& $Python (Join-Path $PSScriptRoot 'public_handoff/godot_probe.py') --runtime $Runtime.ToLowerInvariant()
if ($LASTEXITCODE -ne 0) { throw 'Public Godot owner integration failed; inspect output/handoff.' }
