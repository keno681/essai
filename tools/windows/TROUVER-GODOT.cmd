@echo off
set "COSMO_GODOT=%~dp0.godot-runtime\Godot_v4.6.3-stable_win64.exe"
if exist "%~dp0.godot-runtime\installation-bloquee.txt" (
 echo Installation precedente bloquee. Voir .godot-runtime\installation-bloquee.txt.
 echo Ne restaure pas un fichier mis en quarantaine et ne desactive pas Defender.
 exit /b 1
)
if exist "%COSMO_GODOT%" goto verifier
call "%~dp0INSTALLER-GODOT.cmd"
if errorlevel 1 exit /b 1
:verifier
call "%~dp0VERIFIER-GODOT.cmd" "%COSMO_GODOT%"
if errorlevel 1 (
 echo Verification du moteur refusee. Aucun lancement.
 echo Moteur absent, bloque ou empreinte incorrecte. > "%~dp0.godot-runtime\installation-bloquee.txt"
 exit /b 1
)
exit /b 0
