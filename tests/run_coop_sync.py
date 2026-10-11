"""Exercise two real supervisors, including coordinated restart and failure rollback."""
from pathlib import Path
import subprocess, tempfile, os, time, signal, json, sys
root=Path(__file__).resolve().parents[1]
allowed={'.gd','.godot','.tscn','.tres','.json','.svg','.png','.wav','.cfg','.gdshader','.uid'}
skip={'downloads','build','developer','tools','tests','launcher'}
modes=[(False,False,True)] if "--seeds-only" in sys.argv else [(False,False,False),(True,False,False),(False,True,False),(False,False,True)]
for failure,drinks,seeds in modes:
 fixture=Path(tempfile.mkdtemp(prefix='cosmo-sync-e2e-'))
 children=[]; handles=[]
 try:
  for role in ['host','guest']:
   pack=fixture/role
   for src in root.rglob('*'):
    rel=src.relative_to(root)
    if not src.is_file() or rel.parts[0] in skip or any(x.startswith('.') for x in rel.parts) or src.suffix not in allowed: continue
    dst=pack/'game'/rel; dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(src.read_bytes())
   updates=[]
   if drinks or seeds: updates.extend(['Recolte-Directe-Pokeball.json','Tickets-Comptoir-Pokeball.json','Tables-Commandes-Pokeball.json','Cuisine-Definitive-Pokeball.json','Commande-Furie-Pokeball.json','Graines-Pokeball.json'])
   if drinks: updates.append('Ingredients-Boissons-Pokeball.json')
   for name in updates:
    update=json.loads((root/'downloads'/name).read_text())
    for operation in reversed(update['files']):
     dst=pack/'game'/operation['path']
     if 'create' in operation: dst.unlink()
     else:
      text=dst.read_text();assert text.count(operation['new'])==1
      dst.write_text(text.replace(operation['new'],operation['old']))
   for src in (root/'launcher').glob('*'):
    if src.is_file():
     dst=pack/'launcher'/src.name;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_bytes(src.read_bytes())
   (pack/'launcher'/'coop_sync_node.gd').write_text((root/'tests/coop_sync_supervisor.gd').read_text())
   p=pack/'launcher'/'launcher.tscn';p.write_text(p.read_text().replace('path="res://launcher.gd"','path="res://coop_sync_node.gd"'))
   env=dict(os.environ)
   for key in ['XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME']: env[key]=str(fixture/role/key.lower())
   log=open(fixture/(role+'.log'),'w');handles.append(log)
   cmd=['godot','--headless','--audio-driver','Dummy','--path',str(pack/'launcher'),'--','--role='+role,'--shared='+str(fixture),'--test-root='+str(root)]
   if failure: cmd+=['--fail-apply']
   if drinks: cmd+=['--drinks']
   if seeds: cmd+=['--seeds']
   children.append(subprocess.Popen(cmd,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True))
   if role=='host': time.sleep(.3)
  deadline=time.monotonic()+160
  while any(p.poll() is None for p in children) and time.monotonic()<deadline:
   for role in ['host','guest']:
    logfile=fixture/(role+'.log')
    if logfile.exists() and 'SCRIPT ERROR' in logfile.read_text(): raise AssertionError(logfile.read_text()[-4000:])
   time.sleep(.1)
  for h in handles: h.flush()
  assert all(p.poll()==0 for p in children),f'Process failures: {fixture}'
  assert (fixture/'host-done').exists() and (fixture/'guest-done').exists(),f'Reconnection incomplete: {fixture}'
  for role in ['host','guest']:
   text=(fixture/(role+'.log')).read_text()
   assert 'SCRIPT ERROR' not in text and 'PASS sync '+role in text,text[-5000:]
  print('PASS: two real launchers, '+('both files rolled back' if failure else 'full seeds update transmitted and applied' if seeds else 'full drinks update transmitted and applied' if drinks else 'both files updated')+', reconnect, inventories and solo save restored',flush=True)
 finally:
  for p in children:
   if p.poll() is None:
    os.killpg(p.pid,signal.SIGTERM)
    try:p.wait(timeout=5)
    except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL)
  for entry in Path('/proc').iterdir():
   if not entry.name.isdigit():continue
   try:args=(entry/'cmdline').read_bytes().decode().split('\0')
   except (OSError,UnicodeError):continue
   if args and 'godot' in Path(args[0]).name.lower() and ('--shared='+str(fixture)) in args:
    try:os.kill(int(entry.name),signal.SIGTERM)
    except ProcessLookupError:pass
  for h in handles:h.close()
