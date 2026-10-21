#requires -Version 7.4
[CmdletBinding()]
param(
 [ValidateSet('Editor','Release')][string]$Runtime='Editor',
 [int[]]$Counts=@(2,10,25,50,100),
 [ValidateSet('dispersed','crowded')][string[]]$Layouts=@('dispersed','crowded'),
 [switch]$VisibleObserver
)
$ErrorActionPreference='Stop'
if (@($Counts | Where-Object { $_ -notin @(2,10,25,50,100) }).Count) { throw 'Use the documented experiment counts.' }
$projectRoot=Split-Path -Parent $PSScriptRoot
$workspaceRoot=Split-Path -Parent $projectRoot
$portableRoot=Join-Path $workspaceRoot 'output/tools/godot-4.7.2'
$binary=if($Runtime -eq 'Editor'){Join-Path $portableRoot 'godot.windows.opt.tools.64.exe'}else{Join-Path $projectRoot 'exports/windows-x86_64/release/ShippingLanes.exe'}
$runRoot=Join-Path $workspaceRoot ('output/capacity-checks/'+$Runtime+'-'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($runRoot)
$summary=@()
foreach($count in $Counts){ foreach($layout in $Layouts){
 $caseRoot=Join-Path $runRoot "$count-$layout"
 [void][IO.Directory]::CreateDirectory($caseRoot)
 $socket=[Net.Sockets.UdpClient]::new([Net.IPEndPoint]::new([Net.IPAddress]::Loopback,0))
 $port=$socket.Client.LocalEndPoint.Port
 $socket.Dispose()
 $children=@()
 try {
  foreach($role in @('server','observer','bots')){
   $start=[Diagnostics.ProcessStartInfo]::new()
   $start.FileName=$binary
   $start.WorkingDirectory=Split-Path -Parent $binary
   $start.UseShellExecute=$false
   $start.CreateNoWindow=$true
   $start.RedirectStandardOutput=$true
   $start.RedirectStandardError=$true
   $start.Environment['APPDATA']=Join-Path $portableRoot 'user_data'
   $arguments=@('--log-file',(Join-Path $caseRoot "$role.log"))
   if(-not($VisibleObserver -and $role -eq 'observer')){$arguments+=@('--headless')}
   if($Runtime -eq 'Editor'){$arguments+=@('--path',$projectRoot)}
   $arguments+=@('--','--capacity-check',"--capacity-role=$role","--capacity-layout=$layout","--capacity-count=$count","--capacity-port=$port","--capacity-results=$caseRoot")
   foreach($argument in $arguments){$start.ArgumentList.Add($argument)}
   $process=[Diagnostics.Process]::Start($start)
   $children+=@{Process=$process;Out=$process.StandardOutput.ReadToEndAsync();Err=$process.StandardError.ReadToEndAsync();Role=$role;CpuStart=$null;CpuEnd=$null;PeakBytes=0L}
   if($role -eq 'server'){
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while(-not(Test-Path (Join-Path $caseRoot 'ready')) -and -not $process.HasExited -and $timer.Elapsed.TotalSeconds -lt 10){Start-Sleep -Milliseconds 50}
    if(-not(Test-Path (Join-Path $caseRoot 'ready'))){throw "Server did not start: $caseRoot"}
   }
  }
  $sample=[Diagnostics.Stopwatch]::StartNew()
  $cpuStartTime=0.0
  $cpuEndTime=0.0
  while($sample.Elapsed.TotalSeconds -lt 30 -and @($children | Where-Object {-not $_.Process.HasExited}).Count){
   $now=$sample.Elapsed.TotalSeconds
   foreach($child in $children){
    if($child.Process.HasExited){continue}
    $child.Process.Refresh()
    $child.PeakBytes=[Math]::Max($child.PeakBytes,$child.Process.WorkingSet64)
    if($now -ge 3 -and $null -eq $child.CpuStart){$child.CpuStart=$child.Process.TotalProcessorTime.TotalSeconds;$cpuStartTime=$now}
    if($now -ge 17 -and $null -eq $child.CpuEnd){$child.CpuEnd=$child.Process.TotalProcessorTime.TotalSeconds;$cpuEndTime=$now}
   }
   Start-Sleep -Milliseconds 50
  }
  $processMetrics=@{}
  foreach($child in $children){
   if(-not $child.Process.HasExited){throw "Capacity process timeout: $caseRoot"}
   $text=$child.Out.GetAwaiter().GetResult()+$child.Err.GetAwaiter().GetResult()
   if($child.Process.ExitCode -ne 0 -or $text -match '(?m)^(ERROR|SCRIPT ERROR):' -or $text -notmatch ('CAPACITY_'+$child.Role.ToUpper()+'_PASS')){throw "Capacity failed ($($child.Role)): $text"}
   if($null -eq $child.CpuEnd -or $null -eq $child.CpuStart){throw 'Missing CPU sampling interval'}
   $processMetrics[$child.Role]=@{cpu_core_percent=100*($child.CpuEnd-$child.CpuStart)/($cpuEndTime-$cpuStartTime);peak_working_set_mib=$child.PeakBytes/1MB}
  }
  $serverResult=Get-Content (Join-Path $caseRoot 'server.json') -Raw | ConvertFrom-Json
  $observerResult=Get-Content (Join-Path $caseRoot 'observer.json') -Raw | ConvertFrom-Json
  $result=@{count=$count;layout=$layout;runtime=$Runtime;visible_observer=[bool]$VisibleObserver;server=$serverResult;observer=$observerResult;processes=$processMetrics}
  $summary+=,$result
  $result | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $caseRoot 'metrics.json') -Encoding utf8
  Write-Host ("CAPACITY_PASS {0} {1} {2}: tick p95={3:N2}ms; server CPU={4:N1}% of one core; memory={5:N1}MiB; observer gap p95={6:N1}ms" -f $Runtime,$count,$layout,$serverResult.tick_ms.p95,$processMetrics.server.cpu_core_percent,$processMetrics.server.peak_working_set_mib,$observerResult.snapshot_gap_ms.p95)
 } finally {
  foreach($child in $children){if(-not $child.Process.HasExited){$child.Process.Kill();$child.Process.WaitForExit()};$child.Process.Dispose()}
 }
}}
$summary | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $runRoot 'summary.json') -Encoding utf8
Write-Host "CAPACITY_CHECK_PASS evidence: $runRoot"
