extends SceneTree
func _initialize() -> void: run.call_deferred()
func find_view(node: Node) -> Node:
	if node.has_method("clear_preparation"): return node
	for child in node.get_children():
		var found=find_view(child)
		if found: return found
	return null
func run() -> void:
	var game=load("res://main.gd").new()
	root.add_child(game)
	game.new_service()
	game.served=8
	for id in game.inventory: game.inventory[id]=4
	for kind in ["wrap","drink"]:
		game.ui.show_page("cookwrap" if kind=="wrap" else "cookdrink")
		var view=find_view(game.ui.window)
		var id: String="moonleaf" if kind=="wrap" else "mineralwater"
		var data={"kitchen":view,"ingredient":id}
		assert(view.prepare.disabled)
		assert(view.plate._can_drop_data(Vector2(130,100),data))
		view.plate._drop_data(Vector2(130,100),data)
		assert(not view.prepare.disabled)
		assert(not view.plate._can_drop_data(Vector2(130,100),data))
		assert(view.plate._get_drag_data(Vector2(130,100))==null)
		view.remove_ingredient(id)
		assert(id in view.chosen)
		assert(game.discard_preparation(kind,view.chosen.duplicate()))
		assert(game.inventory[id]==3)
		view.clear_preparation(); view.refresh()
		assert(view.prepare.disabled)
		view.plate._drop_data(Vector2(130,100),data)
		view.prepare.pressed.emit()
		assert(game.holding>=0 and game.inventory[id]==2)
		assert(game.recipe(game.holding).get("custom",false))
		assert(game.ui.get_meta("composition_"+kind).is_empty())
		assert(game.discard_order() and game.inventory[id]==2)
		game.ui.show_page("cookwrap" if kind=="wrap" else "cookdrink")
		view=find_view(game.ui.window)
		assert(view.chosen.is_empty())
	for i in range(50): game.next_order(); assert(not game.recipe(game.order).get("custom",false))
	assert(not game.discard_preparation("wrap",["moonleaf","moonleaf"]))
	print("PASS kitchen: single ingredient wrap/drink enabled, permanent drops, consumed discards, crafted drafts cleared, normal client menu")
	game.queue_free()
	await process_frame
	quit()
