#requires -Version 7.4
[CmdletBinding()]
param([ValidateSet('Editor','Debug','Release')][string]$Runtime='Editor')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$workspaceRoot=Split-Path -Parent $projectRoot
$manifest=Get-Content (Join-Path $projectRoot 'sqlite-dependency.json') -Raw | ConvertFrom-Json
foreach($entry in $manifest.files){if((Get-FileHash (Join-Path $projectRoot $entry.path)).Hash -ne $entry.sha256){throw "Dependency hash mismatch: $($entry.path)"}}
$runId=[Guid]::NewGuid().ToString('N')
$runRoot=Join-Path $workspaceRoot "output/recovery-checks/$Runtime-$runId"
[IO.Directory]::CreateDirectory($runRoot)|Out-Null
$appData=Join-Path $runRoot 'appdata'
$fixtureRoot=Join-Path $appData "Godot/app_userdata/Shipping Lanes/action-recovery/$runId"
$binary=if($Runtime -eq 'Editor'){Join-Path $workspaceRoot 'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe'}else{Join-Path $projectRoot "exports/windows-x86_64/$($Runtime.ToLowerInvariant())/ShippingLanes.exe"}
if(-not(Test-Path $binary)){throw 'Build the selected runtime first.'}
foreach($phase in @('init','pending','recover','prepared','retry','committed','verify','reopen')){
 $start=[Diagnostics.ProcessStartInfo]::new()
 $start.FileName=$binary
 $start.WorkingDirectory=Split-Path -Parent $binary
 $start.UseShellExecute=$false
 $start.CreateNoWindow=$true
 $start.RedirectStandardOutput=$true
 $start.RedirectStandardError=$true
 $start.Environment['APPDATA']=$appData
 $argsList=@('--headless','--log-file',(Join-Path $runRoot "$phase.log"))
 if($Runtime -eq 'Editor'){$argsList+=@('--path',$projectRoot)}
 $argsList+=@('--','--recovery-check',"--recovery-root=user://action-recovery/$runId","--recovery-phase=$phase")
 foreach($a in $argsList){$start.ArgumentList.Add($a)}
 $process=[Diagnostics.Process]::Start($start)
 try{
  $stdout=$process.StandardOutput.ReadToEndAsync()
  $stderr=$process.StandardError.ReadToEndAsync()
  if($phase -in @('pending','prepared','committed')){
   $ready=Join-Path $fixtureRoot "$phase.ready"
   $timer=[Diagnostics.Stopwatch]::StartNew()
   while(-not(Test-Path $ready) -and -not $process.HasExited -and $timer.Elapsed.TotalSeconds -lt 20){Start-Sleep -Milliseconds 50}
   if(-not(Test-Path $ready)){throw "Crash fixture not ready: $phase"}
   # Terminate only the child launched above, never an editor or unrelated game.
   $process.Kill()
   $process.WaitForExit()
   Write-Host "${Runtime} ${phase}: owned process terminated at ready marker"
  }else{
   if(-not $process.WaitForExit(20000)){throw "Timeout: $phase"}
   if($process.ExitCode -ne 0){throw "Phase $phase exit $($process.ExitCode); see $runRoot"}
  }
  $outputText=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
  if($outputText -match '(?m)^(ERROR|SCRIPT ERROR):'){throw "Runtime error: $outputText"}
  if($phase -notin @('pending','prepared','committed') -and $outputText -notmatch "RECOVERY_PHASE_PASS $phase"){throw "Missing success marker: $outputText"}
  Write-Host $outputText.Trim()
 }finally{if(-not $process.HasExited){$process.Kill();$process.WaitForExit()};$process.Dispose()}
}
Write-Host "RECOVERY_CHECK_PASS $Runtime -- evidence: $runRoot"
