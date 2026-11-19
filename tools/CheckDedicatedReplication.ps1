[CmdletBinding()]
param(
    [string]$Godot = 'C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe',
    [ValidateSet('Replication','Split')][string]$Probe = 'Replication',
    [switch]$Families
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ((& $Godot --version) -notmatch '^4\.7\.2\.') { throw 'Godot 4.7.2 required.' }
$folder = Join-Path $root ('.godot/replication-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($folder) | Out-Null
$socket = New-Object Net.Sockets.UdpClient(0)
$port = $socket.Client.LocalEndPoint.Port
$socket.Close()
$children = @()
$oldAppData = $env:APPDATA
$script = if ($Probe -eq 'Split') { 'dedicated_split_check.gd' } else { 'dedicated_replication_check.gd' }
$marker = if ($Probe -eq 'Split') { 'DEDICATED_SPLIT_PASS' } else { 'DEDICATED_REPLICATION_PASS' }
function Read-ProbeLog([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = New-Object IO.StreamReader($stream)
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}
try {
    foreach ($role in @('server','client1','client2')) {
        $data = Join-Path $folder $role
        [IO.Directory]::CreateDirectory($data) | Out-Null
        $env:APPDATA = $data
        $mode = if ($role -eq 'server') { '--server' } else { '--connect' }
        $log = Join-Path $data 'godot.log'
        $arguments = @('--headless','--path',('"' + $root + '"'),'--log-file',('"' + $log + '"'),'--script',('res://tools/' + $script),'--',$mode,"--port=$port",("--captain=Probe-" + $role))
        if ($Families) { $arguments += '--families' }
        $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $data 'stdout.txt') -RedirectStandardError (Join-Path $data 'stderr.txt')
        # Retain the native handle so Windows PowerShell preserves ExitCode.
        $null = $process.Handle
        $children += @{ Process = $process; Log = $log; Data = $data }
        if ($role -eq 'server') {
            $deadline = [DateTime]::UtcNow.AddSeconds(35)
            while ([DateTime]::UtcNow -lt $deadline) {
                if ((Test-Path -LiteralPath $log) -and ((Read-ProbeLog $log).Contains('DEDICATED_SERVER_READY'))) { break }
                if ((Test-Path -LiteralPath $log) -and ((Read-ProbeLog $log) -match 'SCRIPT ERROR')) { throw "Server script error. Logs: $folder" }
                if ($process.HasExited) { throw "Server exited before readiness. Logs: $folder" }
                Start-Sleep -Milliseconds 100
            }
            if ([DateTime]::UtcNow -ge $deadline) { throw "Server readiness timeout. Logs: $folder" }
        }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(75)
    while ([DateTime]::UtcNow -lt $deadline -and @($children | Where-Object { -not $_.Process.HasExited }).Count -gt 0) { Start-Sleep -Milliseconds 200 }
    foreach ($child in $children) {
        $output = Read-ProbeLog $child.Log
        Write-Output $output
        # The restricted Windows runner cannot read the OS CA store. UDP gameplay
        # uses no TLS; retain the diagnostic but reject every other engine error.
        $checkedOutput = $output.Replace('ERROR: Failed to read the root certificate store.', '')
        if ($child.Process.HasExited) { $child.Process.WaitForExit() }
        if (-not $child.Process.HasExited -or $child.Process.ExitCode -ne 0 -or -not $output.Contains($marker) -or $checkedOutput -match 'SCRIPT ERROR|ERROR:') { throw "Loopback failed (exit=$($child.Process.ExitCode)). Logs: $folder" }
    }
    if (@(Get-ChildItem -LiteralPath $folder -Recurse -File | Where-Object { $_.Name -match '\.(db|sqlite)' }).Count -gt 0) { throw 'Unexpected database in isolated network runtime.' }
    Write-Output "DEDICATED_LOOPBACK_PASS $Probe server + 2 clients; no databases"
} finally {
    $env:APPDATA = $oldAppData
    foreach ($child in $children) {
        if (-not $child.Process.HasExited) { $child.Process.Kill(); $child.Process.WaitForExit() }
        $child.Process.Dispose()
    }
}
