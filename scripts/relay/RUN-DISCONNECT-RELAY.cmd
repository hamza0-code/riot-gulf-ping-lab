@echo off
rem Double-click to turn the Riot relay off (click YES on the admin prompt). Everything goes back to the normal line.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process powershell -Verb RunAs -ErrorAction Stop -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','\"%~dp0Disconnect-RiotRelay.ps1\"' } catch { Write-Host 'Admin prompt was declined - nothing was changed.' -ForegroundColor Red }"
pause
