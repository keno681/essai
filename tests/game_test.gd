extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var game = load("res://main.gd").new()
	root.add_child(game)
	game.new_service()
	game.coins = 0
	game.served = 0
	game.order = 0
	game.customer = 0
	game.upgraded = false
	game.holding = -1
	game.selected = 0
	for id in game.inventory: game.inventory[id] = 0
	assert(not game.cook(), "Une recette sans ingrédients doit échouer")
	assert(game.customer_state == "arriving")
	var start = game.customer_x
	game.update_customers(1)
	assert(game.customer_x < start, "Le client doit marcher jusqu'au comptoir")
	game.update_customers(10)
	assert(game.customer_state == "waiting")
	for i in range(3):
		game.order = i
		game.selected = i
		for id in game.recipe(i).ingredients: game.inventory[id] += 1
		assert(game.cook(), "La recette doit réussir avec ses ingrédients")
		assert(game.serve(), "Le client doit recevoir sa commande")
		assert(game.customer_state == "leaving")
		assert(not game.serve(), "Impossible de servir deux fois un client en départ")
		var previous_actor = game.actor_customer
		game.update_customers(10)
		assert(game.actor_customer != previous_actor)
		assert(game.customer_state == "arriving")
		game.update_customers(10)
		assert(game.customer_state == "waiting")
	assert(game.served == 3)
	assert(game.coins == 42)
	assert(game.completed)
	game.player.x = 1090
	game.interact()
	assert(game.upgraded)
	assert(game.coins == 7)
	game.selected = (game.order+1)%3
	for id in game.recipe(game.selected).ingredients: game.inventory[id] += 1
	assert(game.cook())
	assert(not game.serve(), "Une mauvaise commande ne doit pas être vendue")
	game.player.x = 130
	game.cooldowns.moonleaf = 0
	var before = game.inventory.moonleaf
	game.interact()
	assert(game.inventory.moonleaf == before, "Cliquer ouvre le choix, sans récolter automatiquement")
	game.planters.harvest("moonleaf")
	assert(game.inventory.moonleaf == before + 1)
	game.planters.harvest("moonleaf")
	assert(game.inventory.moonleaf == before + 1, "Repousse respectée")
	game.planters.popup.hide()
	game.ui.show_page("inventory")
	assert(game.menu)
	game.ui.hide_page()
	assert(not game.menu)
	game.player_race = "floran"
	game.brightness = 0.8
	game.speed_setting = 2
	game.save_settings()
	game.player_race = "human"
	game.load_settings()
	assert(game.player_race == "floran")
	assert(is_equal_approx(game.brightness, 0.8))
	assert(game.speed_setting == 2)
	game.return_wrap()
	assert(game.holding == -1)
	game.new_service()
	assert(game.served == 0 and game.coins == 0 and not game.upgraded)
	assert(game.sheet.beds.size() == 6)
	assert(not game.recipe_unlocked(3))
	game.travel("garden",140)
	game.interact()
	game.planters.harvest("bed1")
	game.planters.popup.hide()
	assert(game.inventory.moonleaf == 2)
	game.travel("planet",420)
	game.interact()
	assert("starlime" in game.discovered)
	assert(game.inventory.starlime == 2)
	assert(not game.harvest_node(game.sheet.wild_nodes[0]), "Une plante ne peut pas être récoltée deux fois immédiatement")
	game.player.x = 1080
	game.interact()
	assert(game.recipe_unlocked(3))
	game.player.x = 1720
	game.interact()
	assert(game.recipe_unlocked(4))
	assert(game.discovered.size() == 6)
	game.travel("office",830)
	game.coins = 60
	var old = game.inventory.starlime
	assert(game.purchase("starlime"))
	assert(game.coins == 45)
	assert(game.inventory.starlime == old, "La livraison ne doit pas être instantanée")
	game.update_deliveries(4.1)
	assert(game.inventory.starlime == old+3)
	game.coins = 0
	assert(not game.purchase("moonleaf"), "Achat refusé sans argent")
	game.coins = 29
	assert(game.purchase("moonleaf"))
	game.player.x = 440
	assert(game.save_at_sofa())
	assert(game.save_at_sofa(), "La sauvegarde doit pouvoir être remplacée")
	game.coins = 999
	game.inventory.starlime = 0
	game.discovered = ["moonleaf","sunfruit","mushroom"]
	assert(game.load_at_sofa())
	assert(game.coins == 23 and game.inventory.starlime == old+3)
	assert(game.deliveries.size() == 1, "Les livraisons en attente doivent être restaurées")
	assert(game.discovered.size() == 6)
	assert(game.room == "office" and game.player.x == 440)
	game.actor_customer = 0
	game.speak_dialogue("greeting")
	assert(not game.speech.is_empty() and game.speech_time>0)
	var original = game.appearance.duplicate(true)
	var pending = game.queued_appearance.duplicate(true)
	var saved = game.snapshot()
	game.appearance = game.roll_appearance()
	game.apply_snapshot(saved)
	assert(game.appearance == original and game.queued_appearance == pending)
	var hats := {}
	var races := {}
	var forms := {}
	var variations := {}
	game.customer_rng.seed = 42
	for iteration in range(500):
		var previous = game.actor_customer
		game.choose_customer()
		assert(game.customer != previous)
		game.actor_customer = game.customer
		races[game.customer] = true
		var look = game.queued_appearance
		assert(look.size >= 0.9 and look.size <= 1.13)
		hats[look.hats] = true
		forms[look.tentacle_forms] = true
		variations[JSON.stringify(look)] = true
		game.next_order()
		assert(game.recipe_unlocked(game.order))
	assert(hats.size()==6 and races.size()==7 and forms.size()==3 and variations.size()==500)
	game.new_service()
	assert(game.restaurant_level()==0 and not game.recipe_unlocked(5))
	game.served=3
	assert(game.restaurant_level()==1 and game.recipe_unlocked(5))
	game.selected=5
	for id in game.recipe(5).ingredients: game.inventory[id]=1
	game.player.x=745
	game.interact()
	assert(game.ui.page=="cookdrink")
	assert(game.cook())
	game.ui.hide_page()
	assert(game.holding==5 and game.inventory.moonleaf==0)
	game.customer_state="waiting"
	game.order=5
	assert(game.serve())
	assert(game.coins==19)
	game.served=8
	assert(game.restaurant_level()==2 and not game.recipe_unlocked(6))
	game.discovered.append_array(["starlime","firepepper"])
	assert(game.recipe_unlocked(6))
	game.selected=6
	for id in game.recipe(6).ingredients: game.inventory[id]=1
	assert(game.cook() and game.holding==6)
	game.customer_state="waiting"
	game.order=6
	assert(game.chat_with_customer("bonjour"))
	assert(game.chat_log.size()==2)
	assert(game.chat_with_customer("ma commande ?"))
	assert(game.recipe(6).name in game.chat_log[-1])
	var full=game.snapshot()
	game.chat_log.clear()
	game.served=0
	game.apply_snapshot(full)
	assert(game.chat_log.size()==4 and game.restaurant_level()==2)
	game.customer_state="leaving"
	assert(not game.chat_with_customer("bonjour"))
	game.served=15
	assert(game.restaurant_level()==3)
	game.ui.show_page("chat")
	game.ui.show_page("progress")
	game.new_service()
	print("PASS : recettes, clients, inventaire, options, six bacs, exploration, trois découvertes, recettes débloquées, achat/livraison, solde insuffisant, sauvegarde remplacée et chargement complet, dialogues, 500 apparences, progression, boissons, chat et persistance.")
	quit(0)
