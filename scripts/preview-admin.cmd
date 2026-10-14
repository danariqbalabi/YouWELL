@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-web.ps1" -Target admin -Port 8081
exit /b %ERRORLEVEL%
