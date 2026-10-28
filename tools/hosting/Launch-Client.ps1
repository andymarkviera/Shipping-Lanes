param([ValidateSet('LAN','Internet')][string]$Connection = 'Internet')
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $PSScriptRoot ($Connection.ToLowerInvariant() + '.json')
if (-not (Test-Path -LiteralPath $configPath)) { throw 'This connection configuration is missing. Ask the host operator to generate it.' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$certificate = Join-Path $PSScriptRoot 'server-certificate.pem'
$config.login.ca = $certificate
$config.authority_ca = $certificate
foreach ($server in $config.servers) { $server.certificate = $certificate }
# Dedicated client profile: preserve the ordinary Port Test save and settings.
$clientData = Join-Path $PSScriptRoot 'PlayerData'
$target = Join-Path $clientData 'Godot/app_userdata/Shipping Lanes'
New-Item -ItemType Directory -Force -Path $target | Out-Null
[System.IO.File]::WriteAllText((Join-Path $target 'public_services.json'), ($config | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
$originalAppData = $env:APPDATA
try {
    $env:APPDATA = $clientData
    $gameArguments = @('--', '--friends-client')
    if ($Connection -eq 'LAN') { $gameArguments += '--lan' }
    Start-Process -ArgumentList $gameArguments -FilePath (Join-Path $PSScriptRoot 'Game/ShippingLanes.exe') -WorkingDirectory $PSScriptRoot
} finally { $env:APPDATA = $originalAppData }
