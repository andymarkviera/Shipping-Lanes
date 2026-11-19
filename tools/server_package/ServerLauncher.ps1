param([Parameter(Mandatory = $true)][string]$Root, [switch]$StartServer)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'ServerCore.ps1')
Add-Type -AssemblyName PresentationFramework
$Root = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar)
# One launcher owns Start/Stop/update, even across different installed versions.
try { $launcherLock = [IO.File]::Open((Join-Path $Root 'launcher.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
catch { [System.Windows.MessageBox]::Show('The Server Launcher is already open.', 'Shipping Lanes Server') | Out-Null; return }
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Shipping Lanes Server" Width="610" Height="510" MinWidth="570" MinHeight="480" Background="#0F1D3D" FontFamily="Segoe UI" Foreground="#FFF1C6" WindowStartupLocation="CenterScreen">
 <Window.Resources>
  <Style TargetType="Button"><Setter Property="Background" Value="#F5C34D"/><Setter Property="Foreground" Value="#102C48"/><Setter Property="FontWeight" Value="Bold"/><Setter Property="Padding" Value="17,10"/><Setter Property="Margin" Value="0,0,10,10"/><Setter Property="FontSize" Value="15"/></Style>
  <Style TargetType="TextBlock"><Setter Property="TextWrapping" Value="Wrap"/><Setter Property="Margin" Value="0,0,0,12"/></Style>
 </Window.Resources>
 <Border BorderBrush="#FFF1C6" BorderThickness="4" CornerRadius="18" Padding="25" Margin="16">
  <StackPanel>
   <TextBlock Text="SHIPPING LANES" FontSize="29" FontWeight="Black" Foreground="#F5C34D"/>
   <TextBlock Text="SERVER LAUNCHER" FontSize="16" FontWeight="Bold"/>
   <TextBlock x:Name="Status" FontSize="19" Text="Reading status..."/>
   <TextBlock x:Name="Connection"/>
   <WrapPanel><Button x:Name="Start" Content="Start"/><Button x:Name="Stop" Content="Stop"/><Button x:Name="Saves" Content="Open saves folder"/></WrapPanel>
   <WrapPanel><Button x:Name="Check" Content="Check for updates"/><Button x:Name="Update" Content="Update available" Visibility="Collapsed"/></WrapPanel>
   <TextBlock x:Name="Message" Text="Checking server releases..." MinHeight="44"/>
   <TextBlock Text="Closing this window leaves the server running. Stop saves every captain before shutdown." FontSize="12" Foreground="#CCDDE6"/>
  </StackPanel>
 </Border>
</Window>
'@
$window = [Windows.Markup.XamlReader]::Load((New-Object Xml.XmlNodeReader $xaml))
$widgets = @{}
foreach ($name in @('Status', 'Connection', 'Start', 'Stop', 'Saves', 'Check', 'Update', 'Message')) { $widgets[$name] = $window.FindName($name) }
$script:job = $null
$script:operation = ''
$script:release = $null
$script:payload = ''
$script:stoppingForUpdate = $false
$script:stopDeadline = $null
$script:stopOwned = $null
$script:relaunch = $false
$corePath = Join-Path $PSScriptRoot 'ServerCore.ps1'
function Begin-Work($Operation) {
    if ($null -ne $script:job) { return }
    foreach ($name in @('Start', 'Stop', 'Check', 'Update')) { $widgets[$name].IsEnabled = $false }
    $script:operation = $Operation
    $script:job = Start-Job -ArgumentList $corePath, $Operation, $Root, $script:release, $script:payload -ScriptBlock {
        param($Core, $Operation, $Root, $Release, $Payload)
        . $Core
        switch ($Operation) {
            'check' { Find-Release (Get-InstalledTag $Root) }
            'stage' { Stage-Release $Root $Release }
            'install' { Install-StagedRelease $Root $Payload $Release.tag }
            'start' { Start-Server $Root }
        }
    }
}
function Stop-ManagedServer {
    if ($null -ne $script:stopDeadline) { return }
    foreach ($name in @('Start', 'Stop', 'Check', 'Update')) { $widgets[$name].IsEnabled = $false }
    $script:stopOwned = Get-OwnedServer $Root
    if ($null -ne $script:stopOwned) {
        Request-ServerStop $Root
        $script:stopDeadline = (Get-Date).AddSeconds(60)
        $widgets.Message.Text = 'Stopping: waiting for the final save checkpoint...'
    }
}
$widgets.Start.Add_Click({ try { Begin-Work 'start'; $widgets.Message.Text = 'Starting server...' } catch { $widgets.Message.Text = $_.Exception.Message } })
$widgets.Stop.Add_Click({ try { Stop-ManagedServer } catch { $widgets.Message.Text = $_.Exception.Message } })
$widgets.Check.Add_Click({ Begin-Work 'check'; $widgets.Message.Text = 'Checking public server releases...' })
$widgets.Update.Add_Click({ Begin-Work 'stage'; $widgets.Message.Text = 'Downloading and verifying the server package. The server keeps running...' })
$widgets.Saves.Add_Click({
    try {
        $folder = Join-Path $Root 'saves'
        [IO.Directory]::CreateDirectory($folder) | Out-Null
        Start-Process explorer.exe -ArgumentList ('"' + $folder + '"') | Out-Null
    } catch { $widgets.Message.Text = $_.Exception.Message }
})
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    try {
        if ($null -ne $script:job -and $script:job.State -in @('Completed', 'Failed', 'Stopped')) {
            $completed = $script:operation
            $finished = $script:job
            $script:job = $null
            try {
                $result = @(Receive-Job -Job $finished -ErrorAction Stop)
                if ($finished.State -ne 'Completed') { throw 'Background operation failed.' }
            } finally { Remove-Job -Job $finished -Force }
            switch ($completed) {
                'check' {
                    $script:release = $(if ($result.Count) { $result[-1] } else { $null })
                    $widgets.Message.Text = $(if ($null -ne $script:release) { "Server $($script:release.tag) is available." } else { 'Server is up to date.' })
                }
                'stage' {
                    $script:payload = [string]$result[-1]
                    $script:stoppingForUpdate = $true
                    Stop-ManagedServer
                }
                'install' {
                    $script:release = $null
                    $script:payload = ''
                    # Reload the installed launcher's code before starting its server.
                    $script:relaunch = $true
                    $window.Close()
                    return
                }
                'start' { $widgets.Message.Text = 'Server launched. Waiting for UDP listening status...' }
            }
        }
        if ($null -ne $script:stopDeadline) {
            if ($script:stopOwned.process.HasExited) {
                $script:stopDeadline = $null
                Assert-CleanStop $Root
                $widgets.Message.Text = 'Stopped. Final checkpoint saved.'
            } elseif ((Get-Date) -gt $script:stopDeadline) {
                $script:stopDeadline = $null
                $script:stoppingForUpdate = $false
                throw 'Shutdown timed out; no process was killed and no update installed. Inspect logs before retrying.'
            }
        }
        if ($script:stoppingForUpdate -and $null -eq $script:stopDeadline -and $null -eq $script:job) {
            $script:stoppingForUpdate = $false
            Assert-CleanStop $Root
            $widgets.Message.Text = 'Verifying a saves backup and installing the update...'
            Begin-Work 'install'
        }
        $status = Get-ServerStatus $Root
        $widgets.Status.Text = "$($status.state)  |  Players: $($status.players)  |  $($status.version)"
        $config = Read-Json (Join-Path $Root 'server-config.json')
        $public = $(if ($config.public_address) { $config.public_address } else { 'Not configured' })
        $tunnel = $(if (@(Get-Process -Name 'playit*' -ErrorAction SilentlyContinue).Count) { 'Tunnel agent running (reachability unverified)' } else { 'Tunnel offline: playit agent not running' })
        $widgets.Connection.Text = "UDP $($config.port)  |  Public address: $public`n$tunnel"
        $busy = $null -ne $script:job -or $null -ne $script:stopDeadline -or $script:stoppingForUpdate
        $widgets.Start.IsEnabled = -not $busy -and $null -eq $status.owned
        $widgets.Stop.IsEnabled = -not $busy -and $null -ne $status.owned
        $widgets.Check.IsEnabled = -not $busy
        $widgets.Update.IsEnabled = -not $busy
        $widgets.Update.Visibility = $(if ($null -ne $script:release) { 'Visible' } else { 'Collapsed' })
    } catch {
        $script:stoppingForUpdate = $false
        $widgets.Message.Text = $_.Exception.Message
    }
})
$window.Add_Closing({
    if ($null -ne $script:job -or $null -ne $script:stopDeadline -or $script:stoppingForUpdate) {
        $_.Cancel = $true
        $widgets.Message.Text = 'Please wait for the current operation to finish.'
    }
})
try {
    if ($StartServer) {
        $widgets.Message.Text = 'Update installed. Starting server; migrations run before listening...'
        Begin-Work 'start'
    } else { Begin-Work 'check' }
    $timer.Start()
    $window.ShowDialog() | Out-Null
} finally { $timer.Stop(); $launcherLock.Dispose() }
if ($script:relaunch) {
    Start-Process powershell.exe -ArgumentList @('-WindowStyle', 'Hidden', '-NoLogo', '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', ('"' + (Join-Path $Root 'Bootstrap.ps1') + '"'), '-StartServer') | Out-Null
}
