extends Node
signal changed
var game: Node2D
var engine: RefCounted
var pending: Dictionary={}
var draft := ""
var status := "Colle ici le bloc fourni dans notre conversation. Aucun abonnement ni service externe nécessaire."
var transcript := "CONSOLE · Prête à recevoir une modification."
var config: Dictionary={"title":"COSMO WRAP BALL","accent":"edc478","planet_name":"Planète d'origine","planet_color":"ffffff","decor":[],"planets":[]}
var root_path: String
var managed := false
var reopen := false
func _ready() -> void:
	game=get_parent()
	root_path=ProjectSettings.globalize_path("res://").trim_suffix("/")
	engine=load("res://patch_engine.gd").new()
	engine.root_path=root_path
	managed="--console-managed" in OS.get_cmdline_user_args()
	# Preserve existing visual customizations without any AI integration.
	if FileAccess.file_exists("user://creator-world.json"):
		var previous=JSON.parse_string(FileAccess.get_file_as_string("user://creator-world.json"))
		if previous is Dictionary and previous.get("config") is Dictionary:
			for field in config:
				if field=="title": continue
				if previous.config.has(field): config[field]=previous.config[field]
	var receipt=root_path+"/.console-runtime/result.json"
	if managed and FileAccess.file_exists(receipt):
		var result=JSON.parse_string(FileAccess.get_file_as_string(receipt))
		if result is Dictionary:
			status=str(result.get("message","Jeu relancé."))
			transcript="CONSOLE · "+status
			reopen=true
		DirAccess.remove_absolute(receipt)

func preview(words: String) -> void:
	draft=words
	pending=engine.prepare(words)
	status=engine.error if pending.is_empty() else "PRÊT · "+pending.title+"\nFichiers : "+", ".join(pending.after.keys())
	transcript="TOI · Bloc de modification collé.\n\nCONSOLE · "+status
	changed.emit()

func send_and_restart() -> void:
	preview(draft)
	if pending.is_empty(): return
	queue_restart({"action":"apply","patch":draft})

func undo() -> void:
	queue_restart({"action":"undo"})

func queue_restart(command: Dictionary) -> void:
	if not managed:
		status="Ouvre le pack sources avec JOUER.cmd pour modifier les fichiers et relancer le jeu."
		changed.emit(); return
	game.save_progress()
	var folder=root_path+"/.console-runtime"
	if DirAccess.make_dir_recursive_absolute(folder)!=OK: status="Dossier de relance inaccessible."; changed.emit(); return
	var file=FileAccess.open(folder+"/request.tmp",FileAccess.WRITE)
	if not file: status="Envoi impossible."; changed.emit(); return
	file.store_string(JSON.stringify(command)); file.close()
	if DirAccess.rename_absolute(folder+"/request.tmp",folder+"/request.json")!=OK: status="Envoi impossible."; changed.emit(); return
	get_tree().quit()
