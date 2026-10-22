#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Python,
    [ValidateSet('editor','release','both')][string]$Runtime = 'both',
    [ValidateSet('starter','heavy','both')][string]$Hull = 'both'
)
$ErrorActionPreference = 'Stop'
& $Python (Join-Path $PSScriptRoot 'check_identity.py') --runtime $Runtime --hull $Hull
if ($LASTEXITCODE -ne 0) { throw 'Private identity checks failed; inspect output/identity.' }
