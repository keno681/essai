@echo off
set "COSMO_GODOT="
for %%G in ("%~dp0Godot_v*-stable_win64.exe") do if exist "%%~fG" if not defined COSMO_GODOT set "COSMO_GODOT=%%~fG"
if defined COSMO_GODOT exit /b 0
echo.
echo Godot n'est pas fourni dans ce pack.
echo Telecharge la version Windows standard x64 depuis :
echo https://godotengine.org/download/windows/
echo Extrais son ZIP et place Godot_v...-stable_win64.exe ici,
echo a cote de JOUER.cmd, sans le renommer.
echo Ne restaure pas l'ancien fichier signale par l'antivirus.
echo Si Defender signale le nouveau fichier, ne le lance pas.
echo.
exit /b 1
