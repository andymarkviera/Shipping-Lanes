#requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('Editor', 'Run', 'Import', 'Check')]
    [string]$Mode = 'Editor',
    [switch]$Headless,
    [ValidateRange(0, 1000000)]
    [int]$QuitAfter = 0,
    [string]$EngineSource
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$baseline = Get-Content -LiteralPath (Join-Path $projectRoot 'engine-baseline.json') -Raw | ConvertFrom-Json
$portableRoot = Join-Path $workspaceRoot 'output/tools/godot-4.7.2'
$enginePath = Join-Path $portableRoot 'godot.windows.opt.tools.64.exe'
$taskAppData = Join-Path $portableRoot 'user_data'
$logRoot = Join-Path $projectRoot '.godot'

[System.IO.Directory]::CreateDirectory($portableRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($logRoot) | Out-Null
[System.IO.Directory]::CreateDirectory((Join-Path $taskAppData 'Godot/app_userdata/Shipping Lanes')) | Out-Null

if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    if (-not $EngineSource) { $EngineSource = $baseline.engine_source }
    if (-not (Test-Path -LiteralPath $EngineSource -PathType Leaf)) {
        throw 'Pinned Godot is unavailable. Supply -EngineSource with the recorded exact build.'
    }
    if ((Get-FileHash -LiteralPath $EngineSource -Algorithm SHA256).Hash -ne $baseline.engine_sha256) {
        throw 'Godot source differs from the pinned build. Record and validate an engine upgrade first.'
    }
    Copy-Item -LiteralPath $EngineSource -Destination $enginePath
}
if ((Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash -ne $baseline.engine_sha256) {
    throw 'Cached Godot differs from the pinned build. Existing files have been preserved.'
}
[System.IO.File]::WriteAllText((Join-Path $portableRoot '_sc_'), '')

function Invoke-ProjectGodot {
    param([string]$LogName, [string[]]$Arguments)
    $logPath = Join-Path $logRoot $LogName
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $enginePath
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    # Child process only: no machine/user environment or Steam settings are changed.
    $startInfo.Environment['APPDATA'] = $taskAppData
    foreach ($argument in @('--path', $projectRoot, '--log-file', $logPath) + $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $outputText = $stdout.GetAwaiter().GetResult()
        $errorText = $stderr.GetAwaiter().GetResult()
        if ($outputText) { Write-Host $outputText.TrimEnd() }
        if ($errorText) { Write-Host $errorText.TrimEnd() }
        if ($process.ExitCode -ne 0) { throw "Godot exited with code $($process.ExitCode). See $logPath" }
        if (-not (Test-Path -LiteralPath $logPath)) { throw "Godot produced no log: $logPath" }
        $logText = Get-Content -LiteralPath $logPath -Raw
        if (($logText + $outputText + $errorText) -match '(?m)^(ERROR|SCRIPT ERROR):') {
            throw "Godot reported an error. See $logPath"
        }
    }
    finally { $process.Dispose() }
}

Write-Host "Using pinned Godot $($baseline.engine_version)"
switch ($Mode) {
    'Check' {
        Invoke-ProjectGodot -LogName 'environment-import.log' -Arguments @('--headless', '--editor', '--import')
        Invoke-ProjectGodot -LogName 'environment-startup.log' -Arguments @('--headless', '--quit-after', '10')
    }
    'Import' {
        Invoke-ProjectGodot -LogName 'environment-import.log' -Arguments @('--headless', '--editor', '--import')
    }
    default {
        $launchArguments = @()
        if ($Mode -eq 'Editor') { $launchArguments += '--editor' }
        if ($Headless) {
            $launchArguments += '--headless'
        }
        else {
            $launchArguments += @('--display-driver', 'windows', '--rendering-method', $baseline.renderer,
                '--rendering-driver', $baseline.rendering_driver)
        }
        if ($QuitAfter -gt 0) { $launchArguments += @('--quit-after', [string]$QuitAfter) }
        Invoke-ProjectGodot -LogName ('environment-' + $Mode.ToLowerInvariant() + '.log') -Arguments $launchArguments
    }
}
