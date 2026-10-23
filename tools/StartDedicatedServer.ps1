#requires -Version 7.4
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Config,
    [ValidateSet('Editor', 'Release')][string]$Runtime = 'Release'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$configPath = (Resolve-Path -LiteralPath $Config).Path
$settings = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
foreach ($field in @('certificate', 'key', 'fingerprint', 'endpoint', 'server', 'credential', 'ca', 'port')) {
    if (-not $settings.$field) { throw "Missing server configuration field: $field" }
}
foreach ($field in @('certificate', 'key', 'ca')) {
    if (-not [IO.Path]::IsPathFullyQualified($settings.$field) -or -not (Test-Path -LiteralPath $settings.$field -PathType Leaf)) {
        throw "Server configuration requires an existing absolute $field path."
    }
}
if ($settings.stop_file) {
    if (-not [IO.Path]::IsPathFullyQualified($settings.stop_file)) { throw 'stop_file must be absolute.' }
    if (Test-Path -LiteralPath $settings.stop_file) { throw 'Stop marker already exists. After verifying the previous server has stopped, remove that marker before restarting.' }
}
if ($settings.endpoint -notlike 'https://*') { throw 'Authority endpoint must use HTTPS.' }
$binary = Join-Path $projectRoot 'exports/windows-x86_64/release/ShippingLanes.exe'
$arguments = @('--headless')
if ($Runtime -eq 'Editor') {
    $binary = Join-Path $workspaceRoot 'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe'
    $arguments += @('--path', ('"' + $projectRoot + '"'))
}
if (-not (Test-Path -LiteralPath $binary)) { throw 'Runtime is missing. Export Release or prepare the pinned editor first.' }
$arguments += @('--', ('"--public-server-config=' + $configPath + '"'))
# The configuration holds the secret, never the command-line arguments or console.
$logRoot = Join-Path $workspaceRoot ('output/server-runs/' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $logRoot -Force
$logPath = Join-Path $logRoot 'server.log'
$errorPath = Join-Path $logRoot 'server-errors.log'
$process = Start-Process -FilePath $binary -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput $logPath -RedirectStandardError $errorPath -PassThru
[pscustomobject]@{ ProcessId = $process.Id; State = 'Starting'; Log = $logPath; ErrorLog = $errorPath; Note = 'Startup does not confirm backend readiness or public reachability.' }
