# Run with pwsh -NoProfile -File tools/server_package/check_core.ps1.
# Synthetic local files only; no download, server PC or player data.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ServerCore.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$script:count = 0
function Check($Condition, $Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:count++
}
function Refuses([scriptblock]$Action, $Message) {
    $refused = $false
    try { & $Action | Out-Null } catch { $refused = $true }
    Check $refused $Message
}
function Fake-Package($Path, $Tag) {
    [IO.Directory]::CreateDirectory($Path) | Out-Null
    $files = @{}
    foreach ($name in @('ShippingLanesServer.exe', 'ShippingLanesServer.pck', 'ServerCore.ps1', 'ServerLauncher.ps1')) {
        [IO.File]::WriteAllText((Join-Path $Path $name), "synthetic $Tag $name")
        $files[$name] = (Get-FileHash -LiteralPath (Join-Path $Path $name)).Hash.ToLowerInvariant()
    }
    Write-JsonAtomic (Join-Path $Path 'package.json') @{ version = $Tag; engine = '4.7.2'; files = $files }
}
function Zip-Package($Source, $Tag, $Zip, $Extra = '') {
    $archive = [IO.Compression.ZipFile]::Open($Zip, 'Create')
    try {
        foreach ($file in Get-ChildItem -LiteralPath $Source -File) {
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, "versions/$Tag/$($file.Name)") | Out-Null
        }
        if ($Extra) {
            $entry = $archive.CreateEntry($Extra)
            $writer = New-Object IO.StreamWriter($entry.Open())
            $writer.Write('untrusted')
            $writer.Dispose()
        }
    } finally { $archive.Dispose() }
    [pscustomobject]@{ tag = $Tag; size = (Get-Item -LiteralPath $Zip).Length; sha256 = (Get-FileHash -LiteralPath $Zip).Hash }
}
$root = Join-Path ([IO.Path]::GetTempPath()) ('shipping-launcher-check-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($root) | Out-Null
try {
    # Parse every PowerShell source (including the Windows-only WPF view).
    foreach ($source in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1') {
        $tokens = $null; $errors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($source.FullName, [ref]$tokens, [ref]$errors)
        Check ($errors.Count -eq 0) "PowerShell parses $($source.Name)"
    }
    $release = [pscustomobject]@{ draft = $false; prerelease = $false; tag_name = 'v3.0.1'; assets = @([pscustomobject]@{
        name = $script:AssetName; browser_download_url = "https://github.com/andymarkviera/Shipping-Lanes-Server-Releases/releases/download/v3.0.1/$script:AssetName"; size = 100; digest = ('sha256:' + ('a' * 64)) }) }
    Check ($null -ne (Select-Release $release 'v3.0.0')) 'new release selected'
    Check ($null -eq (Select-Release $release 'v3.0.1')) 'same tag ignored'
    Check ($null -eq (Select-Release $release 'v3.0.2')) 'older release ignored'
    $release.prerelease = $true
    Check ($null -eq (Select-Release $release 'v3.0.0')) 'prerelease ignored'
    $release.prerelease = $false
    $release.assets[0].browser_download_url = 'https://example.invalid/server.zip'
    Refuses { Select-Release $release 'v3.0.0' } 'foreign download rejected'
    Refuses { Get-Version 'v3.0.1/../../saves' } 'tag traversal rejected'
    Write-JsonAtomic "$root/current.json" @{ version = 'v3.0.0' }
    Fake-Package "$root/versions/v3.0.0" 'v3.0.0'
    Fake-Package "$root/source" 'v3.0.1'
    $good = Zip-Package "$root/source" 'v3.0.1' "$root/good.zip"
    [IO.Directory]::CreateDirectory("$root/staging/good") | Out-Null
    Expand-ServerPackage "$root/good.zip" "$root/staging/good" $good
    Check ((Test-Package "$root/staging/good" 'v3.0.1').version -eq 'v3.0.1') 'good zip validates'
    $good.sha256 = '0' * 64
    Refuses { Expand-ServerPackage "$root/good.zip" "$root/hash-bad" $good } 'bad download digest rejected'
    foreach ($badName in @('../saves/world.json', 'versions/v3.0.1/../../saves/world.json', 'saves/world.json', 'versions/v3.0.1/ServerCore.ps1', 'versions/v3.0.1/stray.txt')) {
        $zip = "$root/bad-$script:count.zip"
        $bad = Zip-Package "$root/source" 'v3.0.1' $zip $badName
        Refuses { Expand-ServerPackage $zip "$root/extract-$script:count" $bad } "unsafe zip rejected: $badName"
    }
    Check (-not (Test-Path -LiteralPath "$root/saves/world.json")) 'archive never writes saves'
    [IO.File]::AppendAllText("$root/staging/good/ShippingLanesServer.pck", 'tamper')
    Refuses { Install-StagedRelease $root "$root/staging/good" 'v3.0.1' } 'corrupt payload rejected'
    Check ((Get-InstalledTag $root) -eq 'v3.0.0') 'failed update retains pointer'
    Remove-Item -LiteralPath "$root/staging/good" -Recurse -Force
    Fake-Package "$root/staging/good" 'v3.0.1'
    [IO.Directory]::CreateDirectory("$root/saves/nested") | Out-Null
    [IO.File]::WriteAllText("$root/saves/nested/world.json", 'synthetic saved captains')
    [IO.File]::WriteAllText("$root/server-config.json", 'operator-config')
    [IO.Directory]::CreateDirectory("$root/saves.lock") | Out-Null
    Refuses { Install-StagedRelease $root "$root/staging/good" 'v3.0.1' } 'writer lock aborts update'
    Remove-Item -LiteralPath "$root/saves.lock" -Force
    [IO.Directory]::CreateDirectory("$root/control/fake") | Out-Null
    Write-JsonAtomic "$root/server-process.json" @{ pid = 2147483647; version = 'v3.0.0'; started = '1'; control = "$root/control/fake" }
    Refuses { Install-StagedRelease $root "$root/staging/good" 'v3.0.1' } 'missing clean receipt aborts update'
    Write-JsonAtomic "$root/control/fake/stopped.json" @{ saved = $false; pid = 2147483647 }
    Refuses { Assert-CleanStop $root } 'failed shutdown save aborts update'
    Write-JsonAtomic "$root/control/fake/stopped.json" @{ saved = $true; pid = 2147483647 }
    Install-StagedRelease $root "$root/staging/good" 'v3.0.1'
    Check ((Get-InstalledTag $root) -eq 'v3.0.1') 'pointer switches only after backup'
    Check ((Get-Content -LiteralPath "$root/saves/nested/world.json" -Raw) -ceq 'synthetic saved captains') 'saves unchanged'
    Check ((Get-Content -LiteralPath "$root/server-config.json" -Raw) -ceq 'operator-config') 'config unchanged'
    $backup = @(Get-ChildItem -LiteralPath "$root/backups" -Directory)[0]
    Check ((Get-Content -LiteralPath "$($backup.FullName)/saves/nested/world.json" -Raw) -ceq 'synthetic saved captains') 'byte exact backup'
    Check (Test-Path -LiteralPath "$root/versions/v3.0.0/ShippingLanesServer.exe") 'old runtime retained'
    Refuses { Install-StagedRelease $root "$root/source" 'v3.0.0' } 'downgrade rejected'
    # Failed backup and repeated updates cannot reset data; retain last five.
    [IO.File]::WriteAllText("$root/backups-blocked", 'synthetic blocker')
    Move-Item -LiteralPath "$root/backups" -Destination "$root/backups-original"
    Move-Item -LiteralPath "$root/backups-blocked" -Destination "$root/backups"
    Fake-Package "$root/staging/blocked" 'v3.0.2'
    Refuses { Install-StagedRelease $root "$root/staging/blocked" 'v3.0.2' } 'backup failure aborts update'
    Check ((Get-InstalledTag $root) -eq 'v3.0.1') 'backup failure retains pointer'
    Remove-Item -LiteralPath "$root/backups"
    Move-Item -LiteralPath "$root/backups-original" -Destination "$root/backups"
    for ($patch = 2; $patch -le 7; $patch++) {
        $tag = "v3.0.$patch"
        Fake-Package "$root/staging/$tag" $tag
        Install-StagedRelease $root "$root/staging/$tag" $tag
    }
    Check (@(Get-ChildItem -LiteralPath "$root/backups" -Directory).Count -eq 5) 'only last five completed backups retained'
    # PID collision with this test's own process must never write a stop marker.
    Write-JsonAtomic "$root/server-process.json" @{ pid = $PID; version = 'v3.0.0'; started = '1'; control = "$root/control/fake" }
    Refuses { Request-ServerStop $root } 'recycled PID rejected'
    Check (-not (Test-Path -LiteralPath "$root/control/fake/stop.request")) 'foreign process untouched'
    Write-Host "SERVER_LAUNCHER_CORE_PASS ($script:count assertions)"
} finally { Remove-Item -LiteralPath $root -Recurse -Force }
