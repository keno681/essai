extends Node
var game_root: String
var engine: RefCounted
var pid := -1
var busy := false
func _ready() -> void:
	game_root=ProjectSettings.globalize_path("res://../game").simplify_path()
	engine=load(game_root+"/patch_engine.gd").new()
	engine.root_path=game_root
	var output: Array=[]
	OS.execute(OS.get_executable_path(),["--headless","--audio-driver","Dummy","--path",game_root,"--editor","--quit"],output,true)
	start_game()
func start_game() -> void:
	var arguments=["--path",game_root,"--","--console-managed"]
	if "--headless-children" in OS.get_cmdline_user_args(): arguments.insert(0,"--headless")
	pid=OS.create_process(OS.get_executable_path(),arguments)
	if pid<0: get_tree().quit(1)
func _process(_delta: float) -> void:
	if busy or pid<0 or OS.is_process_running(pid): return
	var request=game_root+"/.console-runtime/request.json"
	if not FileAccess.file_exists(request): get_tree().quit(); return
	busy=true
	var command=JSON.parse_string(FileAccess.get_file_as_string(request))
	DirAccess.remove_absolute(request)
	var ok:=false
	var message: String
	if command is Dictionary and command.get("action")=="apply" and command.get("patch") is String:
		var transaction=engine.prepare(command.patch)
		if not transaction.is_empty(): ok=engine.apply(transaction,OS.get_executable_path())
		message="Modification appliquée et vérifiée. Jeu relancé." if ok else engine.error
	elif command is Dictionary and command.get("action")=="undo":
		ok=engine.undo_latest()
		message="Modification annulée. Jeu relancé." if ok else engine.error
	else: message="Commande de relance non reconnue."
	var receipt=FileAccess.open(game_root+"/.console-runtime/result.json",FileAccess.WRITE)
	if receipt:
		receipt.store_string(JSON.stringify({"ok":ok,"message":message})); receipt.close()
	start_game()
	busy=false
