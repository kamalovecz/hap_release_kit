@echo off
cd /d "%~dp0"
echo ============================================
echo  hap_release_kit - Sign + Install HAP
echo  Usage: this file [hap-filename]
echo  Default: input\ClashBox_LTS_V1_unsigned.hap
echo ============================================
set "HAP=%~1"
if "%HAP%"=="" set "HAP=input\ClashBox_LTS_V1_unsigned.hap"
powershell -NoProfile -ExecutionPolicy Bypass -File "scripts\build-hap.ps1" -HapPath "%HAP%" -Install -Replace
echo.
echo ExitCode: %ERRORLEVEL%
pause
