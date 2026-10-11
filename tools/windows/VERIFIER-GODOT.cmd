@echo off
setlocal DisableDelayedExpansion
if not exist "%~1" exit /b 1
certutil -hashfile "%~1" SHA256 > "%~dp0.godot-runtime\executable.sha256" 2>&1
if errorlevel 1 exit /b 1
findstr /i /x /c:"ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00" "%~dp0.godot-runtime\executable.sha256" >nul
if errorlevel 1 exit /b 1
exit /b 0
