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
			if topic.id in ["unknown","dismiss"]: continue
			assert(game.chat_with_customer(topic.keywords[0]))
			assert(game.chat_memory.topic==topic.id)
			assert(not "{" in game.chat_log[-1] and not "}" in game.chat_log[-1])
			assert(game.speech.length()<=int(game.sheet.local_chat[0].response_limit))
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
	game.customer_state="waiting"
	game.actor_customer=4
	game.reset_customer_conversation()
	var chapters := {}
	for prompt in ["Raconte une histoire", "Raconte la suite", "Et ensuite ?"]:
		assert(game.chat_with_customer(prompt))
		assert(game.chat_memory.topic=="story")
		assert(game.speech.length()>200)
		chapters[game.speech]=true
	assert(chapters.size()==3)
	game.reset_customer_conversation()
	assert(game.chat_with_customer("Tu peux me raconter une histoire, bonjour ?"))
	assert(game.chat_memory.topic=="story", "Le sujet précis doit primer sur une salutation")
	assert(game.chat_with_customer("Raconte la suite"))
	var complete=game.chat_log.duplicate()
	game.travel("office",440)
	assert(game.save_at_sofa())
	game.chat_log.clear()
	game.chat_memory.clear()
	assert(game.load_at_sofa())
	assert(game.chat_log==complete, "Les textes longs ne doivent pas être tronqués au chargement")
	game.travel("restaurant",565)
	assert(game.chat_with_customer("La suite"))
	assert(game.speech==game.sheet.chat_personalities[4].story[2])
	for prompt in ["casse toi", "va-t’en", "dégage"]:
		game.customer_state="waiting"
		game.customer_x=946
		game.reset_customer_conversation()
		var old_actor=game.actor_customer
		var balance=game.coins
		var sales=game.served
		var stock=game.inventory.duplicate()
		var carried=game.holding
		assert(game.chat_with_customer(prompt))
		assert(game.customer_state=="leaving" and game.customer_emotion=="angry")
		assert(game.coins==balance and game.served==sales and game.inventory==stock and game.holding==carried)
		assert(not game.serve())
		var departure=game.snapshot()
		game.customer_emotion="calm"
		game.apply_snapshot(departure)
		assert(game.customer_emotion=="angry" and game.customer_state=="leaving")
		game.update_customers(10)
		assert(game.actor_customer!=old_actor and game.customer_emotion=="calm")
		assert(game.customer_state=="arriving" and game.chat_memory.is_empty())
		game.update_customers(10)
		assert(game.customer_state=="waiting")
	game.ui.show_page("chat")
	var fields=game.ui.window.find_children("*","LineEdit",true,false)
	assert(fields.size()==1)
	fields[0].text="casse-toi"
	fields[0].text_submitted.emit(fields[0].text)
	assert(not game.menu and game.customer_state=="leaving" and game.customer_emotion=="angry", "La fenêtre doit se fermer pour laisser le client partir immédiatement")
	for child in game.get_children(): assert(not child is HTTPRequest)
	game.new_service()
	assert(game.chat_log.is_empty() and game.chat_memory.is_empty())
	game.queue_free()
	await process_frame
	print("PASS chat autonome : gratuit sans HTTP, sept personnalités, accents, contexte réel, 161 sujets/races, histoires en trois parties, textes longs conservés, insultes et départ en colère sans vente, relances, réponses variées, prénom, sauvegarde/chargement, mémoire par client, aucune modification des ressources.")
	quit(0)
