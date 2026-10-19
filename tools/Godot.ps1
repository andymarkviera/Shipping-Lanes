#requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('Editor', 'Run', 'Import', 'Check', 'Export', 'RunExport', 'AssetCheck', 'ControlsCheck', 'FlowCheck', 'CatalogCheck', 'GeographyCheck', 'ContractsCheck', 'UnitsCheck', 'SessionCheck', 'ClocksCheck', 'DiagnosticsCheck')]
    [string]$Mode = 'Editor',
    [switch]$Headless,
    [ValidateRange(0, 1000000)]
    [int]$QuitAfter = 0,
    [string]$EngineSource,
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    [string]$TemplateSource,
    [switch]$GeographyProbe,
    [switch]$ContractsProbe,
    [switch]$UnitsProbe,
    [switch]$SessionProbe,
    [switch]$ClocksProbe,
    [switch]$DiagnosticsProbe,
    [string]$Scene
)

$ErrorActionPreference = 'Stop'
if ($DiagnosticsProbe -and ($Mode -ne 'RunExport' -or $ClocksProbe -or $SessionProbe -or $UnitsProbe -or $ContractsProbe -or $GeographyProbe)) { throw '-DiagnosticsProbe requires RunExport without other probes.' }
if ($ClocksProbe -and ($Mode -ne 'RunExport' -or $SessionProbe -or $UnitsProbe -or $ContractsProbe -or $GeographyProbe)) { throw '-ClocksProbe requires RunExport without other probes.' }
if ($SessionProbe -and ($Mode -ne 'RunExport' -or $UnitsProbe -or $ContractsProbe -or $GeographyProbe)) { throw '-SessionProbe requires RunExport without other probes.' }
if ($UnitsProbe -and ($Mode -ne 'RunExport' -or $ContractsProbe -or $GeographyProbe)) { throw '-UnitsProbe requires RunExport without other probes.' }
if ($Scene -and $Mode -ne 'Run') { throw '-Scene requires Run.' }
if ($ContractsProbe -and ($Mode -ne 'RunExport' -or $GeographyProbe)) { throw '-ContractsProbe requires RunExport without GeographyProbe.' }
if ($GeographyProbe -and $Mode -ne 'RunExport') { throw '-GeographyProbe requires RunExport.' }
$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$baseline = Get-Content -LiteralPath (Join-Path $projectRoot 'engine-baseline.json') -Raw | ConvertFrom-Json
$portableRoot = Join-Path $workspaceRoot 'output/tools/godot-4.7.2'
$enginePath = Join-Path $portableRoot 'godot.windows.opt.tools.64.exe'
$taskAppData = Join-Path $portableRoot 'user_data'
$logRoot = Join-Path $projectRoot '.godot'
$exportRoot = Join-Path $projectRoot ('exports/windows-x86_64/' + $Configuration.ToLowerInvariant())
$exportPath = Join-Path $exportRoot 'ShippingLanes.exe'

[System.IO.Directory]::CreateDirectory($portableRoot) | Out-Null
[System.IO.Directory]::CreateDirectory($logRoot) | Out-Null
[System.IO.Directory]::CreateDirectory((Join-Path $taskAppData 'Godot/app_userdata/Shipping Lanes')) | Out-Null

if ($Mode -ne 'RunExport' -and -not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
    if (-not $EngineSource) { $EngineSource = $baseline.engine_source }
    if (-not (Test-Path -LiteralPath $EngineSource -PathType Leaf)) {
        throw 'Pinned Godot is unavailable. Supply -EngineSource with the recorded exact build.'
    }
    if ((Get-FileHash -LiteralPath $EngineSource -Algorithm SHA256).Hash -ne $baseline.engine_sha256) {
        throw 'Godot source differs from the pinned build. Record and validate an engine upgrade first.'
    }
    Copy-Item -LiteralPath $EngineSource -Destination $enginePath
}
if ($Mode -ne 'RunExport' -and (Get-FileHash -LiteralPath $enginePath -Algorithm SHA256).Hash -ne $baseline.engine_sha256) {
    throw 'Cached Godot differs from the pinned build. Existing files have been preserved.'
}
[System.IO.File]::WriteAllText((Join-Path $portableRoot '_sc_'), '')
# Pin native dependencies and preload before import; scan-time first discovery
# crashes on shutdown with this engine/binding pair. Preserve other extensions.
$dependency = Get-Content (Join-Path $projectRoot 'sqlite-dependency.json') -Raw | ConvertFrom-Json
foreach ($entry in $dependency.files) {
    if ((Get-FileHash -LiteralPath (Join-Path $projectRoot $entry.path)).Hash -ne $entry.sha256) {
        throw "SQLite dependency hash mismatch: $($entry.path)"
    }
}
if ($Mode -ne 'RunExport') {
    $extensionList = Join-Path $logRoot 'extension_list.cfg'
    $extensions = if (Test-Path $extensionList) { @(Get-Content $extensionList) } else { @() }
    $sqliteExtension = 'res://addons/godot-sqlite/gdsqlite.gdextension'
    if ($extensions -notcontains $sqliteExtension) {
        [IO.File]::WriteAllLines($extensionList, [string[]]($extensions + $sqliteExtension))
    }
}

function Invoke-ProjectGodot {
    param([string]$LogName, [string[]]$Arguments, [switch]$Exported)
    $logPath = Join-Path $logRoot $LogName
    # Remove a stale log so it cannot make a failed launch appear successful.
    if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath }
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = if ($Exported) { $exportPath } else { $enginePath }
    $startInfo.WorkingDirectory = if ($Exported) { $exportRoot } else { $projectRoot }
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    # Child process only: no machine/user environment or Steam settings are changed.
    $startInfo.Environment['APPDATA'] = $taskAppData
    $baseArguments = @('--log-file', $logPath)
    if (-not $Exported) { $baseArguments = @('--path', $projectRoot) + $baseArguments }
    foreach ($argument in $baseArguments + $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if ($LogName.EndsWith('-check.log') -or ($Exported -and ($DiagnosticsProbe -or $ClocksProbe -or $SessionProbe -or $UnitsProbe -or $ContractsProbe -or $GeographyProbe))) {
            if (-not $process.WaitForExit(30000)) {
                $process.Kill()
                $process.WaitForExit()
                throw "Check timed out; see $logPath"
            }
        } else { $process.WaitForExit() }
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

function Install-ExportTemplates {
    $templates = Get-Content -LiteralPath (Join-Path $projectRoot 'export-templates.json') -Raw | ConvertFrom-Json
    if ($templates.version -ne $baseline.export_template_version) { throw 'Template and engine version pins disagree.' }
    $templateRoot = Join-Path $portableRoot ('editor_data/export_templates/' + $templates.version)
    $sourceRoot = if ($TemplateSource) { $TemplateSource } else { $templates.source }
    [System.IO.Directory]::CreateDirectory($templateRoot) | Out-Null
    foreach ($file in $templates.files) {
        $destination = Join-Path $templateRoot $file.name
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            $source = Join-Path $sourceRoot $file.name
            if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
                throw "Missing pinned template $($file.name). Supply -TemplateSource with the recorded matching files."
            }
            if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $file.sha256) {
                throw "Template source hash mismatch: $($file.name). Existing files preserved."
            }
            Copy-Item -LiteralPath $source -Destination $destination
        }
        if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $file.sha256) {
            throw "Cached template hash mismatch: $($file.name). Existing files preserved."
        }
    }
    if ((Get-Content -LiteralPath (Join-Path $templateRoot 'version.txt') -Raw).Trim() -ne $templates.version) {
        throw 'Export template version metadata does not match the pin.'
    }
    Write-Host "Verified Windows templates $($templates.version)"
}

if ($Mode -ne 'RunExport') { Write-Host "Using pinned Godot $($baseline.engine_version)" }
switch ($Mode) {
    'Check' {
        Invoke-ProjectGodot -LogName 'environment-import.log' -Arguments @('--headless', '--editor', '--import')
        Invoke-ProjectGodot -LogName 'scripts-check.log' -Arguments @('--headless', '--script', 'res://tools/check_scripts.gd')
        Invoke-ProjectGodot -LogName 'environment-startup.log' -Arguments @('--headless', '--quit-after', '10')
    }
    'Import' {
        Invoke-ProjectGodot -LogName 'environment-import.log' -Arguments @('--headless', '--editor', '--import')
    }
    'AssetCheck' {
        Invoke-ProjectGodot -LogName 'asset-check.log' -Arguments @('--headless', '--script', 'res://tools/check_starter.gd')
    }
    'DiagnosticsCheck' {
        Invoke-ProjectGodot -LogName 'diagnostics-check.log' -Arguments @('--headless', '--scene', 'res://tools/diagnostics_probe.tscn')
    }
    'ClocksCheck' {
        Invoke-ProjectGodot -LogName 'clocks-check.log' -Arguments @('--headless', '--scene', 'res://tools/clocks_probe.tscn')
    }
    'SessionCheck' {
        Invoke-ProjectGodot -LogName 'session-check.log' -Arguments @('--headless', '--scene', 'res://tools/session_probe.tscn')
    }
    'UnitsCheck' {
        Invoke-ProjectGodot -LogName 'units-check.log' -Arguments @('--headless', '--scene', 'res://tools/units_probe.tscn')
    }
    'ContractsCheck' {
        Invoke-ProjectGodot -LogName 'contracts-check.log' -Arguments @('--headless', '--scene', 'res://tools/contracts_probe.tscn')
    }
    'GeographyCheck' {
        Invoke-ProjectGodot -LogName 'geography-check.log' -Arguments @('--headless', '--scene', 'res://tools/geography_probe.tscn')
    }
    'CatalogCheck' {
        Invoke-ProjectGodot -LogName 'catalog-check.log' -Arguments @('--headless', '--script', 'res://tools/check_catalog.gd')
    }
    'FlowCheck' {
        Invoke-ProjectGodot -LogName 'flow-check.log' -Arguments @('--headless', '--script', 'res://tools/check_flow.gd')
    }
    'ControlsCheck' {
        Invoke-ProjectGodot -LogName 'controls-check.log' -Arguments @('--headless', '--script', 'res://tools/check_controls.gd')
    }
    'Export' {
        Install-ExportTemplates
        [System.IO.Directory]::CreateDirectory($exportRoot) | Out-Null
        Invoke-ProjectGodot -LogName 'environment-import.log' -Arguments @('--headless', '--editor', '--import')
        $exportOption = '--export-' + $Configuration.ToLowerInvariant()
        Invoke-ProjectGodot -LogName ('export-' + $Configuration.ToLowerInvariant() + '.log') -Arguments @('--headless', $exportOption, 'Windows Desktop', $exportPath)
        foreach ($artifact in @($exportPath, [System.IO.Path]::ChangeExtension($exportPath, '.pck'))) {
            if (-not (Test-Path -LiteralPath $artifact -PathType Leaf) -or (Get-Item -LiteralPath $artifact).Length -eq 0) {
                throw "Export artifact missing or empty: $artifact"
            }
        }
        Write-Host "Export ready: $exportPath (keep the entire export folder together, including the SQLite DLL)"
    }
    'RunExport' {
        $dllName = 'libgdsqlite.windows.template_' + $Configuration.ToLowerInvariant() + '.x86_64.dll'
        $dllPin = $dependency.files | Where-Object { $_.path.EndsWith('/' + $dllName) }
        $exportDll = Join-Path $exportRoot $dllName
        if (-not (Test-Path $exportDll) -or (Get-FileHash $exportDll).Hash -ne $dllPin.sha256) {
            throw 'Export SQLite DLL is missing or differs from the pin. Rebuild the export.'
        }
        foreach ($artifact in @($exportPath, [System.IO.Path]::ChangeExtension($exportPath, '.pck'))) {
            if (-not (Test-Path -LiteralPath $artifact -PathType Leaf)) { throw "Build $Configuration first: missing $artifact" }
        }
        $launchArguments = @()
        if ($Headless) { $launchArguments += '--headless' }
        if ($QuitAfter -gt 0) { $launchArguments += @('--quit-after', [string]$QuitAfter) }
        if ($DiagnosticsProbe) { $launchArguments += @('--', '--diagnostics-check') }
        if ($ClocksProbe) { $launchArguments += @('--', '--clocks-check') }
        if ($SessionProbe) { $launchArguments += @('--', '--session-check') }
        if ($UnitsProbe) { $launchArguments += @('--', '--units-check') }
        if ($ContractsProbe) { $launchArguments += @('--', '--contracts-check') }
        if ($GeographyProbe) { $launchArguments += @('--', '--geography-check') }
        Invoke-ProjectGodot -Exported -LogName ('export-run-' + $Configuration.ToLowerInvariant() + '.log') -Arguments $launchArguments
    }
    default {
        $launchArguments = @()
        if ($Mode -eq 'Editor') { $launchArguments += '--editor' }
        if ($Scene) { $launchArguments += @('--scene', $Scene) }
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
