extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game=load("res://main.gd").new()
	root.add_child(game)
	var creator=game.creator
	assert(creator.provider=="groq")
	assert(creator.endpoint()=="https://api.groq.com/openai/v1/chat/completions")
	assert(creator.model=="llama-3.3-70b-versatile")
	creator.key="fake-groq-test-key"
	creator.model="custom-groq-model"
	creator.conversation.append({"role":"user","content":"test"})
	assert(creator.select_provider("openai"))
	assert(creator.endpoint()=="https://api.openai.com/v1/chat/completions")
	assert(creator.key!="fake-groq-test-key" and creator.conversation.is_empty())
	creator.key="fake-openai-test-key"
	assert(creator.select_provider("groq"))
	assert(creator.key=="fake-groq-test-key" and creator.model=="custom-groq-model")
	assert(not creator.select_provider("invalid"))
	assert(creator.api_error(401,PackedByteArray()).contains("Groq"))
	assert(creator.api_error(429,JSON.stringify({"error":{"code":"insufficient_quota"}}).to_utf8_buffer()).contains("crédits/quota"))
	game.ui.hide_page()
	assert(game.start_click_action(Vector2(1045,377)))
	assert(game.ui.page=="creator" and game.menu)
	creator.key=""
	creator.ask("change le décor")
	assert(creator.status.begins_with("Clé manquante"))
	var before=game.sheet.recipes[0].name
	var response={"choices":[{"message":{"content":JSON.stringify({"explanation":"Un monde violet", "patch":{"title":"WRAP GALAXIE","accent":"aa88ff","recipe_names":{"0":"Wrap violet"},"recipe_prices":{"0":200},"planets":[{"name":"Violette","color":"aa88ff"}],"decor":[{"x":600,"y":400,"size":20,"color":"aa88ff"}],"code":"delete files"}})}}]}
	creator.completed(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify(response).to_utf8_buffer())
	assert(creator.console_text().contains("Groq : Un monde violet"))
	assert(not creator.pending.has("code"))
	assert(game.sheet.recipes[0].name==before)
	creator.key="test-private-not-a-real-key"
	creator.apply_pending()
	assert(game.sheet.recipes[0].name=="Wrap violet")
	assert(game.sheet.recipes[0].price==100)
	assert(creator.config.title=="WRAP GALAXIE")
	var disk=FileAccess.get_file_as_string(creator.PATH)
	assert(not disk.contains(creator.key))
	assert(creator.console_text().contains("Changements appliqués"))
	creator.visit(creator.config.planets[0])
	assert(game.room=="planet" and creator.config.planet_name=="Violette")
	creator.undo()
	assert(game.sheet.recipes[0].name==before)
	assert(not creator.validate({"accent":"bad","decor":[{"x":"bad","y":10,"color":"ffffff"}]}).has("accent"))
	creator.completed(HTTPRequest.RESULT_SUCCESS,429,[],PackedByteArray())
	assert(creator.status.contains("429"))
	assert(creator.console_text().contains("429"))
	game.queue_free()
	await process_frame
	var restored=load("res://main.gd").new()
	root.add_child(restored)
	assert(restored.sheet.recipes[0].name==before)
	restored.queue_free()
	await process_frame
	print("CREATOR TEST PASSED: Pokéball, validation, preview, apply, undo, persistence, private key and API errors")
	quit()
