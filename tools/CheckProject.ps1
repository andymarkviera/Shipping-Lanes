#requires -Version 7.4
[CmdletBinding()]
param([switch]$Full)
$ErrorActionPreference = 'Stop'
$modes = @('Check','UnitsCheck','CatalogCheck','DiagnosticsCheck')
if ($Full) { $modes += @('ControlsCheck','FlowCheck','ContractsCheck','GeographyCheck','SessionCheck','ClocksCheck','AssetCheck','HandlingCheck','CameraCheck','WaterCheck','CollisionCheck','FeedbackCheck','WorldSizeCheck','HeavyLifterCheck','CompositionCheck','FuelCheck','NetworkCheck','ReplicationCheck','CargoNetworkCheck','ConnectedWorldCheck','CapacityCheck','ActionCheck','EconomyCheck','RecoveryCheck','PersistenceCheck') }
foreach ($mode in $modes) {
    & (Join-Path $PSScriptRoot 'Godot.ps1') -Mode $mode
}
Write-Host "PROJECT_CHECK_PASS ($($modes.Count) stages)"
