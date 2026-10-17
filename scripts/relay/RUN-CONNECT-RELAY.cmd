@echo off
rem Edit the two lines below, then double-click this file and click YES on the Windows admin prompt.
rem Installs WireGuard if needed and routes ONLY Riot Games traffic through your relay.
set RELAY_IP=203.0.113.10
set SSH_KEY=C:\path\to\your-ssh-key.key
set RELAY_USER=ubuntu

echo Requesting admin rights... click YES on the Windows prompt (check the taskbar if you don't see it).
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process powershell -Verb RunAs -ErrorAction Stop -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','\"%~dp0Connect-RiotRelay.ps1\"','-RelayIP','%RELAY_IP%','-SshKey','\"%SSH_KEY%\"','-User','%RELAY_USER%' } catch { Write-Host ''; Write-Host 'Admin prompt was declined or blocked - nothing was changed.' -ForegroundColor Red }"
pause
