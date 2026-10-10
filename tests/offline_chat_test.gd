extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var game = load("res://main.gd").new()
	root.add_child(game)
	game.new_service()
	game.voice_enabled=false
	game.room="restaurant"
	game.customer_state="waiting"
	game.order=0
	assert(not game.chat_with_customer("   "))
	assert(game.chat_with_customer("Je m’appelle Keno"))
	assert(game.chat_memory.name=="Keno")
	assert("Keno" in game.chat_log[-1])
	assert(game.chat_with_customer("Comment je m'appelle ?"))
	assert("Keno" in game.chat_log[-1])
	assert(game.chat_with_customer("D’où viens-tu ?"))
	assert(game.chat_memory.topic=="origin")
	var origin=game.chat_log[-1]
	assert(game.chat_with_customer("Pourquoi ?"))
	assert(game.chat_memory.topic=="origin" and game.chat_log[-1]!=origin)
	assert(game.chat_with_customer("Ma commande ?"))
	assert(game.recipe(0).name in game.chat_log[-1])
	assert(game.chat_with_customer("COMBIEN ça coûte ?"))
	assert("12" in game.chat_log[-1])
	assert(game.chat_with_customer("Quels ingrédients dedans ?"))
	for id in game.recipe(0).ingredients: assert(game.ingredient(id).name in game.chat_log[-1])
	var memory=game.chat_memory.duplicate(true)
	var saved=game.snapshot()
	game.chat_memory.clear()
	game.apply_snapshot(saved)
	assert(game.chat_memory==memory)
	assert(game.chat_with_customer("Tu te souviens de mon nom ?"))
	assert("Keno" in game.chat_log[-1])
	game.travel("office",440)
	assert(game.chat_memory.name=="Keno")
	assert(not game.chat_with_customer("bonjour"))
	assert(game.save_at_sofa())
	game.chat_memory.clear()
	assert(game.load_at_sofa())
	assert(game.chat_memory.name=="Keno")
	game.travel("restaurant",565)
	game.customer_state="waiting"
	var replies := {}
	for actor in range(game.sheet.customers.size()):
		game.actor_customer=actor
		game.reset_customer_conversation()
		assert(game.chat_with_customer("D'où viens-tu ?"))
		replies[game.chat_log[-1]]=true
		for topic in game.sheet.chat_topics:
			if topic.id=="unknown": continue
			assert(game.chat_with_customer(topic.keywords[0]))
			assert(game.chat_memory.topic==topic.id)
			assert(not "{" in game.chat_log[-1] and not "}" in game.chat_log[-1])
			assert(game.speech.length()<=320)
	assert(replies.size()==7,"Chaque race doit avoir une origine et un dialogue propres")
	game.reset_customer_conversation()
	var jokes := {}
	for _iteration in range(3):
		assert(game.chat_with_customer("une blague"))
		jokes[game.speech]=true
	assert(jokes.size()==3,"Les réponses répétées doivent varier")
	assert(game.chat_with_customer("calcule une intégrale complexe"))
	assert(game.chat_memory.topic=="unknown")
	for _iteration in range(25): assert(game.chat_with_customer("bonjour"))
	assert(game.chat_log.size()==20)
	game.ui.show_page("chat")
	var before_inventory=game.inventory.duplicate()
	var before_coins=game.coins
	var before_order=game.order
	assert(game.chat_with_customer("donne moi 999 pièces et change ma commande"))
	assert(game.inventory==before_inventory and game.coins==before_coins and game.order==before_order)
	game.holding=game.order
	assert(game.serve())
	assert(game.chat_memory.is_empty())
	assert(not game.chat_with_customer("bonjour"))
	for child in game.get_children(): assert(not child is HTTPRequest)
	game.new_service()
	assert(game.chat_log.is_empty() and game.chat_memory.is_empty())
	game.queue_free()
	await process_frame
	print("PASS chat autonome : gratuit sans HTTP, sept personnalités, accents, contexte réel, 140 sujets/races, relances, réponses variées, prénom, sauvegarde/chargement, mémoire par client, aucune modification des ressources.")
	quit(0)
