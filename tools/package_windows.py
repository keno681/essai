"""Create the Windows source pack with a supplied official Godot runtime."""
from pathlib import Path
import argparse, zipfile
parser=argparse.ArgumentParser()
parser.add_argument('--runtime',type=Path,required=True)
parser.add_argument('--license-dir',type=Path,required=True)
parser.add_argument('--preview',type=Path)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
# Old screenshots, demonstration video and legacy menu mockups are not game assets.
unused_art={'clients-demo.mp4','gameplay.png','garden-gameplay.png','office-gameplay.png','planet-gameplay.png','inventory.png','menu.png','options.png','races-demo.png','save.png','shop.png'}
readme=(root/'README.md').read_text()
(root/'downloads').mkdir(exist_ok=True)
with zipfile.ZipFile(root/'downloads/CosmoWrapBall.zip','w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 base='CosmoWrapBall/'
 z.write(args.runtime,base+'Godot.exe')
 for name in ['GODOT-LICENSE.txt','GODOT-COPYRIGHT.txt']: z.write(args.license_dir/name,base+name)
 z.writestr(base+'JOUER.cmd','@echo off\r\ncd /d "%~dp0"\r\n"%~dp0Godot.exe" --headless --audio-driver Dummy --path "%~dp0launcher"\r\nif errorlevel 1 pause\r\n')
 z.writestr(base+'OUVRIR-EDITEUR.cmd','@echo off\r\n"%~dp0Godot.exe" --path "%~dp0game" --editor\r\n')
 z.writestr(base+'LIRE-MOI.txt',readme)
 for p in root.rglob('*'):
  rel=p.relative_to(root)
  if not p.is_file() or any(a.startswith('.') for a in rel.parts): continue
  if rel.parts[0] in ['downloads','build','developer','tools','tests','launcher']: continue
  if rel.parts[0]=='art' and (p.name in unused_art or p.name.removesuffix('.import') in unused_art): continue
  if p.suffix not in ['.gd','.uid','.godot','.tscn','.tres','.json','.svg','.png','.wav','.md','.txt','.cfg','.gdshader']: continue
  z.write(p,base+'game/'+rel.as_posix())
 for p in (root/'launcher').rglob('*'):
  if p.is_file() and not any(a.startswith('.') for a in p.relative_to(root/'launcher').parts): z.write(p,base+'launcher/'+p.relative_to(root/'launcher').as_posix())
 if args.preview: z.write(args.preview,base+'APERCU-CONSOLE.png')
with zipfile.ZipFile(root/'downloads/CosmoWrapBall.zip') as z:
 assert z.testzip() is None
 assert not any('/developer/' in n or 'creator.gd' in n for n in z.namelist())
 assert [n for n in z.namelist() if n.lower().endswith('.exe')]==[base+'Godot.exe']
 assert (root/'downloads/CosmoWrapBall.zip').stat().st_size < 100*1024*1024, 'ZIP exceeds the GitHub file limit'
print('ZIP verified:',(root/'downloads/CosmoWrapBall.zip').stat().st_size)
