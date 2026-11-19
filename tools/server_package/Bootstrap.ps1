param([switch]$StartServer)
$ErrorActionPreference = 'Stop'
try {
    $root = $PSScriptRoot
    $version = (Get-Content -LiteralPath (Join-Path $root 'current.json') -Raw | ConvertFrom-Json).version
    if ($version -cnotmatch '^v\d+\.\d+\.\d+$') { throw 'Invalid installed version.' }
    & (Join-Path $root "versions/$version/ServerLauncher.ps1") -Root $root -StartServer:$StartServer
} catch {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($_.Exception.Message, 'Shipping Lanes Server') | Out-Null
}
