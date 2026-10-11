extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var tool=load("res://atelier.gd").new()
	root.add_child(tool)
	assert(tool.parse_action('{"action":"done","explanation":"prêt"}').action=="done")
	assert(tool.parse_action('```json\n{"action":"read","path":"ui.gd"}\n```').path=="ui.gd")
	assert(tool.parse_action('Voici : {"action":"done","explanation":"ok"} Merci').action=="done")
	assert(tool.parse_action('{"action":"replace","new":"unfinished').is_empty())
	assert(tool.parse_action('[{"action":"done"}]').is_empty(),"Never accept multiple-action lists")
	tool.requests_sent=20
	var bad={"choices":[{"message":{"content":'{"action":"replace","new":"cut'},"finish_reason":"length"}]}
	tool.received(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify(bad).to_utf8_buffer())
	assert(tool.staged.is_empty() and tool.console.text.contains("tronquée"))
	var good={"choices":[{"message":{"content":'```json\n{"action":"done","explanation":"Prêt"}\n```'},"finish_reason":"stop"}]}
	tool.received(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify(good).to_utf8_buffer())
	assert(tool.format_retries==0 and tool.console.text.contains("Groq : Prêt"))
	tool.game_root="/tmp/atelier-fixture-"+str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tool.game_root)
	var file=FileAccess.open(tool.game_root+"/project.godot",FileAccess.WRITE)
	file.store_string("config_version=5\n[application]\nconfig/name=\"Fixture\"\n")
	file.close()
	file=FileAccess.open(tool.game_root+"/sample.gd",FileAccess.WRITE)
	file.store_string("extends Node\nvar answer: int = 1\n")
	file.close()
	assert(tool.safe_path("../../outside.gd").is_empty())
	assert(tool.safe_path("/tmp/outside.gd").is_empty())
	assert(tool.safe_path(".git/config").is_empty())
	assert(tool.safe_path("art/binary.png").is_empty())
	assert(tool.perform({"action":"read","path":"sample.gd"}).contains("answer"))
	assert(tool.perform({"action":"search","query":"answer"}).contains("sample.gd:2"))
	assert(tool.perform({"action":"replace","path":"sample.gd","old":"answer: int = 1","new":"answer: int = 2"})=="Modification préparée.")
	assert(FileAccess.get_file_as_string(tool.game_root+"/sample.gd").contains("= 1"))
	tool.apply_changes()
	while tool.validating: await process_frame
	assert(FileAccess.get_file_as_string(tool.game_root+"/sample.gd").contains("= 2"))
	tool.undo()
	assert(FileAccess.get_file_as_string(tool.game_root+"/sample.gd").contains("= 1"))
	tool.perform({"action":"replace","path":"sample.gd","old":"var answer: int = 1","new":"this is NOT valid GDScript !!!"})
	tool.apply_changes()
	while tool.validating: await process_frame
	assert(FileAccess.get_file_as_string(tool.game_root+"/sample.gd").contains("= 1"),"Syntax errors must roll back")
	assert(tool.console.text.contains("Vérification échouée"))
	tool.perform({"action":"create","path":"new.gd","text":"extends Node\n"})
	tool.apply_changes()
	while tool.validating: await process_frame
	assert(FileAccess.file_exists(tool.game_root+"/new.gd"))
	tool.undo()
	assert(not FileAccess.file_exists(tool.game_root+"/new.gd"))
	tool.perform({"action":"replace","path":"sample.gd","old":"= 1","new":"= 3"})
	file=FileAccess.open(tool.game_root+"/sample.gd",FileAccess.WRITE)
	file.store_string("extends Node\nvar answer: int = 99\n")
	file.close()
	tool.apply_changes()
	assert(FileAccess.get_file_as_string(tool.game_root+"/sample.gd").contains("99"),"Must not overwrite concurrent edits")
	tool.queue_free()
	await process_frame
	print("ATELIER PASS: confined paths, reads, search, staged edits, Godot validation, syntax rollback, undo, new files and concurrent changes")
	quit()
