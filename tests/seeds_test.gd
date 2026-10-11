extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://main.gd").new()
	root.add_child(game)
	game.new_service()
	game.ui.hide_page()
	assert(game.seed_count("moonleaf")==3)
	game.planters.harvest("moonleaf")
	assert(game.inventory.moonleaf==3 and game.planters.plants.moonleaf=="")
	game.planters.harvest("moonleaf")
	assert(game.inventory.moonleaf==3)
	game.planters.plant("moonleaf","moonleaf")
	assert(game.seed_count("moonleaf")==2 and game.planters.timer("moonleaf")>0)
	game.planters.harvest("moonleaf")
	assert(game.inventory.moonleaf==3)
	game.cooldowns.moonleaf=0
	game.planters.harvest("moonleaf")
	assert(game.inventory.moonleaf==6 and game.planters.plants.moonleaf=="")
	game.inventory.seed_moonleaf=0
	game.planters.plant("moonleaf","moonleaf")
	assert(game.planters.plants.moonleaf=="")
	game.coins=100
	var stock: int=game.inventory.moonleaf
	assert(game.purchase("moonleaf"))
	assert(game.seed_count("moonleaf")==0 and game.coins==94)
	game.update_deliveries(4.1)
	assert(game.seed_count("moonleaf")==3 and game.inventory.moonleaf==stock)
	assert(not game.purchase("mineralwater"))
	for id in ["lunartea","nebulasyrup"]:
		assert(game.purchase(id))
		game.update_deliveries(4.1)
		game.planters.plant("moonleaf",id)
		assert(game.seed_count(id)==2)
		game.cooldowns.moonleaf=0
		game.planters.harvest("moonleaf")
		assert(game.inventory[id]==3 and game.planters.plants.moonleaf=="")
	var saved: Dictionary=game.snapshot()
	game.inventory.seed_moonleaf=0
	game.apply_snapshot(saved)
	assert(game.seed_count("moonleaf")==3)
	assert(game.planters.plants.moonleaf=="")
	for item in game.sheet.ingredients: saved.inventory.erase("seed_"+item.id)
	game.apply_snapshot(saved)
	assert(game.seed_count("moonleaf")==3 and game.seed_count("lunartea")==0)
	print("PASS seeds: consume one seed, yield three, empty beds, growth, no seed refusal, seed-only deliveries, tea/berries, save migration")
	game.queue_free()
	await process_frame
	quit()
