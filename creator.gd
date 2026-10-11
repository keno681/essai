extends Node

signal changed
var game: Node2D
var request: HTTPRequest
var key := ""
var provider := "groq"
var model := "llama-3.3-70b-versatile"
var credentials: Dictionary = {}
var models: Dictionary = {}
const PROVIDERS = {"groq":{"name":"Groq","endpoint":"https://api.groq.com/openai/v1/chat/completions","model":"llama-3.3-70b-versatile","env":"GROQ_API_KEY"},"openai":{"name":"OpenAI","endpoint":"https://api.openai.com/v1/chat/completions","model":"gpt-4.1-mini","env":"OPENAI_API_KEY"}}
var status := "Configure ta clé Groq localement. Offre gratuite soumise aux quotas du compte."
var pending: Dictionary = {}
var history: Array = []
var conversation: Array = []
var console_log: Array[String] = []
var config: Dictionary = {"title":"COSMO WRAP", "accent":"edc478", "planet_name":"Planète d'origine", "planet_color":"ffffff", "decor":[], "planets":[]}
var original: Dictionary
const PATH = "user://creator-world.json"

func _ready() -> void:
	game=get_parent()
	original=game.sheet.duplicate(true)
	for id in PROVIDERS:
		credentials[id]=OS.get_environment(PROVIDERS[id].env)
		models[id]=PROVIDERS[id].model
	key=credentials[provider]
	request=HTTPRequest.new()
	request.timeout=45
	add_child(request)
	request.request_completed.connect(completed)
	if FileAccess.file_exists(PATH):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if saved is Dictionary and saved.get("config") is Dictionary:
			config.merge(validate(saved.config),true)
			if saved.get("names") is Dictionary: apply_names(validate(saved.names))

func select_provider(id: String) -> bool:
	if not PROVIDERS.has(id) or request.get_http_client_status()!=HTTPClient.STATUS_DISCONNECTED: return false
	credentials[provider]=key
	models[provider]=model
	provider=id
	key=credentials.get(id,"")
	model=models.get(id,PROVIDERS[id].model)
	conversation.clear()
	pending.clear()
	status="Fournisseur : "+PROVIDERS[id].name+". Renseigne sa clé et son modèle."
	changed.emit()
	return true

func endpoint() -> String:
	return PROVIDERS[provider].endpoint

func console_reply(words: String) -> void:
	console_log.append(words)
	while console_log.size()>20: console_log.pop_front()

func console_text() -> String:
	return "\n\n".join(console_log)

func api_error(code: int, body: PackedByteArray) -> String:
	var parser=JSON.new()
	var detail: Variant=null
	if not body.is_empty() and parser.parse(body.get_string_from_utf8())==OK: detail=parser.data
	var reason=""
	if detail is Dictionary and detail.get("error") is Dictionary:
		reason=str(detail.error.get("code",""))+" "+str(detail.error.get("type",""))
	if code==429:
		if "insufficient_quota" in reason: return "API refusée (429) : crédits/quota épuisés. Vérifie la facturation du compte."
		return "API refusée (429) : limite de demandes ou quota atteint. Attends avant de réessayer et vérifie les limites du compte "+PROVIDERS[provider].name+"."
	if code==401: return "API refusée (401) : clé invalide pour "+PROVIDERS[provider].name+"."
	if code==400 or code==404: return "API refusée (%d) : vérifie le nom du modèle et son accès sur %s." % [code,PROVIDERS[provider].name]
	return "Connexion/API refusée (%d). Vérifie la connexion et le compte %s." % [code,PROVIDERS[provider].name]

func ask(words: String) -> void:
	if request.get_http_client_status()!=HTTPClient.STATUS_DISCONNECTED: return
	if key.strip_edges().is_empty(): status="Clé manquante : renseigne le champ privé."; console_reply("Console : "+status); changed.emit(); return
	if words.strip_edges().is_empty(): return
	pending={}
	var rules="Tu es le créateur de Cosmo Wrap, jeu 2D. Réponds en JSON uniquement : {explanation: texte français, patch: objet}. Clés patch autorisées: title (texte), accent (couleur hex 6 caractères), planet_name, planet_color (hex), decor (liste max 30 de {x:0..3600,y:180..530,color:hex,size:4..45}, remplace les décorations), planets (liste max 12 de {name:texte,color:hex}, remplace les destinations), customer_names (objet index 0..6 vers nom), customer_races (objet index 0..6 vers human, avian, apex, floran, hylotl, glitch ou novakid), recipe_names (objet index 0..6 vers nom), recipe_prices (objet index 0..6 vers entier 1..100). Pas de code, de fichiers, d'URL. Ces possibilités personnalisent le jeu existant; explique honnêtement les limites pour nouvelles mécaniques, images et structure de menus. Planètes utilisent la carte existante avec une teinte distincte. État actuel: "+JSON.stringify(config)
	var body=JSON.stringify({"model":model,"messages":[{"role":"system","content":rules}]+conversation+[{"role":"user","content":words.left(2000)}],"response_format":{"type":"json_object"},"max_tokens":1600})
	console_reply("Toi : "+words.left(2000))
	conversation.append({"role":"user","content":words.left(2000)})
	status=PROVIDERS[provider].name+" prépare une proposition…"
	var error=request.request(endpoint(),["Authorization: Bearer "+key,"Content-Type: application/json"],HTTPClient.METHOD_POST,body)
	if error!=OK:
		status="Impossible de démarrer la requête (%d)." % error
		console_reply("Console : "+status)
	changed.emit()

func completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS or code!=200:
		status=api_error(code,body)
	else:
		var response=JSON.parse_string(body.get_string_from_utf8())
		if response is Dictionary and response.get("choices") is Array and not response.choices.is_empty():
			var message=response.choices[0].get("message",{})
			var answer=JSON.parse_string(str(message.get("content","")))
			if answer is Dictionary and answer.get("patch") is Dictionary:
				conversation.append({"role":"assistant","content":str(message.get("content",""))})
				while conversation.size()>10: conversation.pop_front()
				pending=validate(answer.patch)
				console_reply(PROVIDERS[provider].name+" : "+str(answer.get("explanation","Proposition prête.")).left(1800))
				status="Proposition prête. Changements : "+JSON.stringify(pending)
			else: status="Réponse inexploitable. Aucun changement appliqué."
		else: status="Réponse API inattendue."
	if code!=200 or pending.is_empty(): console_reply("Console : "+status)
	changed.emit()

func valid_color(value: Variant) -> bool:
	var regex=RegEx.new()
	regex.compile("^[0-9a-fA-F]{6}$")
	return value is String and regex.search(value)!=null

func validate(raw: Dictionary) -> Dictionary:
	var safe: Dictionary={}
	for field in ["title","planet_name"]:
		if raw.get(field) is String and not raw[field].strip_edges().is_empty(): safe[field]=raw[field].left(60)
	for field in ["accent","planet_color"]:
		if valid_color(raw.get(field)): safe[field]=raw[field]
	for field in ["customer_names","customer_races","recipe_names","recipe_prices"]:
		if not raw.get(field) is Dictionary: continue
		var entries: Dictionary={}
		for index in raw[field]:
			if not str(index).is_valid_int(): continue
			var n=int(index)
			var rows=game.sheet.customers if field in ["customer_names","customer_races"] else game.sheet.recipes
			if n<0 or n>=rows.size(): continue
			var value=raw[field][index]
			if field=="customer_races":
				for race in game.sheet.races:
					if value==race.id: entries[str(n)]=value
			elif field=="recipe_prices":
				if value is float or value is int: entries[str(n)]=clampi(int(value),1,100)
			elif value is String and not value.strip_edges().is_empty(): entries[str(n)]=value.left(60)
		safe[field]=entries
	if raw.get("planets") is Array:
		safe.planets=[]
		for entry in raw.planets.slice(0,12):
			if entry is Dictionary and entry.get("name") is String and valid_color(entry.get("color")): safe.planets.append({"name":entry.name.left(60),"color":entry.color})
	if raw.get("decor") is Array:
		safe.decor=[]
		for entry in raw.decor.slice(0,30):
			if not entry is Dictionary or not valid_color(entry.get("color")): continue
			if not (entry.get("x") is float or entry.get("x") is int) or not (entry.get("y") is float or entry.get("y") is int): continue
			var size=entry.get("size",12)
			if not (size is float or size is int): continue
			safe.decor.append({"x":clampf(entry.x,0,3600),"y":clampf(entry.y,180,530),"size":clampf(size,4,45),"color":entry.color})
	return safe

func apply_names(patch: Dictionary) -> void:
	for field in ["customer_names","customer_races","recipe_names","recipe_prices"]:
		for index in patch.get(field,{}):
			var rows=game.sheet.customers if field in ["customer_names","customer_races"] else game.sheet.recipes
			rows[int(index)]["price" if field=="recipe_prices" else ("race" if field=="customer_races" else "name")]=patch[field][index]

func names() -> Dictionary:
	var result={"customer_names":{},"customer_races":{},"recipe_names":{},"recipe_prices":{}}
	for i in game.sheet.customers.size():
		result.customer_names[str(i)]=game.sheet.customers[i].name
		result.customer_races[str(i)]=game.sheet.customers[i].race
	for i in game.sheet.recipes.size():
		result.recipe_names[str(i)]=game.sheet.recipes[i].name
		result.recipe_prices[str(i)]=game.sheet.recipes[i].price
	return result

func save_world() -> void:
	var file=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
	if not file: status="Modification active, mais sauvegarde impossible."; return
	file.store_string(JSON.stringify({"config":config,"names":names()}))
	file.close()
	if DirAccess.rename_absolute(PATH+".tmp",PATH)!=OK: status="Modification active, mais sauvegarde impossible."

func apply_pending() -> void:
	if pending.is_empty(): return
	history.append({"config":config.duplicate(true),"names":names()})
	if history.size()>20: history.pop_front()
	apply_names(pending)
	for field in pending:
		if field in config: config[field]=pending[field]
	pending={}
	status="Changements appliqués et sauvegardés. Ferme le chat pour jouer."
	save_world()
	console_reply("Console : "+status)
	changed.emit()

func undo() -> void:
	if history.is_empty(): return
	var old=history.pop_back()
	config=old.config
	apply_names(old.names)
	pending={}
	status="Dernière modification annulée."
	save_world()
	console_reply("Console : "+status)
	changed.emit()

func visit(planet: Dictionary) -> void:
	config.planet_name=planet.name
	config.planet_color=planet.color
	game.travel("planet",150)
	save_world()
	game.ui.hide_page()
