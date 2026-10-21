#requires -Version 7.4
[CmdletBinding()]
param([ValidateSet('Editor','Release')][string]$Runtime='Editor', [switch]$Replication, [switch]$Cargo, [switch]$ConnectedWorld, [switch]$Actions, [ValidateSet('normal','impaired')][string]$Profile='normal')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$workspaceRoot=Split-Path -Parent $projectRoot
$portableRoot=Join-Path $workspaceRoot 'output/tools/godot-4.7.2'
$binary=if($Runtime -eq 'Editor'){Join-Path $portableRoot 'godot.windows.opt.tools.64.exe'}else{Join-Path $projectRoot 'exports/windows-x86_64/release/ShippingLanes.exe'}
$runRoot=Join-Path $workspaceRoot ('output/network-checks/'+$Runtime+'-'+$Profile+'-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)
# Select a free loopback UDP port. Host binding still handles the small race.
$socket=[Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback,0))
$port=$socket.Client.LocalEndPoint.Port
$socket.Dispose()
$children=@()
try {
 foreach($role in @('host','client')){
  $start=[Diagnostics.ProcessStartInfo]::new()
  $start.FileName=$binary
  $start.WorkingDirectory=Split-Path -Parent $binary
  $start.UseShellExecute=$false
  $start.CreateNoWindow=$true
  $start.RedirectStandardOutput=$true
  $start.RedirectStandardError=$true
  $start.Environment['APPDATA']=Join-Path $runRoot ('a/'+$role)
  $arguments=@('--headless','--log-file',(Join-Path $runRoot "$role.log"))
  if($Runtime -eq 'Editor'){$arguments+=@('--path',$projectRoot)}
  $checkFlag=if($Actions){'--action-check'}elseif($ConnectedWorld){'--connected-world-check'}elseif($Cargo){'--cargo-network-check'}elseif($Replication){'--replication-check'}else{'--network-check'}
  $arguments+=@('--',$checkFlag,"--network-profile=$Profile","--network-role=$role","--network-port=$port","--network-results=$runRoot")
  foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
  $process=[Diagnostics.Process]::Start($start)
  $children+=@{Process=$process;Out=$process.StandardOutput.ReadToEndAsync();Err=$process.StandardError.ReadToEndAsync();Role=$role}
  if($role -eq 'host'){
   $timer=[Diagnostics.Stopwatch]::StartNew()
   while(-not(Test-Path (Join-Path $runRoot 'ready')) -and -not $process.HasExited -and $timer.Elapsed.TotalSeconds -lt 10){Start-Sleep -Milliseconds 50}
   if(-not(Test-Path (Join-Path $runRoot 'ready'))){throw "Host did not start; see $runRoot"}
  }
 }
 foreach($child in $children){
  if(-not $child.Process.WaitForExit(25000)){throw "Network process timeout; see $runRoot"}
  $text=$child.Out.GetAwaiter().GetResult()+$child.Err.GetAwaiter().GetResult()
  if($child.Process.ExitCode -ne 0 -or $text -match '(?m)^(ERROR|SCRIPT ERROR):' -or $text -notmatch ('NETWORK_'+$child.Role.ToUpper()+'_PASS')){throw "Network check failed: $text"}
  Write-Host $text.Trim()
 }
 $hostResult=Get-Content (Join-Path $runRoot 'host.json') -Raw | ConvertFrom-Json
 $clientResult=Get-Content (Join-Path $runRoot 'client.json') -Raw | ConvertFrom-Json
 if(-not $Replication -and -not $Cargo -and -not $ConnectedWorld -and -not $Actions){
 if($hostResult.rounds.Count -ne 3 -or $clientResult.rounds.Count -ne 3){throw 'Missing reconnect rounds'}
 for($round=0;$round -lt 3;$round++){
  if(($hostResult.rounds[$round] -join ',') -ne ($clientResult.rounds[$round] -join ',')){throw "Ship identity mismatch in round $round"}
 }
 }
 Write-Host "NETWORK_CHECK_PASS $Runtime -- two processes verified; evidence: $runRoot"
} finally {
 foreach($child in $children){if(-not $child.Process.HasExited){$child.Process.Kill();$child.Process.WaitForExit()};$child.Process.Dispose()}
}
