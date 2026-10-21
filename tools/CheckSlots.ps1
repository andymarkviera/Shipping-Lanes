#requires -Version 7.4
[CmdletBinding()]
param([ValidateSet('Editor','Debug','Release')][string]$Runtime='Editor')
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$workspaceRoot=Split-Path -Parent $projectRoot
$manifest=Get-Content (Join-Path $projectRoot 'sqlite-dependency.json') -Raw | ConvertFrom-Json
foreach($entry in $manifest.files){if((Get-FileHash (Join-Path $projectRoot $entry.path)).Hash -ne $entry.sha256){throw "Dependency hash mismatch: $($entry.path)"}}
$runId=[Guid]::NewGuid().ToString('N')
$runRoot=Join-Path $workspaceRoot "output/slots-checks/$Runtime-$runId"
[IO.Directory]::CreateDirectory($runRoot)|Out-Null
$appData=Join-Path $runRoot 'a'
$binary=if($Runtime -eq 'Editor'){Join-Path $workspaceRoot 'output/tools/godot-4.7.2/godot.windows.opt.tools.64.exe'}else{Join-Path $projectRoot "exports/windows-x86_64/$($Runtime.ToLowerInvariant())/ShippingLanes.exe"}
if(-not(Test-Path $binary)){throw 'Build the selected runtime first.'}
foreach($phase in @('slots')){
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
 $argsList+=@('--','--slots-check',"--slots-proof=$runId")
 foreach($a in $argsList){$start.ArgumentList.Add($a)}
 $process=[Diagnostics.Process]::Start($start)
 try{
  $stdout=$process.StandardOutput.ReadToEndAsync()
  $stderr=$process.StandardError.ReadToEndAsync()
  if(-not $process.WaitForExit(20000)){throw "Timeout: $phase"}
  if($process.ExitCode -ne 0){throw "Phase $phase exit $($process.ExitCode); see $runRoot"}
  $outputText=$stdout.GetAwaiter().GetResult()+$stderr.GetAwaiter().GetResult()
  if($outputText -match '(?m)^(ERROR|SCRIPT ERROR):'){throw "Runtime error: $outputText"}
  if($outputText -notmatch "SLOTS_CHECK_PASS"){throw "Missing success marker: $outputText"}
  Write-Host $outputText.Trim()
 }finally{if(-not $process.HasExited){$process.Kill();$process.WaitForExit()};$process.Dispose()}
}
Write-Host "SLOTS_RUN_PASS $Runtime -- evidence: $runRoot"
