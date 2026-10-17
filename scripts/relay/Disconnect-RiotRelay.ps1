#Requires -RunAsAdministrator
# Removes the Riot relay tunnel; all traffic goes back to the normal line.
& "$env:ProgramFiles\WireGuard\wireguard.exe" /uninstalltunnelservice riot-relay
Write-Host "Relay tunnel removed." -ForegroundColor Green
