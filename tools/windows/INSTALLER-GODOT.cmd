@echo off
setlocal DisableDelayedExpansion
set "COSMO_RUNTIME=%~dp0.godot-runtime"
if not exist "%COSMO_RUNTIME%" mkdir "%COSMO_RUNTIME%"
if not exist "%COSMO_RUNTIME%" exit /b 1
if exist "%COSMO_RUNTIME%\installation-bloquee.txt" exit /b 1
set "COSMO_ARCHIVE=%COSMO_RUNTIME%\Godot-officiel.zip"
set "COSMO_STAGING=%COSMO_RUNTIME%\staging-%RANDOM%-%RANDOM%"
if exist "%COSMO_STAGING%" goto erreur
echo Premier lancement : telechargement officiel de Godot 4.6.3.
echo Une connexion Internet est necessaire seulement pour cette installation.
curl.exe --fail --location --proto =https --proto-redir =https --tlsv1.2 --connect-timeout 20 --max-time 240 --output "%COSMO_ARCHIVE%" "https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_win64.exe.zip"
if errorlevel 1 goto erreur
echo Verification de l'archive officielle...
certutil -hashfile "%COSMO_ARCHIVE%" SHA512 > "%COSMO_RUNTIME%\archive.sha512" 2>&1
if errorlevel 1 goto erreur
findstr /i /x /c:"d44ea7ef5bab754cacd49d581b6062836b2eea12a82e1d183aebfad9cd8c7db2bd82513337bd657d6d2d5c04d46239c0570b029faf1343e81e8a2fa7b85dd83b" "%COSMO_RUNTIME%\archive.sha512" >nul
if errorlevel 1 goto erreur
powershell.exe -NoProfile -Command "Expand-Archive -LiteralPath $env:COSMO_ARCHIVE -DestinationPath $env:COSMO_STAGING"
if errorlevel 1 goto erreur
copy /b "%COSMO_STAGING%\Godot_v4.6.3-stable_win64.exe" "%COSMO_RUNTIME%\Godot_v4.6.3-stable_win64.exe" >nul
if errorlevel 1 goto erreur
call "%~dp0VERIFIER-GODOT.cmd" "%COSMO_RUNTIME%\Godot_v4.6.3-stable_win64.exe"
if errorlevel 1 goto erreur
del "%COSMO_ARCHIVE%"
rmdir /s /q "%COSMO_STAGING%"
echo Installation verifiee. Lancement du jeu...
exit /b 0
:erreur
echo Installation arretee : telechargement, extraction ou verification en echec.
echo Ne desactive pas Defender. Ne restaure pas un fichier mis en quarantaine.
echo Copie le message affiche et le chemin signale pour diagnostiquer le probleme.
echo Installation arretee. Consulter les erreurs et l'historique de protection Windows. > "%COSMO_RUNTIME%\installation-bloquee.txt"
exit /b 1
