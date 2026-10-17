#Requires -RunAsAdministrator
# Low-latency tuning for the Realtek PCIe Ethernet adapter + Windows.
# Saves the current state to network-backup.json first; undo with Revert-Network.ps1.

Start-Transcript -Path (Join-Path $PSScriptRoot 'tune-up-log.txt') -Append | Out-Null

$Adapter = 'Ethernet'
$Backup  = Join-Path $PSScriptRoot 'network-backup.json'
$MMCSS   = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'

if (-not (Get-NetAdapter -Name $Adapter -ErrorAction SilentlyContinue)) {
    Write-Error "Adapter '$Adapter' not found. Edit `$Adapter at the top of this script."; exit 1
}

# The adapter's driver key; PnPCapabilities=24 there unticks "Allow the computer to turn off this device".
# (Disable-NetAdapterPowerManagement fails with error 31 on the Realtek inbox driver, so set it directly.)
$Guid   = (Get-NetAdapter -Name $Adapter).InterfaceGuid
$DevKey = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue |
          Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).NetCfgInstanceId -eq $Guid } |
          Select-Object -First 1 -ExpandProperty PSPath

# ---------- 1. Backup (only the first time, so re-running never overwrites the original state) ----------
if (-not (Test-Path $Backup)) {
    $mm = Get-ItemProperty $MMCSS
    [ordered]@{
        Adapter       = $Adapter
        AdvancedProps = @(Get-NetAdapterAdvancedProperty -Name $Adapter |
                          Select-Object DisplayName, RegistryKeyword, @{n='RegistryValue';e={@($_.RegistryValue)}})
        DevKey        = $DevKey
        PnPCapabilities = if ($DevKey) { (Get-ItemProperty $DevKey).PnPCapabilities } else { $null }
        PowerScheme   = ([regex]::Match((powercfg /getactivescheme), '[0-9a-f-]{36}')).Value
        NetworkThrottlingIndex = $mm.NetworkThrottlingIndex
        SystemResponsiveness   = $mm.SystemResponsiveness
    } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 $Backup
    Write-Host "Backup saved to $Backup" -ForegroundColor Green
} else {
    Write-Host "Backup already exists, keeping the original: $Backup" -ForegroundColor Yellow
}

# ---------- 2. Adapter: turn off everything that trades latency for power or throughput ----------
# Names cover the Realtek inbox driver and the newer Realtek NetAdapterCx driver; missing ones are skipped.
$want = [ordered]@{
    'Interrupt Moderation'      = 'Disabled'   # deliver each packet immediately instead of batching interrupts
    'Power Saving Mode'         = 'Disabled'
    'Energy-Efficient Ethernet' = 'Disabled'   # EEE puts the link to sleep between packets
    'Advanced EEE'              = 'Disabled'
    'Green Ethernet'            = 'Disabled'
    'Gigabit Lite'              = 'Disabled'
    'Auto Disable Gigabit'      = 'Disabled'
    'Flow Control'              = 'Disabled'   # pause frames can stall the queue for a few ms
}
$present = Get-NetAdapterAdvancedProperty -Name $Adapter
foreach ($name in $want.Keys) {
    $p = $present | Where-Object DisplayName -eq $name
    if (-not $p) { Write-Host "  skip  $name (not exposed by this driver)" -ForegroundColor DarkGray; continue }
    if ($p.DisplayValue -eq $want[$name]) { Write-Host "  ok    $name already $($want[$name])"; continue }
    try {
        Set-NetAdapterAdvancedProperty -Name $Adapter -DisplayName $name -DisplayValue $want[$name] -NoRestart -ErrorAction Stop
        Write-Host "  set   $name -> $($want[$name])" -ForegroundColor Cyan
    } catch { Write-Host "  fail  $name : $($_.Exception.Message)" -ForegroundColor Red }
}

# "Allow the computer to turn off this device to save power" -> off
if ($DevKey) {
    Set-ItemProperty $DevKey -Name PnPCapabilities -Type DWord -Value 24
    Write-Host "  set   Allow Windows to turn off adapter -> off (after reboot)" -ForegroundColor Cyan
} else { Write-Host "  fail  Adapter registry key not found; power management left as is" -ForegroundColor Red }

# ---------- 3. Power plan: stop CPU/PCIe from napping between packets ----------
$ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
$plans = powercfg /list
$existing = [regex]::Match([string]($plans | Select-String 'Ultimate Performance' | Select-Object -First 1), '[0-9a-f-]{36}').Value
if (-not $existing) { $existing = [regex]::Match((powercfg -duplicatescheme $ultimate), '[0-9a-f-]{36}').Value }
if (-not $existing) { $existing = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }   # High performance fallback
powercfg /setactive $existing
# PCI Express Link State Power Management -> Off on this plan
powercfg /setacvalueindex $existing 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0
powercfg /setactive $existing
Write-Host "  set   Power plan -> $((powercfg /getactivescheme) -replace '.*\((.*)\).*','$1'), PCIe link power saving off" -ForegroundColor Cyan

# ---------- 4. Windows multimedia scheduler: no network throttling while a game/audio stream runs ----------
Set-ItemProperty $MMCSS -Name NetworkThrottlingIndex -Type DWord -Value 0xFFFFFFFF
Set-ItemProperty $MMCSS -Name SystemResponsiveness   -Type DWord -Value 10
Write-Host "  set   NetworkThrottlingIndex -> off, SystemResponsiveness -> 10" -ForegroundColor Cyan

# ---------- 5. Apply ----------
Write-Host "`nRestarting the adapter (internet drops for ~5 seconds)..." -ForegroundColor Yellow
Restart-NetAdapter -Name $Adapter
Start-Sleep 8
Get-NetAdapterAdvancedProperty -Name $Adapter | Format-Table DisplayName, DisplayValue -AutoSize
Write-Host "Done. Reboot now so every change takes effect." -ForegroundColor Green
Stop-Transcript | Out-Null
