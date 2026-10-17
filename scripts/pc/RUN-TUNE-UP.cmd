@echo off
rem Double-click this. Windows asks "Do you want to allow this app to make changes?" - click Yes.
rem A blue admin window then runs the tune-up and stays open; it writes tune-up-log.txt next to this file.
echo Requesting admin rights... click YES on the Windows prompt (check the taskbar if you don't see it).
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process powershell -Verb RunAs -ErrorAction Stop -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','\"%~dp0Optimize-Network.ps1\"' } catch { Write-Host ''; Write-Host 'Admin prompt was declined or blocked - nothing was changed.' -ForegroundColor Red }"
pause
