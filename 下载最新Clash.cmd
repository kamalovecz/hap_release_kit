@echo off
cd /d "%~dp0"
echo ============================================
echo  Download latest ClashBox/ClashNext unsigned HAP
echo  into input\ directory
echo ============================================
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\download-clash.ps1"
echo.
echo ExitCode: %ERRORLEVEL%
pause
