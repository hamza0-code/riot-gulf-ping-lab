#Requires -RunAsAdministrator
# Restores everything Optimize-Network.ps1 changed, from network-backup.json.

$Backup = Join-Path $PSScriptRoot 'network-backup.json'
$MMCSS  = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
if (-not (Test-Path $Backup)) { Write-Error "No backup found at $Backup"; exit 1 }
$b = Get-Content $Backup -Raw | ConvertFrom-Json

$current = Get-NetAdapterAdvancedProperty -Name $b.Adapter
foreach ($p in $b.AdvancedProps) {
    if (-not $p.RegistryKeyword -or $null -eq $p.RegistryValue) { continue }
    $now = $current | Where-Object RegistryKeyword -eq $p.RegistryKeyword
    if (-not $now -or (@($now.RegistryValue) -join ',') -eq (@($p.RegistryValue) -join ',')) { continue }
    Set-NetAdapterAdvancedProperty -Name $b.Adapter -RegistryKeyword $p.RegistryKeyword -RegistryValue $p.RegistryValue -NoRestart
    Write-Host "  restored $($p.DisplayName)"
}
if ($b.DevKey) {
    if ($null -eq $b.PnPCapabilities) { Remove-ItemProperty $b.DevKey -Name PnPCapabilities -ErrorAction SilentlyContinue }
    else { Set-ItemProperty $b.DevKey -Name PnPCapabilities -Type DWord -Value ([uint32]$b.PnPCapabilities) }
    Write-Host "  restored adapter power management"
}
if ($b.PowerScheme) { powercfg /setactive $b.PowerScheme; Write-Host "  restored power plan" }
if ($null -ne $b.NetworkThrottlingIndex) { Set-ItemProperty $MMCSS -Name NetworkThrottlingIndex -Type DWord -Value ([uint32]$b.NetworkThrottlingIndex) }
if ($null -ne $b.SystemResponsiveness)   { Set-ItemProperty $MMCSS -Name SystemResponsiveness   -Type DWord -Value ([uint32]$b.SystemResponsiveness) }
Write-Host "  restored multimedia scheduler values"

Restart-NetAdapter -Name $b.Adapter
Write-Host "Reverted. Reboot to finish." -ForegroundColor Green
