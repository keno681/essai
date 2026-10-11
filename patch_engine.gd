extends RefCounted
const FORMAT="cosmowrap-patch-v1"
const EXTENSIONS=["gd","gdshader","tscn","tres","godot","json","cfg","svg","md","txt"]
var root_path: String
var error := ""

func path_for(relative: String) -> String:
	if relative.is_empty() or relative.is_absolute_path() or ":" in relative or "\\" in relative: return ""
	var parent=root_path
	for part in relative.split("/"):
		if part.is_empty() or part.begins_with(".") or part in ["downloads","build","launcher","tests"]: return ""
		var dir=DirAccess.open(parent)
		if dir and dir.is_link(part): return ""
		parent+="/"+part
	if relative.get_extension() not in EXTENSIONS: return ""
	return parent

func prepare(words: String) -> Dictionary:
	error=""
	words=words.strip_edges()
	if words.begins_with("```"):
		var newline=words.find("\n")
		if newline>=0 and words.ends_with("```"): words=words.substr(newline+1,words.length()-newline-4).strip_edges()
	var parser=JSON.new()
	if words.length()>2000000 or parser.parse(words)!=OK or not parser.data is Dictionary:
		error="Colle le bloc de modification fourni dans la conversation, pas une demande en langage naturel."
		return {}
	var patch: Dictionary=parser.data
	if patch.get("format")!=FORMAT or not patch.get("files") is Array or patch.files.is_empty() or patch.files.size()>30:
		error="Bloc non reconnu : format cosmowrap-patch-v1 attendu (1 à 30 opérations)."
		return {}
	var before: Dictionary={}
	var after: Dictionary={}
	for operation in patch.files:
		if not operation is Dictionary or not operation.get("path") is String:
			error="Chemin de fichier manquant."; return {}
		var relative: String=operation.path
		var path=path_for(relative)
		if path.is_empty(): error="Chemin ou format interdit : "+relative; return {}
		if not before.has(relative):
			var exists=FileAccess.file_exists(path)
			if exists and FileAccess.get_file_as_bytes(path).size()>2000000: error="Fichier trop grand : "+relative; return {}
			var text=FileAccess.get_file_as_string(path) if exists else ""
			before[relative]={"exists":exists,"text":text}
			after[relative]=text
		if operation.has("create"):
			if before[relative].exists or not operation.create is String: error="Le fichier existe déjà ou contenu invalide : "+relative; return {}
			after[relative]=operation.create
		else:
			if not operation.get("old") is String or not operation.get("new") is String or operation.old.is_empty(): error="Remplacement incomplet : "+relative; return {}
			if not before[relative].exists and after[relative].is_empty(): error="Fichier absent : "+relative; return {}
			if after[relative].count(operation.old)!=1: error="Version différente : texte absent ou non unique dans "+relative; return {}
			after[relative]=after[relative].replace(operation.old,operation.new)
	return {"title":str(patch.get("title","Modification du jeu")).left(120),"before":before,"after":after}

func write_map(files: Dictionary, restore: bool=false) -> bool:
	for relative in files:
		var path=path_for(relative)
		if path.is_empty(): return false
		if restore and not files[relative].exists:
			if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK: return false
			continue
		if DirAccess.make_dir_recursive_absolute(path.get_base_dir())!=OK: return false
		var file=FileAccess.open(path,FileAccess.WRITE)
		if not file: return false
		file.store_string(files[relative].text if restore else files[relative])
		file.close()
	return true

func apply(transaction: Dictionary, executable: String) -> bool:
	error=""
	for relative in transaction.before:
		var path=path_for(relative)
		if path.is_empty() or FileAccess.file_exists(path)!=transaction.before[relative].exists or (transaction.before[relative].exists and FileAccess.get_file_as_string(path)!=transaction.before[relative].text):
			error="Fichiers modifiés depuis l’aperçu : "+relative; return false
	var backup_path=root_path+"/.console-backups/"+str(Time.get_unix_time_from_system()).replace(".","-")+".json"
	DirAccess.make_dir_recursive_absolute(backup_path.get_base_dir())
	var backup=FileAccess.open(backup_path,FileAccess.WRITE)
	if not backup: error="Sauvegarde des fichiers impossible."; return false
	backup.store_string(JSON.stringify(transaction)); backup.close()
	if not write_map(transaction.after):
		write_map(transaction.before,true); DirAccess.rename_absolute(backup_path,backup_path+".rejected"); error="Écriture impossible ; fichiers restaurés."; return false
	var logs: Array=[]
	var code=OS.execute(executable,["--headless","--audio-driver","Dummy","--path",root_path,"--editor","--quit"],logs,true)
	for relative in transaction.after:
		if relative.get_extension()!="gd": continue
		var output: Array=[]
		var result=OS.execute(executable,["--headless","--audio-driver","Dummy","--path",root_path,"--check-only","--script",path_for(relative)],output,true)
		logs.append_array(output)
		if result!=0: code=result
	var startup: Array=[]
	var startup_code=OS.execute(executable,["--headless","--audio-driver","Dummy","--path",root_path,"--quit-after","5"],startup,true)
	logs.append_array(startup)
	if startup_code!=0: code=startup_code
	var text="\n".join(logs)
	if code!=0 or "SCRIPT ERROR" in text or "Parse Error" in text or "Failed to load script" in text:
		var restored=write_map(transaction.before,true)
		DirAccess.rename_absolute(backup_path,backup_path+".rejected")
		error="Vérification refusée. Fichiers restaurés : "+str(restored)+"\n"+text.right(1800)
		return false
	return true

func undo_latest() -> bool:
	var dir=DirAccess.open(root_path+"/.console-backups")
	if not dir: error="Aucune modification à annuler."; return false
	var files=dir.get_files()
	files.sort()
	for i in range(files.size()-1,-1,-1):
		if not files[i].ends_with(".json"): continue
		var path=root_path+"/.console-backups/"+files[i]
		var data=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or not data.get("before") is Dictionary or not data.get("after") is Dictionary: continue
		for relative in data.after:
			if path_for(relative).is_empty() or FileAccess.get_file_as_string(path_for(relative))!=data.after[relative]: error="Les fichiers ont changé depuis cette modification. Annulation refusée pour préserver tes changements."; return false
		if not write_map(data.before,true): error="Restauration impossible."; return false
		DirAccess.rename_absolute(path,path+".undone")
		return true
	error="Aucune modification à annuler."; return false
