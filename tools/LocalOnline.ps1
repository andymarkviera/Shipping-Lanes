#requires -Version 7.4
[CmdletBinding()]
param(
    [ValidateSet('Setup','Start','Stop','Play')][string]$Action = 'Start',
    [ValidatePattern('^[a-z0-9-]+$')][string]$Name = 'development',
    [ValidateSet('Editor','Release')][string]$Runtime = 'Editor',
    [string]$Python = 'C:/Users/andyv/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$runner = Join-Path $PSScriptRoot 'public_handoff/local_online.py'
$folder = Join-Path $workspaceRoot "output/local-online/$Name"
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) { throw 'Supply the managed Python executable using -Python.' }
$operation = @{Setup='init';Start='run';Stop='stop';Play='client'}[$Action]
if ($Action -eq 'Start') {
    if (-not (Test-Path -LiteralPath (Join-Path $folder 'initialized.json'))) {
        & $Python $runner init --name $Name
        if ($LASTEXITCODE -ne 0) { throw 'Local setup failed; existing data has not been reset.' }
    }
    # Unique supervisor log paths avoid interfering with an existing run on duplicate Start.
    $id = [Guid]::NewGuid().ToString('N')
    $log = Join-Path $folder "supervisor-$id.log"
    $errorLog = Join-Path $folder "supervisor-$id-errors.log"
    $arguments = @(('"' + $runner + '"'), 'run', '--name', $Name, '--runtime', $Runtime.ToLowerInvariant())
    $process = Start-Process -FilePath $Python -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $errorLog -PassThru
    [pscustomobject]@{ProcessId=$process.Id;State='Starting';Log=$log;ErrorLog=$errorLog;Note='Wait for LOCAL_ONLINE_READY. Use -Action Play for the isolated development client.'}
} else {
    & $Python $runner $operation --name $Name --runtime $Runtime.ToLowerInvariant()
    if ($LASTEXITCODE -ne 0) { throw 'Local online action failed; see the message above.' }
}
