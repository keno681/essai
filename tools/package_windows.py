"""Build the editable Windows game pack without distributing a runtime executable."""
from pathlib import Path
import argparse
import hashlib
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--preview', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
unused_art = {
    'clients-demo.mp4', 'gameplay.png', 'garden-gameplay.png', 'office-gameplay.png',
    'planet-gameplay.png', 'inventory.png', 'menu.png', 'options.png', 'save.png', 'shop.png',
}
allowed = {'.gd', '.uid', '.godot', '.tscn', '.tres', '.json', '.svg', '.png', '.wav', '.cfg', '.gdshader'}
output = root / 'downloads' / 'CosmoWrapBall-Sources.zip'
output.parent.mkdir(exist_ok=True)
base = 'CosmoWrapBall/'
with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
    for name in ['JOUER.cmd', 'OUVRIR-EDITEUR.cmd', 'TROUVER-GODOT.cmd', 'INSTALLER-GODOT.cmd', 'VERIFIER-GODOT.cmd']:
        text = (root / 'tools' / 'windows' / name).read_text()
        z.writestr(base + name, text.replace('\r\n', '\n').replace('\n', '\r\n'))
    z.writestr(base + 'LIRE-MOI.txt', (root / 'README.md').read_text())
    z.writestr(base + 'SECURITE.txt', (root / 'SECURITE.md').read_text())
    for p in sorted(root.rglob('*')):
        rel = p.relative_to(root)
        if not p.is_file() or any(part.startswith('.') for part in rel.parts):
            continue
        if rel.parts[0] in {'downloads', 'build', 'developer', 'tools', 'tests', 'launcher'}:
            continue
        if p.suffix not in allowed or (rel.parts[0] == 'art' and p.name in unused_art):
            continue
        z.write(p, base + 'game/' + rel.as_posix())
    for p in sorted((root / 'launcher').rglob('*')):
        rel = p.relative_to(root / 'launcher')
        if p.is_file() and not any(part.startswith('.') for part in rel.parts) and p.suffix in allowed:
            z.write(p, base + 'launcher/' + rel.as_posix())
    if args.preview:
        if args.preview.suffix.lower() != '.png':
            parser.error('--preview must be a PNG image')
        z.write(args.preview, base + 'APERCU-CONSOLE.png')
with zipfile.ZipFile(output) as z:
    assert z.testzip() is None
    assert not any(Path(n).suffix.lower() in {'.exe', '.dll', '.msi', '.pck'} for n in z.namelist())
    assert not any('/.console-' in n or '/.godot/' in n for n in z.namelist())
digest = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix('.sha256').write_text(f'{digest}  {output.name}\n')
print(f'Pack verified: {output.name}, {output.stat().st_size} bytes, no bundled executable')
