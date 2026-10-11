extends SceneTree
func _initialize() -> void: run.call_deferred()
func kitchen(node: Node) -> Node:
	if node.has_method("remove_ingredient"): return node
	for child in node.get_children():
		var found := kitchen(child)
		if found: return found
	return null
func run() -> void:
	var game=load("res://main.gd").new()
	root.add_child(game)
	game.new_service()
	game.served=8
	game.discovered.append("starlime")
	for id in game.inventory: game.inventory[id]=2
	game.ui.show_page("cookdrink")
	var view := kitchen(game.ui.window)
	assert(not "moonleaf" in view.allowed and not "firepepper" in view.allowed)
	assert(view.shown.size()==4)
	assert(not view.plate._can_drop_data(Vector2(130,100),{"kitchen":view,"ingredient":"moonleaf"}))
	for id in ["mineralwater","nebulasyrup","starlime"]:
		var data := {"kitchen":view,"ingredient":id}
		assert(view.plate._can_drop_data(Vector2(130,100),data))
		view.plate._drop_data(Vector2(130,100),data)
	assert(view.match_index==6)
	view.prepare.pressed.emit()
	assert(game.holding==6 and game.inventory.moonleaf==2)
	assert(game.inventory.mineralwater==1 and game.inventory.nebulasyrup==1 and game.inventory.starlime==1)
	game.return_wrap()
	game.ui.show_page("cookwrap")
	view=kitchen(game.ui.window)
	assert(not "mineralwater" in view.allowed and not "nebulasyrup" in view.allowed)
	assert("moonleaf" in view.allowed and "starlime" in view.allowed)
	assert(view.shown.size()==6)
	game.planters.empty("moonleaf")
	game.planters.plant("moonleaf","mineralwater")
	assert(game.planters.plants.moonleaf=="")
	var saved: Dictionary=game.snapshot()
	for id in ["mineralwater","lunartea","nebulasyrup"]: saved.inventory.erase(id); saved.discovered.erase(id)
	game.apply_snapshot(saved)
	assert(game.inventory.mineralwater==0 and "mineralwater" in game.discovered)
	print("PASS : recettes de boissons, tables separees, rejet salade/eau, stocks, citron commun, bacs et ancienne sauvegarde")
	game.queue_free()
	await process_frame
	quit()
