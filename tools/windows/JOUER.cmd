@echo off
setlocal DisableDelayedExpansion
cd /d "%~dp0"
call "%~dp0TROUVER-GODOT.cmd"
if errorlevel 1 (
 pause
 exit /b 1
)
"%COSMO_GODOT%" --headless --audio-driver Dummy --path "%~dp0launcher"
if errorlevel 1 pause
