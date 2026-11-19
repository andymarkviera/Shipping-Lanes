# Windows PowerShell 5.1, inbox .NET only. Dot-sourced by the launcher and checks.
$ErrorActionPreference = 'Stop'
$script:Feed = 'https://api.github.com/repos/andymarkviera/Shipping-Lanes-Server-Releases/releases/latest'
$script:AssetName = 'Shipping-Lanes-Server-Windows-x64.zip'

function Read-Json($Path) { Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json }
function Write-JsonAtomic($Path, $Value) {
    $temp = "$Path.new"
    [IO.File]::WriteAllText($temp, ($Value | ConvertTo-Json -Depth 20))
    if (Test-Path -LiteralPath $Path) {
        [IO.File]::Replace($temp, $Path, "$Path.previous")
        Remove-Item -LiteralPath "$Path.previous" -Force -ErrorAction SilentlyContinue
    }
    else { [IO.File]::Move($temp, $Path) }
}
function Get-Version($Tag) {
    if ($Tag -cnotmatch '^v\d+\.\d+\.\d+$') { throw 'Unsupported release tag (stable vMAJOR.MINOR.PATCH required).' }
    [version]$Tag.Substring(1)
}
function Get-InstalledTag($Root) {
    $tag = (Read-Json (Join-Path $Root 'current.json')).version
    $null = Get-Version $tag
    $tag
}
function Get-PackagePath($Root, $Tag) {
    $null = Get-Version $Tag
    Join-Path $Root "versions/$Tag"
}
function Test-Package($Path, $Tag) {
    $metadata = Read-Json (Join-Path $Path 'package.json')
    if ($metadata.version -cne $Tag -or $metadata.engine -cne '4.7.2') { throw 'Package version/engine mismatch.' }
    foreach ($required in @('ShippingLanesServer.exe', 'ShippingLanesServer.pck', 'ServerCore.ps1', 'ServerLauncher.ps1')) {
        if ($null -eq $metadata.files.PSObject.Properties[$required]) { throw "Incomplete package: $required" }
    }
    $actual = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force)
    if ($actual.Count -ne @($metadata.files.PSObject.Properties).Count + 1) { throw 'Unexpected package files.' }
    foreach ($entry in $metadata.files.PSObject.Properties) {
        $name = $entry.Name
        if ($name -match '(^/|\\|:|(^|/)\.\.?(/|$))' -or $name -notmatch '\.(exe|pck|dll|dat|ps1)$') { throw 'Invalid manifest path.' }
        $file = Join-Path $Path $name
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ine $entry.Value) { throw "Package checksum mismatch: $name" }
    }
    $metadata
}
function Select-Release($Release, $Installed) {
    if ($Release.draft -or $Release.prerelease) { return $null }
    $tag = [string]$Release.tag_name
    if ((Get-Version $tag) -le (Get-Version $Installed)) { return $null }
    $assets = @($Release.assets | Where-Object { $_.name -ceq $script:AssetName })
    if ($assets.Count -ne 1) { throw 'Release has no unique Windows server package.' }
    $url = "https://github.com/andymarkviera/Shipping-Lanes-Server-Releases/releases/download/$tag/$script:AssetName"
    if ($assets[0].browser_download_url -cne $url -or $assets[0].size -le 0 -or $assets[0].size -gt 2147483648) { throw 'Invalid server asset URL/size.' }
    if ([string]$assets[0].digest -cnotmatch '^sha256:[a-fA-F0-9]{64}$') { throw 'Release asset needs its GitHub SHA256 digest.' }
    [pscustomobject]@{ tag = $tag; url = $url; size = [long]$assets[0].size; sha256 = $assets[0].digest.Substring(7) }
}
function Find-Release($Installed) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $release = Invoke-RestMethod -Uri $script:Feed -Headers @{ 'User-Agent' = 'Shipping-Lanes-Server-Launcher'; Accept = 'application/vnd.github+json' } -TimeoutSec 20
    Select-Release $release $Installed
}
function Expand-ServerPackage($Zip, $Destination, $Release) {
    if ((Get-Item -LiteralPath $Zip).Length -ne $Release.size -or (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash -ine $Release.sha256) { throw 'Download size/SHA256 mismatch.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        if ($archive.Entries.Count -gt 256) { throw 'Too many package entries.' }
        $total = 0L
        $seen = @{}
        $prefix = "versions/$($Release.tag)/"
        foreach ($entry in $archive.Entries) {
            $name = $entry.FullName
            if ($name -match '(^/|\\|:|(^|/)\.\.?(/|$))' -or $name -match '[<>|?*]' -or $name -match '[. ](/|$)' -or $seen.ContainsKey($name)) { throw 'Unsafe/duplicate ZIP path.' }
            $seen[$name] = $true
            # Reject UNIX symlinks and Windows reparse points.
            if (($entry.ExternalAttributes -band 0x400) -ne 0 -or (($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw 'Links are not allowed in a package.' }
            $total += $entry.Length
            if ($total -gt 4294967296) { throw 'Expanded package is too large.' }
            if ($name -in @('Bootstrap.ps1', 'LaunchServer.cmd', 'current.json', 'server-config.json')) { continue }
            if (-not $name.StartsWith($prefix, [StringComparison]::Ordinal)) { throw 'Package contains data outside its version folder.' }
            $relative = $name.Substring($prefix.Length)
            if (-not $relative) { continue }
            $target = Join-Path $Destination $relative
            if ($name.EndsWith('/')) { [IO.Directory]::CreateDirectory($target) | Out-Null; continue }
            if ($relative -notmatch '\.(exe|pck|dll|dat|ps1|json)$') { throw 'Unexpected runtime file type.' }
            [IO.Directory]::CreateDirectory((Split-Path $target)) | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $false)
        }
    } finally { $archive.Dispose() }
    $null = Test-Package $Destination $Release.tag
}
function Stage-Release($Root, $Release) {
    $jobPath = Join-Path $Root ('staging/' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($jobPath) | Out-Null
    try {
        $zip = Join-Path $jobPath 'package.zip'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri $Release.url -OutFile $zip -TimeoutSec 300 -Headers @{ 'User-Agent' = 'Shipping-Lanes-Server-Launcher' } | Out-Null
        $payload = Join-Path $jobPath 'payload'
        [IO.Directory]::CreateDirectory($payload) | Out-Null
        Expand-ServerPackage $zip $payload $Release
        $payload
    } catch { Remove-Item -LiteralPath $jobPath -Recurse -Force; throw }
}
function Get-OwnedServer($Root) {
    $statePath = Join-Path $Root 'server-process.json'
    if (-not (Test-Path -LiteralPath $statePath)) { return $null }
    $state = Read-Json $statePath
    $process = Get-Process -Id $state.pid -ErrorAction SilentlyContinue
    if ($null -eq $process) { return $null }
    # A recycled PID is never signalled. Require executable AND birth time.
    $expected = Join-Path (Get-PackagePath $Root $state.version) 'ShippingLanesServer.exe'
    if ($process.StartTime.ToUniversalTime().Ticks.ToString() -cne $state.started -or $process.Path -ine $expected) { throw 'Server process ownership changed; inspect before continuing.' }
    [pscustomobject]@{ process = $process; state = $state }
}
function Get-ServerStatus($Root) {
    $owned = Get-OwnedServer $Root
    if ($null -eq $owned) {
        $message = 'Stopped'
        try { Assert-CleanStop $Root } catch { $message = 'Stopped (checkpoint unconfirmed; inspect logs)' }
        return [pscustomobject]@{ state = $message; players = 0; version = Get-InstalledTag $Root; owned = $null }
    }
    $path = Join-Path $owned.state.control 'status.json'
    $status = $null
    if (Test-Path -LiteralPath $path) {
        try { $status = Read-Json $path } catch { } # writer rename/read race; retry next tick
    }
    $fresh = $null -ne $status -and $status.pid -eq $owned.state.pid -and ((Get-Date).ToUniversalTime() - (Get-Item -LiteralPath $path).LastWriteTimeUtc).TotalSeconds -lt 5
    [pscustomobject]@{ state = $(if ($fresh -and $status.listening) { 'Running (UDP listening)' } else { 'Starting / status unavailable' }); players = $(if ($fresh) { $status.players } else { '?' }); version = $owned.state.version; owned = $owned }
}
function Start-Server($Root) {
    if ($null -ne (Get-OwnedServer $Root)) { throw 'Server is already running.' }
    if (Test-Path -LiteralPath (Join-Path $Root 'saves.lock')) { throw 'Save guard remains. Inspect the stopped server; the launcher never removes it.' }
    $tag = Get-InstalledTag $Root
    $runtime = Get-PackagePath $Root $tag
    $null = Test-Package $runtime $tag
    $config = Read-Json (Join-Path $Root 'server-config.json')
    $address = $null
    $portValue = 0
    if (-not [int]::TryParse([string]$config.port, [ref]$portValue) -or $portValue -lt 1024 -or $portValue -gt 65535 -or -not [Net.IPAddress]::TryParse($config.bind, [ref]$address)) { throw 'Invalid bind/UDP port in server-config.json.' }
    $control = Join-Path $Root ('control/' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($control) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $Root 'logs')) | Out-Null
    # Start-Process joins arguments on Windows: quote full path values explicitly.
    if ($Root.Contains('"')) { throw 'Installation path contains a quote.' }
    $arguments = @('--headless', '--', '--server', "--port=$($config.port)", "--bind=$($config.bind)", ('--saves-dir="' + (Join-Path $Root 'saves') + '"'), ('--control-dir="' + $control + '"'))
    $log = Join-Path $Root ('logs/' + [guid]::NewGuid().ToString('N'))
    $process = Start-Process -FilePath (Join-Path $runtime 'ShippingLanesServer.exe') -WorkingDirectory $runtime -ArgumentList $arguments -PassThru -RedirectStandardOutput "$log.out.log" -RedirectStandardError "$log.err.log" -WindowStyle Hidden
    try {
        Write-JsonAtomic (Join-Path $Root 'server-process.json') @{ pid = $process.Id; started = $process.StartTime.ToUniversalTime().Ticks.ToString(); version = $tag; control = $control }
    } catch {
        # If process registration fails, ask this exact new instance to save/stop.
        [IO.File]::WriteAllText((Join-Path $control 'stop.request'), 'stop')
        throw
    }
}
function Request-ServerStop($Root) {
    $owned = Get-OwnedServer $Root
    if ($null -eq $owned) { return }
    [IO.File]::WriteAllText((Join-Path $owned.state.control 'stop.request'), 'stop')
}
function Assert-CleanStop($Root) {
    if ($null -ne (Get-OwnedServer $Root)) { throw 'Server is still running; update cancelled.' }
    $statePath = Join-Path $Root 'server-process.json'
    if (Test-Path -LiteralPath $statePath) {
        $state = Read-Json $statePath
        $receipt = Join-Path $state.control 'stopped.json'
        if (-not (Test-Path -LiteralPath $receipt)) { throw 'No successful shutdown checkpoint; update cancelled. Inspect logs and saves.' }
        $saved = Read-Json $receipt
        if (-not $saved.saved -or $saved.pid -ne $state.pid) { throw 'No successful shutdown checkpoint; update cancelled. Inspect logs and saves.' }
    }
    if (Test-Path -LiteralPath (Join-Path $Root 'saves.lock')) { throw 'Save guard remains; update cancelled.' }
}
function Install-StagedRelease($Root, $Payload, $Tag) {
    Assert-CleanStop $Root
    $null = Test-Package $Payload $Tag
    $old = Get-InstalledTag $Root
    if ((Get-Version $Tag) -le (Get-Version $old)) { throw 'Refusing a downgrade or repeated update.' }
    $destination = Get-PackagePath $Root $Tag
    if (Test-Path -LiteralPath $destination) { throw 'Version folder already exists; inspect it before retrying.' }
    # Backup is completed and checked before the pointer changes. Existing data
    # and previous packages remain intact on every failure; never auto-rollback
    # a world after a newer server may have migrated it.
    $saves = Join-Path $Root 'saves'
    if (Test-Path -LiteralPath $saves) {
        $backup = Join-Path $Root ('backups/' + $old + '-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ') + '-' + [guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($backup) | Out-Null
        Copy-Item -LiteralPath $saves -Destination (Join-Path $backup 'saves') -Recurse -Force
        foreach ($file in Get-ChildItem -LiteralPath $saves -File -Recurse -Force) {
            $relative = $file.FullName.Substring($saves.Length).TrimStart([char[]]'\/')
            if ((Get-FileHash -LiteralPath $file.FullName).Hash -cne (Get-FileHash -LiteralPath (Join-Path "$backup/saves" $relative)).Hash) { throw 'Backup verification failed.' }
        }
        [IO.File]::WriteAllText((Join-Path $backup 'complete'), $old)
        # Prune only completed launcher backups, after successful verification.
        @(Get-ChildItem -LiteralPath (Join-Path $Root 'backups') -Directory | Where-Object { $_.Name -match '^v\d+\.\d+\.\d+-' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'complete')) } | Sort-Object LastWriteTimeUtc -Descending | Select-Object -Skip 5) | Remove-Item -Recurse -Force
    }
    Move-Item -LiteralPath $Payload -Destination $destination
    Write-JsonAtomic (Join-Path $Root 'current.json') @{ version = $Tag }
}
