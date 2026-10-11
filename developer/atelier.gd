extends Control

const ENDPOINT="https://api.groq.com/openai/v1/chat/completions"
const EXTENSIONS=["gd","tscn","tres","godot","json","cfg","svg","md","txt"]
var provider := "ollama"
var provider_select: OptionButton
var provider_models := {"ollama":"qwen3:8b","groq":"openai/gpt-oss-20b"}
var tool_names: Dictionary={}
var game_root: String
var key_input: LineEdit
var model_input: LineEdit
var prompt: TextEdit
var console: TextEdit
var http: HTTPRequest
var messages: Array=[]
var staged: Dictionary={}
var baseline: Dictionary={}
var undo_files: Dictionary={}
var steps:=0
var requests_sent:=0
var format_retries:=0
var loading_models:=false
var running:=false
var validating:=false
var worker: Thread
var controls: Array[Button]=[]

func _ready() -> void:
	game_root=ProjectSettings.globalize_path("res://../game").simplify_path()
	var margin:=MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	add_child(margin)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	margin.add_child(box)
	var title:=Label.new()
	title.text="ATELIER IA v17 · OLLAMA LOCAL / GROQ"
	title.add_theme_font_size_override("font_size",24)
	box.add_child(title)
	var note:=Label.new()
	note.text="Clé en mémoire. Aperçu avant écriture. Sauvegarde des fichiers. Relancer le jeu après modification."
	box.add_child(note)
	provider_select=OptionButton.new()
	provider_select.add_item("Ollama · local · sans clé ni quota")
	provider_select.add_item("Groq · API")
	provider_select.item_selected.connect(func(index):
		if running or validating:
			provider_select.selected=0 if provider=="ollama" else 1
			return
		provider_models[provider]=model_input.text
		provider="ollama" if index==0 else "groq"
		model_input.text=provider_models[provider]
		key_input.editable=provider=="groq"
		messages.clear()
		staged.clear()
		baseline.clear()
		tool_names.clear()
		log_message("Fournisseur : "+provider+". Recommence la demande."))
	box.add_child(provider_select)
	key_input=LineEdit.new()
	key_input.secret=true
	key_input.editable=false
	key_input.placeholder_text="Clé Groq seulement — inutile avec Ollama"
	key_input.text=OS.get_environment("GROQ_API_KEY")
	box.add_child(key_input)
	model_input=LineEdit.new()
	model_input.text="qwen3:8b"
	box.add_child(model_input)
	make_button(box,"CHARGER LES MODÈLES DISPONIBLES",load_models)
	prompt=TextEdit.new()
	prompt.custom_minimum_size.y=90
	prompt.placeholder_text="Ex. : remplace les cadres de survol par une lueur cyan animée."
	box.add_child(prompt)
	var row:=HBoxContainer.new()
	box.add_child(row)
	make_button(row,"PRÉPARER",prepare)
	make_button(row,"RÉESSAYER",retry)
	make_button(row,"APPLIQUER + VÉRIFIER",apply_changes)
	make_button(row,"ANNULER",undo)
	make_button(row,"LANCER LE JEU",launch_game)
	make_button(row,"OUVRIR GODOT",open_editor)
	console=TextEdit.new()
	console.editable=false
	console.size_flags_vertical=Control.SIZE_EXPAND_FILL
	box.add_child(console)
	http=HTTPRequest.new()
	http.timeout=240
	add_child(http)
	http.request_completed.connect(received)
	log_message("Projet : "+game_root+"\nLes scripts peuvent exécuter du code sur ton PC. Examine les changements proposés avant de les appliquer.\nL'atelier ne crée pas de nouvelles images HD ; il peut créer des SVG et modifier tous les fichiers texte du jeu.")
	if not FileAccess.file_exists(game_root+"/project.godot"): log_message("ERREUR : dossier game absent. Extrais tout le pack avant de lancer l'atelier.")

func make_button(row: Node, title: String, action: Callable) -> void:
	var button:=Button.new()
	button.text=title
	button.pressed.connect(action)
	row.add_child(button)
	controls.append(button)

func log_message(words: String) -> void:
	if not key_input.text.is_empty(): words=words.replace(key_input.text,"[clé masquée]")
	if not key_input.text.strip_edges().is_empty(): words=words.replace(key_input.text.strip_edges(),"[clé masquée]")
	console.text+="\n"+words+"\n"
	console.set_caret_line(console.get_line_count()-1)

func safe_path(relative: String) -> String:
	if relative.is_empty() or relative.is_absolute_path() or ":" in relative or "\\" in relative: return ""
	for part in relative.split("/"):
		if part in ["..","."] or part.begins_with(".") or part in ["downloads","build","developer"]: return ""
	if relative.get_extension() not in EXTENSIONS: return ""
	var path=(game_root+"/"+relative).simplify_path()
	if not path.begins_with(game_root+"/"): return ""
	# Refuse links, including parent directories.
	var parent=game_root
	for part in relative.split("/"):
		var dir=DirAccess.open(parent)
		if dir and dir.is_link(part): return ""
		parent+="/"+part
	return path

func file_list(folder: String="", depth: int=0) -> Array[String]:
	var files: Array[String]=[]
	if depth>6: return files
	var dir=DirAccess.open(game_root+"/"+folder)
	if not dir: return files
	for file in dir.get_files():
		var relative=folder+file
		if not safe_path(relative).is_empty(): files.append(relative)
	for child in dir.get_directories():
		if child.begins_with(".") or child in ["downloads","build","developer"] or dir.is_link(child): continue
		files.append_array(file_list(folder+child+"/",depth+1))
	return files

func source(relative: String) -> String:
	if staged.has(relative): return staged[relative]
	return FileAccess.get_file_as_string(safe_path(relative))

func load_models() -> void:
	if running or validating or (provider=="groq" and key_input.text.strip_edges().is_empty()): return
	running=true
	loading_models=true
	var error=http.request("http://127.0.0.1:11434/api/tags" if provider=="ollama" else "https://api.groq.com/openai/v1/models",headers(),HTTPClient.METHOD_GET)
	if error!=OK: running=false; loading_models=false; log_message("Impossible de charger les modèles.")

func prepare() -> void:
	if running or validating: return
	if prompt.text.strip_edges().is_empty() or (provider=="groq" and key_input.text.strip_edges().is_empty()): log_message("Renseigne la demande et, pour Groq, sa clé."); return
	staged.clear()
	baseline.clear()
	steps=0
	requests_sent=0
	format_retries=0
	tool_names.clear()
	messages=[{"role":"system","content":"Tu modifies un vrai projet Godot4.6. Utilise les fonctions fournies pour lire et modifier les vrais fichiers, jamais des chemins inventés. Les couleurs/cadres du HUD sont dans ui.gd (skin, CYAN), les cadres de survol des objets dans main.gd (draw_interaction_markers), les paramètres de couleur dans creator.gd (config.accent). Recherche puis lis le fichier avant de remplacer. Copie old exactement depuis la lecture. Fais des changements petits et ciblés, jamais la réécriture complète de design.json pour une couleur. Chaque changement est préparé en mémoire et nécessite une validation humaine. Ne génère pas de réseau, shell ou accès à des fichiers hors du jeu. Appelle finish pour expliquer le résultat en français quand la proposition est prête. Fichiers : "+JSON.stringify(file_list())},{"role":"user","content":prompt.text.left(4000)}]
	log_message("Toi : "+prompt.text)
	send_next()

func retry() -> void:
	if running or validating or messages.is_empty(): return
	send_next()

func send_next() -> void:
	if requests_sent>=20: log_message("Limite de 20 étapes. Examine la proposition ou recommence une demande plus précise."); return
	running=true
	loading_models=false
	requests_sent+=1
	var body=JSON.stringify(chat_payload())
	var error=http.request("http://127.0.0.1:11434/api/chat" if provider=="ollama" else ENDPOINT,headers(),HTTPClient.METHOD_POST,body)
	if error!=OK: running=false; log_message("Requête impossible : "+str(error))

func headers() -> PackedStringArray:
	if provider=="ollama": return PackedStringArray(["Content-Type: application/json"])
	return PackedStringArray(["Authorization: Bearer "+key_input.text.strip_edges(),"Content-Type: application/json"])

func chat_payload() -> Dictionary:
	if provider=="groq":
		return {"model":model_input.text.strip_edges(),"messages":messages,"tools":tool_definitions(),"tool_choice":"auto","temperature":0.1,"max_tokens":3000}
	var local_messages: Array=[]
	for original in messages:
		var entry: Dictionary=original.duplicate(true)
		if entry.get("tool_calls") is Array:
			for call in entry.tool_calls:
				if call.function.arguments is String: call.function.arguments=parse_action(call.function.arguments)
				call.erase("id")
				call.erase("type")
		if entry.get("role")=="tool":
			entry.tool_name=tool_names.get(entry.get("tool_call_id",""),"")
			entry.erase("tool_call_id")
		local_messages.append(entry)
	return {"model":model_input.text.strip_edges(),"messages":local_messages,"tools":tool_definitions(),"stream":false,"think":false,"options":{"temperature":0.1,"num_ctx":8192,"num_predict":3000}}

func normalize_local(response: Dictionary) -> Dictionary:
	if not response.get("message") is Dictionary: return response
	var message: Dictionary=response.message.duplicate(true)
	if message.get("tool_calls") is Array:
		for i in message.tool_calls.size():
			var call=message.tool_calls[i]
			if not call is Dictionary or not call.get("function") is Dictionary: continue
			call.id="local_%d_%d" % [requests_sent,i]
			call.type="function"
			tool_names[call.id]=call.function.get("name","")
			if call.function.get("arguments") is Dictionary: call.function.arguments=JSON.stringify(call.function.arguments)
	return {"choices":[{"message":message,"finish_reason":"length" if response.get("done_reason","")=="length" else "stop"}]}

func tool_definitions() -> Array:
	var paths: Array=file_list()
	for path in staged:
		if path not in paths: paths.append(path)
	var specs=[
		{"name":"read_file","description":"Lire les lignes réelles d'un fichier du projet.","properties":{"path":{"type":"string","enum":paths},"start":{"type":"integer"},"lines":{"type":"integer"}},"required":["path","start","lines"]},
		{"name":"search_code","description":"Chercher un texte dans le projet et obtenir les chemins et lignes exacts.","properties":{"query":{"type":"string"}},"required":["query"]},
		{"name":"replace_text","description":"Préparer un remplacement précis. old doit être un extrait exact et unique du fichier lu.","properties":{"path":{"type":"string","enum":paths},"old":{"type":"string"},"new":{"type":"string"}},"required":["path","old","new"]},
		{"name":"create_file","description":"Préparer un nouveau fichier texte dans le projet.","properties":{"path":{"type":"string"},"text":{"type":"string"}},"required":["path","text"]},
		{"name":"finish","description":"Terminer et expliquer les changements préparés en français.","properties":{"explanation":{"type":"string"}},"required":["explanation"]}
	]
	var result: Array=[]
	for spec in specs:
		result.append({"type":"function","function":{"name":spec.name,"description":spec.description,"parameters":{"type":"object","properties":spec.properties,"required":spec.required,"additionalProperties":false}}})
	return result

func recover_format(reason: String) -> void:
	format_retries+=1
	log_message(reason)
	if format_retries<=2 and requests_sent<20:
		messages.append({"role":"user","content":"La réponse précédente a échoué. Utilise un appel de fonction fourni, avec ses arguments exacts. Ne rédige pas de JSON libre ou de code inventé. Commence par read_file ou search_code, puis fais un replace_text court avec le texte exact lu. Les chemins sont ceux de la liste du projet. Termine avec finish."})
		log_message("Correction automatique (%d/2)…" % format_retries)
		send_next.call_deferred()
	else: log_message("Corrections épuisées. Aucun fichier écrit. Choisis un modèle compatible avec les appels de fonctions.")

func execute_tool_calls(message: Dictionary) -> bool:
	var calls=message.get("tool_calls",[])
	if not calls is Array or calls.is_empty() or calls.size()>5: return false
	for call in calls:
		if not call is Dictionary or not call.get("id") is String or not call.get("function") is Dictionary: return false
	var assistant={"role":"assistant","tool_calls":calls}
	if message.get("content") is String: assistant.content=message.content
	messages.append(assistant)
	var finished:=false
	for call in calls:
		if not call is Dictionary or not call.get("id") is String or not call.get("function") is Dictionary:
			log_message("Appel de fonction incomplet ; recommence la demande.")
			return false
		var function=call.function
		var action=parse_action(str(function.get("arguments","")))
		var actions={"read_file":"read","search_code":"search","replace_text":"replace","create_file":"create","finish":"done"}
		var feedback="Arguments invalides ou fonction inconnue. Utilise les arguments du schéma."
		if not action.is_empty() and actions.has(function.get("name","")):
			action.action=actions[function.name]
			if action.action=="done":
				finished=true
				feedback="Proposition terminée."
				log_message(("Ollama" if provider=="ollama" else "Groq")+" : "+str(action.get("explanation","Terminé"))+"\nFichiers préparés : "+JSON.stringify(staged.keys())+"\nApplique la proposition puis relance le jeu.")
			else:
				feedback=perform(action)
				steps+=1
				log_message("Étape %d : %s %s\n%s" % [steps,action.action,str(action.get("path","")),feedback.left(700)])
		messages.append({"role":"tool","tool_call_id":call.id,"content":feedback})
	format_retries=0
	if not finished: send_next.call_deferred()
	return true

func received(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	running=false
	if result!=HTTPRequest.RESULT_SUCCESS and provider=="ollama":
		log_message("Ollama ne répond pas sur ce PC. Lance Ollama, puis exécute ollama pull qwen3:8b. Le premier chargement peut prendre du temps. Clique ensuite RÉESSAYER.")
		return
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		if provider=="ollama":
			log_message("Ollama HTTP %d : %s\nVérifie que le modèle est installé avec ollama list." % [code,body.get_string_from_utf8().left(900)])
			return
		var error_parser=JSON.new()
		if not loading_models and code==400 and error_parser.parse(body.get_string_from_utf8())==OK and error_parser.data is Dictionary:
			var detail=error_parser.data.get("error",{})
			if detail is Dictionary and detail.get("code","") in ["json_validate_failed","tool_use_failed"]:
				recover_format("Le fournisseur a refusé le format de l'appel de fonction.")
				return
		log_message("API %d : %s\nEn cas de 429, attends puis clique RÉESSAYER. Aucun fichier écrit." % [code,body.get_string_from_utf8().left(1200)])
		return
	var response=JSON.parse_string(body.get_string_from_utf8())
	if loading_models:
		loading_models=false
		var ids: Array[String]=[]
		if provider=="ollama" and response is Dictionary and response.get("models") is Array:
			for entry in response.models:
				if entry is Dictionary and entry.get("name") is String: ids.append(entry.name)
		if response is Dictionary and response.get("data") is Array:
			for entry in response.data:
				if entry is Dictionary and entry.get("id") is String and entry.get("active",true) and not ("whisper" in entry.id or "tts" in entry.id or "guard" in entry.id): ids.append(entry.id)
		ids.sort()
		log_message("Modèles disponibles : "+", ".join(ids))
		if not ids.is_empty() and model_input.text not in ids: model_input.text=ids[0]
		return
	if provider=="ollama" and response is Dictionary: response=normalize_local(response)
	if not response is Dictionary or not response.get("choices") is Array or response.choices.is_empty(): log_message("Réponse API inattendue."); return
	var message=response.choices[0].get("message",{})
	var finish_reason=str(response.choices[0].get("finish_reason",""))
	if finish_reason=="length": recover_format("Réponse tronquée (limite de longueur)."); return
	if message is Dictionary and message.get("tool_calls") is Array:
		if not execute_tool_calls(message): log_message("Appels de fonctions illisibles. Aucun fichier écrit.")
		return
	var content=str(message.get("content",""))
	var action=parse_action(content)
	var reason=str(response.choices[0].get("finish_reason",""))
	if action.is_empty() or action.get("action","") not in ["read","search","replace","create","done"]:
		recover_format("Réponse sans appel de fonction exploitable.")
		return
	format_retries=0
	steps+=1
	messages.append({"role":"assistant","content":content})
	if action.get("action")=="done":
		log_message(("Ollama" if provider=="ollama" else "Groq")+" : "+str(action.get("explanation","Terminé"))+"\nFichiers préparés : "+JSON.stringify(staged.keys())+"\nLis les changements ci-dessus puis clique APPLIQUER + VÉRIFIER.")
		return
	var feedback=perform(action)
	messages.append({"role":"user","content":feedback})
	log_message("Étape %d : %s %s\n%s" % [steps,str(action.get("action","")),str(action.get("path","")),feedback.left(700)])
	send_next.call_deferred()

func parse_action(content: String) -> Dictionary:
	var parser=JSON.new()
	if parser.parse(content)==OK:
		return parser.data if parser.data is Dictionary else {}
	# Accept a single fenced object or surrounding explanation, never incomplete JSON.
	var start=content.find("{")
	var end=content.rfind("}")
	if start>=0 and end>start:
		if parser.parse(content.substr(start,end-start+1))==OK and parser.data is Dictionary: return parser.data
	return {}

func perform(action: Dictionary) -> String:
	var kind=action.get("action","")
	var fields={"search":["query"],"read":["path"],"replace":["path","old","new"],"create":["path","text"]}
	if not fields.has(kind): return "Action inconnue."
	for field in fields[kind]:
		if not action.get(field) is String: return "Argument requis invalide : "+str(field)
	if kind=="read":
		for field in ["start","lines"]:
			if action.has(field) and not (action[field] is int or action[field] is float): return "La lecture attend des numéros de lignes, pas une liste de lignes inventées."
	if action.get("action")=="search":
		var query=str(action.get("query",""))
		if query.is_empty(): return "Recherche vide interdite."
		var matches: Array[String]=[]
		for file in file_list():
			if FileAccess.get_file_as_bytes(safe_path(file)).size()>200000: continue
			var rows=source(file).split("\n")
			for i in rows.size():
				if query.to_lower() in rows[i].to_lower():
					matches.append("%s:%d %s" % [file,i+1,rows[i].left(250)])
					if matches.size()>=40: return "\n".join(matches)
		return "\n".join(matches)
	var relative=str(action.get("path",""))
	var path=safe_path(relative)
	if path.is_empty(): return "Chemin interdit ou format non textuel."
	if action.get("action")=="create":
		if FileAccess.file_exists(path) or staged.has(relative): return "Le fichier existe : utiliser read puis replace."
		var text=str(action.get("text",""))
		if text.length()>100000: return "Fichier trop grand."
		baseline[relative]={"exists":false,"text":""}
		staged[relative]=text
		log_message("NOUVEAU FICHIER "+relative+"\n"+text)
		return "Fichier préparé."
	if not FileAccess.file_exists(path) and not staged.has(relative): return "Fichier absent."
	if FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path).size()>200000: return "Fichier trop grand."
	var text=source(relative)
	if action.get("action")=="read":
		var rows=text.split("\n")
		var start=clampi(int(action.get("start",1))-1,0,maxi(0,rows.size()-1))
		var end=mini(start+clampi(int(action.get("lines",80)),1,120),rows.size())
		return "%s lignes %d à %d / %d\n%s" % [relative,start+1,end,rows.size(),"\n".join(rows.slice(start,end))]
	if action.get("action")=="replace":
		var old=str(action.get("old",""))
		var replacement=str(action.get("new",""))
		if old.is_empty() or text.count(old)!=1: return "Ancien texte absent ou non unique. Relire puis essayer un extrait unique."
		if not baseline.has(relative): baseline[relative]={"exists":true,"text":text}
		staged[relative]=text.replace(old,replacement)
		log_message("MODIFICATION "+relative+"\nAVANT :\n"+old+"\nAPRÈS :\n"+replacement)
		return "Modification préparée."
	return "Action inconnue."

func write_files(files: Dictionary, restore: bool=false) -> bool:
	for relative in files:
		var path=safe_path(relative)
		if path.is_empty(): return false
		if restore and not files[relative].exists:
			if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
			continue
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file=FileAccess.open(path,FileAccess.WRITE)
		if not file: return false
		file.store_string(files[relative].text if restore else files[relative])
	return true

func apply_changes() -> void:
	if running or validating or staged.is_empty(): return
	for relative in baseline:
		var path=safe_path(relative)
		if FileAccess.file_exists(path)!=baseline[relative].exists or (baseline[relative].exists and FileAccess.get_file_as_string(path)!=baseline[relative].text):
			log_message("Le fichier a changé depuis la proposition : "+relative+". Recommence la demande.")
			return
	undo_files=baseline.duplicate(true)
	var backup=game_root+"/.atelier-backups/"+str(Time.get_unix_time_from_system()).replace(".","-")+".json"
	DirAccess.make_dir_recursive_absolute(backup.get_base_dir())
	var file=FileAccess.open(backup,FileAccess.WRITE)
	if not file: log_message("Sauvegarde impossible : aucune modification appliquée."); return
	file.store_string(JSON.stringify(undo_files))
	file.close()
	if not write_files(staged): write_files(undo_files,true); log_message("Écriture refusée : retour aux fichiers précédents."); return
	validating=true
	log_message("Fichiers écrits. Vérification Godot en cours…")
	worker=Thread.new()
	worker.start(validate_game)

func validate_game() -> void:
	var output: Array=[]
	var code=OS.execute(OS.get_executable_path(),["--headless","--audio-driver","Dummy","--path",game_root,"--editor","--quit"],output,true)
	for relative in file_list():
		if relative.get_extension()!="gd": continue
		var script_output: Array=[]
		var script_code=OS.execute(OS.get_executable_path(),["--headless","--audio-driver","Dummy","--path",game_root,"--check-only","--script",safe_path(relative)],script_output,true)
		output.append_array(script_output)
		if script_code!=0: code=script_code
	var logs="\n".join(output)
	var failed=code!=0 or "SCRIPT ERROR" in logs or "Parse Error" in logs or "Failed to load script" in logs
	validation_finished.call_deferred(failed,logs.left(12000))

func validation_finished(failed: bool, logs: String) -> void:
	worker.wait_to_finish()
	validating=false
	if failed:
		var restored=write_files(undo_files,true)
		log_message("Vérification échouée. Retour arrière : "+str(restored)+"\n"+logs)
	else: log_message("Vérification des scripts réussie. Relance le jeu pour voir les changements. Vérifie aussi le résultat en jouant.")
	staged.clear()
	baseline.clear()

func undo() -> void:
	if running or validating: return
	if undo_files.is_empty(): log_message("Aucune modification à annuler dans cette session. Les sauvegardes précédentes sont dans game/.atelier-backups."); return
	log_message("Retour aux fichiers précédents : "+str(write_files(undo_files,true)))
	undo_files.clear()
	staged.clear()

func launch_game() -> void:
	if validating: return
	var output: Array=[]
	OS.execute(OS.get_executable_path(),["--headless","--audio-driver","Dummy","--path",game_root,"--editor","--quit"],output,true)
	OS.create_process(OS.get_executable_path(),["--path",game_root])
	log_message("Jeu lancé depuis les sources. Ferme la partie précédente avant de relancer.")

func open_editor() -> void:
	if validating: return
	OS.create_process(OS.get_executable_path(),["--path",game_root,"--editor"])

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and worker and worker.is_started(): worker.wait_to_finish()
