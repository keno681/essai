extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var tool=load("res://atelier.gd").new()
	root.add_child(tool)
	tool.provider="groq"
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
	tool.provider="ollama"
	tool.key_input.text="fake-private-key"
	var local_payload=tool.chat_payload()
	assert(local_payload.think==false and local_payload.stream==false)
	assert(not JSON.stringify(local_payload).contains(tool.key_input.text))
	assert(not "Authorization" in str(tool.headers()))
	var local=tool.normalize_local({"message":{"role":"assistant","content":"","tool_calls":[{"function":{"name":"finish","arguments":{"explanation":"Local prêt"}}}]},"done":true,"done_reason":"stop"})
	assert(local.choices[0].message.tool_calls[0].function.arguments is String)
	assert(local.choices[0].message.tool_calls[0].id.begins_with("local_"))
	var tool_id=local.choices[0].message.tool_calls[0].id
	tool.messages.append({"role":"tool","tool_call_id":tool_id,"content":"ok"})
	assert(tool.chat_payload().messages[-1].tool_name=="finish")
	tool.messages.pop_back()
	tool.provider="groq"
	var definitions=tool.tool_definitions()
	assert(definitions.size()==5)
	assert("sample.gd" in definitions[0].function.parameters.properties.path.enum)
	assert(tool.perform({"action":"read","path":"sample.gd","lines":[{"line_number":30}]}).contains("numéros"))
	assert(tool.perform({"action":"replace","path":"hui:/ui.gd","old":"x","new":"y"}).contains("interdit"))
	var calls=[
		{"id":"call_read","type":"function","function":{"name":"read_file","arguments":JSON.stringify({"path":"sample.gd","start":1,"lines":20})}},
		{"id":"call_replace","type":"function","function":{"name":"replace_text","arguments":JSON.stringify({"path":"sample.gd","old":"= 1","new":"= 2"})}},
		{"id":"call_finish","type":"function","function":{"name":"finish","arguments":JSON.stringify({"explanation":"Modification proposée"})}}
	]
	assert(tool.execute_tool_calls({"tool_calls":calls}))
	assert(tool.staged["sample.gd"].contains("= 2"))
	assert(FileAccess.get_file_as_string(tool.game_root+"/sample.gd").contains("= 1"))
	assert(tool.messages[-1].role=="tool" and tool.messages[-1].tool_call_id=="call_finish")
	tool.staged.clear()
	tool.baseline.clear()
	tool.requests_sent=20
	tool.received(HTTPRequest.RESULT_SUCCESS,400,[],JSON.stringify({"error":{"code":"json_validate_failed","message":"Failed to generate JSON"}}).to_utf8_buffer())
	assert(tool.console.text.contains("Le fournisseur a refusé"))
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
