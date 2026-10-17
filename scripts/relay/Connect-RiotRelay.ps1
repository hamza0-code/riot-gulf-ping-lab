#Requires -RunAsAdministrator
# Fetches the tunnel config from your relay, installs WireGuard if needed, and routes ONLY Riot traffic through it.
#   .\Connect-RiotRelay.ps1 -RelayIP 1.2.3.4 -SshKey C:\path\to\ssh-key.key
param(
    [Parameter(Mandatory)][string]$RelayIP,
    [Parameter(Mandatory)][string]$SshKey,
    [string]$User = 'ubuntu',
    # Local UDP port for the tunnel. The Dubai->Riyadh link into Oracle Riyadh balances flows across a ~53 ms
    # and a ~77 ms path by port; 40017 was fastest in the original test. Find yours with ..\tools\Find-FastPort.ps1.
    [int]$ListenPort = 40017
)

$Name = 'riot-relay'
$Conf = Join-Path $PSScriptRoot "$Name.conf"
$Wg   = "$env:ProgramFiles\WireGuard\wireguard.exe"

# Windows ssh rejects keys other accounts can read, so use a locked-down copy next to this script
$Key = Join-Path $PSScriptRoot 'relay.key'
Copy-Item -LiteralPath $SshKey $Key -Force
icacls $Key /inheritance:r /grant:r "$($env:USERNAME):(R)" | Out-Null

$ssh  = @('-i', $Key, '-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=10', "$User@$RelayIP")

# 1. WireGuard client (official package via winget)
if (-not (Test-Path $Wg)) {
    Write-Host "Installing WireGuard..." -ForegroundColor Yellow
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id WireGuard.WireGuard -e
    } else {
        # Official installer from wireguard.com; it fetches and verifies the signed MSI itself
        $inst = Join-Path $env:TEMP 'wireguard-installer.exe'
        Invoke-WebRequest -UseBasicParsing 'https://download.wireguard.com/windows-client/wireguard-installer.exe' -OutFile $inst
        if ((Get-AuthenticodeSignature $inst).Status -ne 'Valid') { Write-Error "Installer signature invalid; not running it."; exit 1 }
        Start-Process $inst -Wait
        Get-Process wireguard -ErrorAction SilentlyContinue | Stop-Process   # installer opens the GUI; the service is all we need
    }
    if (-not (Test-Path $Wg)) { Write-Error "WireGuard install failed; install it from wireguard.com and re-run."; exit 1 }
}

# 2. Wait for the relay's first-boot setup to finish, then pull the config
Write-Host "Waiting for relay setup to finish (first boot takes 2-4 minutes)..." -ForegroundColor Yellow
for ($i = 0; $i -lt 40; $i++) {
    $ready = ssh @ssh 'sudo cat /etc/wireguard/ready 2>/dev/null' 2>$null
    if ($ready -match 'ready') { break }
    Start-Sleep 10
}
if ($ready -notmatch 'ready') { Write-Error "Relay never reported ready. Check the Cloud-init script was pasted and UDP 51820 is open."; exit 1 }
$text = ssh @ssh 'sudo cat /etc/wireguard/client.conf'
$text = $text -replace '^\[Interface\]$', "[Interface]`r`nListenPort = $ListenPort"
$text -join "`r`n" | Set-Content -Encoding ascii $Conf     # WireGuard can't read the UTF-16 PowerShell 5 writes by default

# 3. (Re)install the tunnel as a Windows service so it survives reboots
& $Wg /uninstalltunnelservice $Name 2>$null; Start-Sleep 2
& $Wg /installtunnelservice $Conf
Start-Sleep 5

# 4. Measure through the tunnel
$t = ping -n 20 10.66.0.1 | Select-String 'time[=<](\d+)ms' | ForEach-Object { [int]$_.Matches[0].Groups[1].Value } | Sort-Object
if (-not $t) { Write-Error "No reply through the tunnel. Open UDP 51820 in the cloud firewall / security list."; exit 1 }
$pcToRelay = $t[[int]($t.Count / 2)]
Write-Host ""
Write-Host "PC -> relay (through tunnel): $pcToRelay ms (min $($t[0]))"
Write-Host "Without relay, VALORANT's Riyadh ping was 61 ms." -ForegroundColor Cyan
Write-Host ""
Write-Host "Tunnel is ON. Play a match, then run ..\Check-ValorantPing.ps1 for Valorant's own number."
Write-Host "If it's not lower, turn it off with .\Disconnect-RiotRelay.ps1"

