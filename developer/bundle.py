"""Package source game, coding workshop and existing verified Windows Godot runtime."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
out = root / 'downloads/CosmoWrap-Atelier-Windows.zip'
with zipfile.ZipFile(root / 'downloads/CosmoWrap-Windows.zip') as original:
    runtime = next(original.read(name) for name in original.namelist() if name.endswith('/CosmoWrap.exe'))
    licenses = {Path(name).name: original.read(name) for name in original.namelist() if 'LICENSE' in name or 'COPYRIGHT' in name}
with zipfile.ZipFile(out.with_suffix('.tmp'), 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
    base = 'CosmoWrap-Atelier/'
    bundle.writestr(base + 'Godot.exe', runtime)
    for name, content in licenses.items():
        bundle.writestr(base + name, content)
    for filename, path in [('ATELIER-IA.cmd', 'atelier'), ('ATELIER-GROQ.cmd', 'atelier'), ('JOUER.cmd', 'game'), ('OUVRIR-GODOT.cmd', 'game')]:
        editor = ' --editor' if filename == 'OUVRIR-GODOT.cmd' else ''
        first_import = '"%~dp0Godot.exe" --headless --audio-driver Dummy --path "%~dp0game" --editor --quit\r\n' if filename == 'JOUER.cmd' else ''
        bundle.writestr(base + filename, f'@echo off\r\n{first_import}"%~dp0Godot.exe" --path "%~dp0{path}"{editor}\r\n'.encode())
    bundle.writestr(base + 'INSTALLER-MODELE.cmd', b'@echo off\r\nwhere ollama >nul 2>&1\r\nif errorlevel 1 (\r\n echo Installe Ollama pour Windows, puis relance ce fichier.\r\n start "" "https://ollama.com/download/windows"\r\n pause\r\n exit /b 1\r\n)\r\nollama pull qwen3:8b\r\nif errorlevel 1 (\r\n echo Telechargement echoue. Verifie que Ollama fonctionne et que Internet est disponible.\r\n) else (\r\n echo Modele installe. Ouvre ATELIER-IA.cmd et laisse Ollama selectionne.\r\n)\r\npause\r\n')
    for path in root.rglob('*'):
        if not path.is_file():
            continue
        parts = path.relative_to(root).parts
        if any(part.startswith('.') for part in parts) or parts[0] in {'downloads', 'build', 'developer'} or path.suffix == '.mp4':
            continue
        bundle.write(path, base + 'game/' + path.relative_to(root).as_posix())
    for name in ['project.godot', 'atelier.tscn', 'atelier.gd', 'atelier.gd.uid']:
        path = root / 'developer' / name
        if path.exists():
            bundle.write(path, base + 'atelier/' + name)
    bundle.writestr(base + 'LIRE-MOI.txt', '''COSMO WRAP - ATELIER IA v20 (OLLAMA LOCAL / GROQ)
1. Clic droit sur le ZIP > Extraire tout. Garder tous les dossiers ensemble.
2. Installer Ollama pour Windows : https://ollama.com/download/windows
3. Double-cliquer INSTALLER-MODELE.cmd pour telecharger qwen3:8b (environ 5 Go).
   Garder Ollama lance. Ouvrir ATELIER-IA.cmd : Ollama est selectionne par defaut, aucune cle requise.
   Groq reste une alternative dans le selecteur et utilise sa propre cle et ses quotas.
4. Decrire un changement et cliquer PREPARER. Plusieurs etapes IA peuvent etre necessaires (20 maximum).
   En cas de 429, attendre puis REESSAYER. La cle reste en memoire.
5. Lire les extraits AVANT / APRES dans la console, puis APPLIQUER + VERIFIER.
6. Si Godot trouve une erreur de script, les fichiers precedents sont restaures.
7. Fermer la partie precedente et cliquer LANCER LE JEU ou ouvrir JOUER.cmd.
ANNULER revient aux fichiers precedents pendant la session.
Les copies des fichiers sont dans game/.atelier-backups. Conserver le ZIP original pour restauration complete.
OUVRIR-GODOT.cmd ouvre le vrai projet source dans Godot pour modifier et exporter soi-meme.

Cet atelier est une application separee du jeu. Le createur de la Pokeball conserve ses reglages limites.
L'atelier peut modifier les scripts, menus, scenes, SVG et donnees texte, et creer de nouveaux fichiers texte.
Il ne genere pas de nouvelles images HD et ne transforme pas tout instantanement sans relancer.
La verification detecte les erreurs de scripts ; elle ne garantit pas le bon fonctionnement en jeu.
Les scripts generes peuvent executer du code sur le PC : examiner la proposition avant application.
Les operations d'edition de l'atelier sont limitees au dossier game ; ce n'est pas un bac a sable pour le code du jeu.
Ollama fonctionne localement sans cle ni quota API. Le modele n est pas inclus dans le ZIP.
Le premier chargement peut durer. Internet necessaire au telechargement initial du modele.
Groq reste soumis aux quotas du compte lorsque selectionne.
L'archive est verifiee ; le lancement sous Windows reste a tester sur votre PC.
'''.encode())
with zipfile.ZipFile(out.with_suffix('.tmp')) as check:
    assert check.testzip() is None
    assert check.read('CosmoWrap-Atelier/Godot.exe') == runtime
    assert 'CosmoWrap-Atelier/game/project.godot' in check.namelist()
    assert 'CosmoWrap-Atelier/atelier/atelier.gd' in check.namelist()
    assert not any('/.git/' in name or '/.godot/' in name for name in check.namelist())
out.with_suffix('.tmp').replace(out)
assert out.stat().st_size < 100 * 1024 * 1024
print(out.name, out.stat().st_size, 'bytes: source files, runtime and archive verified')

patch = root / 'downloads/CosmoWrap-Atelier-Correctif.zip'
with zipfile.ZipFile(patch.with_suffix('.tmp'), 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as update:
    for name in ['project.godot', 'atelier.tscn', 'atelier.gd', 'atelier.gd.uid']:
        path = root / 'developer' / name
        if path.exists():
            update.write(path, 'atelier/' + name)
    update.writestr('LIRE-MOI-CORRECTIF.txt', '''CORRECTIF ATELIER v20
1. Fermer l'atelier ouvert.
2. Extraire ce ZIP.
3. Copier le dossier atelier obtenu dans votre dossier CosmoWrap-Atelier,
   a cote de Godot.exe et du dossier game. Accepter de remplacer les fichiers.
4. Relancer ATELIER-IA.cmd. Le titre doit afficher ATELIER IA v20.
Le jeu, ses sources modifiees et le modele Ollama ne sont pas remplaces.
Ce correctif ajoute RELANCER LE JEU : fermeture avec sauvegarde puis redemarrage.
'''.encode())
with zipfile.ZipFile(patch.with_suffix('.tmp')) as update:
    assert update.testzip() is None
    assert update.read('atelier/atelier.gd') == (root / 'developer/atelier.gd').read_bytes()
patch.with_suffix('.tmp').replace(patch)
print(patch.name, patch.stat().st_size, 'bytes: workshop-only update verified')
