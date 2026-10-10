extends SceneTree

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var game = load("res://main.gd").new()
	root.add_child(game)
	game.coins = 0
	game.served = 0
	game.order = 0
	game.customer = 0
	game.upgraded = false
	game.holding = -1
	game.selected = 0
	for id in game.inventory: game.inventory[id] = 0
	assert(not game.cook(), "Une recette sans ingrédients doit échouer")
	for i in range(3):
		game.selected = i
		for id in game.recipe(i).ingredients: game.inventory[id] += 1
		assert(game.cook(), "La recette doit réussir avec ses ingrédients")
		assert(game.serve(), "Le client doit recevoir sa commande")
	assert(game.served == 3)
	assert(game.coins == 42)
	assert(game.completed)
	game.player.x = 1090
	game.interact()
	assert(game.upgraded)
	assert(game.coins == 7)
	game.selected = 1
	for id in game.recipe(1).ingredients: game.inventory[id] += 1
	assert(game.cook())
	assert(not game.serve(), "Une mauvaise commande ne doit pas être vendue")
	game.player.x = 130
	game.cooldowns.moonleaf = 0
	var before = game.inventory.moonleaf
	game.interact()
	assert(game.inventory.moonleaf == before + 1)
	game.interact()
	assert(game.inventory.moonleaf == before + 1, "Repousse respectée")
	print("PASS : 3 recettes, service, objectif, terrasse, refus commande incorrecte, récolte et repousse.")
	quit(0)
