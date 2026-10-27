param([ValidateSet('Setup','Start','Stop','Clients','Check')][string]$Action = 'Check')
$ErrorActionPreference = 'Stop'
$python = Join-Path $PSScriptRoot 'Runtime/python/python.exe'
$runner = Join-Path $PSScriptRoot 'ShippingLanes/tools/hosting/host.py'
if ($Action -eq 'Start') {
    $logDirectory = Join-Path $PSScriptRoot 'Logs'
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $stamp = [Guid]::NewGuid().ToString('N')
    $arguments = @(('"' + $runner + '"'), 'run')
    $process = Start-Process -FilePath $python -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logDirectory ($stamp + '.log')) -RedirectStandardError (Join-Path $logDirectory ($stamp + '-errors.log'))
    Write-Output "Started supervisor $($process.Id). Wait for HOST_READY in Logs/$stamp.log."
} else {
    $operation = @{Setup='setup';Stop='stop';Clients='clients';Check='check'}[$Action]
    & $python $runner $operation
    if ($LASTEXITCODE -ne 0) { throw 'Host command failed. See the message above; do not delete the saved-data directory.' }
}
