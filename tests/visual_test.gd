extends SceneTree

var game: Node

func _initialize() -> void:
	run.call_deferred()

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://captures")
	assert(image.save_png("user://captures/"+name+".png") == OK)

func kitchen_node(node: Node) -> Node:
	if node.has_method("remove_ingredient"): return node
	for child in node.get_children():
		var found := kitchen_node(child)
		if found: return found
	return null

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(1).timeout
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1200,720))
	game.ui.hide_page()
	game.room = "restaurant"
	game.player = Vector2(590,505)
	game.customer_state = "waiting"
	game.customer_x = 850
	await capture("restaurant-harmonise")
	# Every crop, including the original plant, now responds to growth and emptying.
	assert(game.planters.defaults.size() == 9)
	game.planters.empty("moonleaf")
	assert(game.planters.plants.moonleaf == "")
	assert(game.planters.popup.size.x < 260)
	assert(game.planters.popup.size.y < 310)
	await capture("bac-compact")
	game.planters.plant("moonleaf", "mushroom")
	assert(game.planters.plants.moonleaf == "mushroom")
	assert(game.planters.timer("moonleaf") > 0)
	game.planters.popup.hide()
	var before: int = int(game.inventory.mushroom)
	game.planters.set_timer("moonleaf",0)
	game.planters.harvest("moonleaf")
	assert(game.inventory.mushroom == before+3)
	game.planters.popup.hide()
	var state: Dictionary = game.snapshot()
	game.planters.plants.moonleaf = "sunfruit"
	game.apply_snapshot(state)
	assert(game.planters.plants.moonleaf == "")
	game.room = "garden"
	game.player = Vector2(590,505)
	game.camera_x = 0
	await capture("serre-harmonisee")
	game.room = "restaurant"
	game.holding = -1
	game.order = 0
	game.inventory.moonleaf = 5
	game.inventory.sunfruit = 5
	game.ui.set_meta("wrap_composition",[])
	game.ui.show_page("cookwrap")
	await process_frame
	var kitchen := kitchen_node(game.ui.window)
	assert(kitchen != null)
	await process_frame
	for icon in kitchen.icons: assert(icon.size == Vector2(76,76))
	var data := {"ingredient":"moonleaf", "kitchen":kitchen, "from_wrap":false}
	assert(kitchen.plate._can_drop_data(Vector2(130,100),data))
	assert(not kitchen.plate._can_drop_data(Vector2.ZERO,data))
	kitchen.plate._drop_data(Vector2(120,110),data)
	data.ingredient = "sunfruit"
	kitchen.plate._drop_data(Vector2(150,95),data)
	assert(kitchen.match_index == 0)
	await capture("cuisine-harmonisee")
	kitchen.prepare.pressed.emit()
	assert(game.holding == 0)
	assert(game.inventory.moonleaf == 4 and game.inventory.sunfruit == 4)
	game.holding = -1
	game.served = 8
	game.discovered = ["moonleaf","sunfruit","mushroom","starlime","firepepper","crystalrice"]
	game.ui.set_meta("wrap_composition",[])
	game.ui.show_page("cookdrink")
	await capture("boissons-harmonisees")
	game.ui.show_page("console")
	await capture("pokeball-harmonisee")
	game.ui.show_page("inventory")
	await capture("inventaire-harmonise")
	game.ui.show_page("menu")
	await capture("menu-harmonise")
	game.ui.hide_page()
	game.room="planet"
	game.player=Vector2(1100,505)
	game.camera_x=850
	await capture("planete-harmonisee")
	print("PASS: cultures, menu compact, sauvegarde, glisser-deposer, recette, stocks, boissons, console et inventaire")
	game.queue_free()
	await process_frame
	quit()
