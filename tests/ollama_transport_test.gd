extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var tool=load("res://atelier.gd").new()
	root.add_child(tool)
	tool.game_root="/tmp/ollama-http-fixture-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tool.game_root)
	var file=FileAccess.open(tool.game_root+"/project.godot",FileAccess.WRITE)
	file.store_string("config_version=5\n[application]\nconfig/name=\"Local fixture\"\n")
	file.close()
	file=FileAccess.open(tool.game_root+"/ui.gd",FileAccess.WRITE)
	file.store_string('extends Node\nvar border = Color("edc478")\n')
	file.close()
	tool.key_input.text="fake-private-key"
	tool.local_structured=not "--native" in OS.get_cmdline_user_args()
	tool.prompt.text="Cadre vert"
	tool.prepare()
	var deadline=Time.get_ticks_msec()+15000
	while not tool.console.text.contains("Ollama : Cadre vert") and Time.get_ticks_msec()<deadline: await process_frame
	assert(tool.staged.has("ui.gd") and tool.staged["ui.gd"].contains("55cc77"))
	assert(tool.console.text.contains("Ollama : Cadre vert"))
	assert(tool.messages[-1].role==("assistant" if tool.local_structured else "tool"))
	tool.apply_changes()
	while tool.validating: await process_frame
	assert(FileAccess.get_file_as_string(tool.game_root+"/ui.gd").contains("55cc77"))
	tool.undo()
	assert(FileAccess.get_file_as_string(tool.game_root+"/ui.gd").contains("edc478"))
	tool.queue_free()
	await process_frame
	print("OLLAMA HTTP INTEGRATION PASSED: native functions, preview, apply and undo")
	quit()
