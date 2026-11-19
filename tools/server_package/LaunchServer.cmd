@echo off
start "" powershell.exe -WindowStyle Hidden -NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Bootstrap.ps1"
