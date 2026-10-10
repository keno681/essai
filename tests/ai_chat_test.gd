extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func await_reply(game: Node) -> void:
	var deadline := Time.get_ticks_msec()+4000
	while game.ai_busy and Time.get_ticks_msec()<deadline:
		await create_timer(0.02).timeout
	assert(not game.ai_busy,"La requête doit se terminer ou échouer sans bloquer le jeu")

func run_tests() -> void:
	var game = load("res://main.gd").new()
	root.add_child(game)
	game.voice_enabled=false
	game.ui.hide_page()
	game.room="restaurant"
	game.customer_state="waiting"
	game.ai_endpoint="http://127.0.0.1:"+OS.get_environment("COSMO_TEST_PORT")+"/v1/responses"
	game.configure_ai("sk-local-test-not-real",true)
	assert(game.chat_with_customer("Bonjour, voyageur !"))
	assert(game.ai_busy)
	assert(not game.chat_with_customer("Un deuxième message trop tôt"))
	await await_reply(game)
	assert("La galaxie a bon goût" in game.chat_log[-1])
	assert(game.ai_status.begins_with("Réponse IA"))
	assert(game.ai_history.size()==2)
	assert(game.chat_with_customer("ma commande ?"))
	await await_reply(game)
	assert("clé API refusée" in game.ai_status)
	assert(game.recipe(game.order).name in game.chat_log[-1])
	assert(game.chat_with_customer("bonjour"))
	await await_reply(game)
	assert("quota" in game.ai_status)
	assert(game.chat_with_customer("merci"))
	await await_reply(game)
	assert("service indisponible" in game.ai_status)
	assert(game.ai_history.size()<=8)
	game.ai_http.timeout=0.15
	assert(game.chat_with_customer("bonjour"))
	await await_reply(game)
	assert("délai dépassé" in game.ai_status)
	game.ai_http.timeout=2
	assert(game.chat_with_customer("bonjour"))
	await create_timer(0.08).timeout
	game.new_service()
	await create_timer(0.6).timeout
	assert(not game.ai_busy and game.chat_log.is_empty() and game.ai_history.is_empty())
	game.save_settings()
	assert(not "sk-local-test" in FileAccess.get_file_as_string("user://settings.json"))
	assert(not "sk-local-test" in JSON.stringify(game.snapshot()))
	game.configure_ai("",false)
	assert(game.ai_key.is_empty() and not game.ai_enabled)
	game.customer_state="waiting"
	assert(game.chat_with_customer("bonjour"))
	assert(not game.ai_busy)
	game.ui.show_page("ai")
	print("PASS IA : HTTP réel vers serveur simulé, contexte, réponse, authentification, quota, réponse invalide, timeout, annulation, absence de clé dans les sauvegardes, mode local et options.")
	game.queue_free()
	await process_frame
	quit(0)
