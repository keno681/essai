extends SceneTree
func _initialize() -> void: run.call_deferred()
func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	assert(root.get_texture().get_image().save_png("user://captures/"+name+".png")==OK)
func run() -> void:
	var game=load("res://main.gd").new(); root.add_child(game)
	game.new_service(); game.ui.hide_page(); game.served=8
	for number in [8,4,1]:
		game.customer_state="waiting"; game.customer_x=946
		game.order=5 if number==1 else 0 if number==8 else 1
		assert(game.tables.welcome(number))
	for i in range(3): game.tables._process(20)
	game.room="restaurant"; game.player.x=650
	for id in game.discovered:
		if not game.ingredient(id).get("pantry",false): game.inventory["raw_"+id]=3
	game.ui.show_page("cookwrap")
	await capture("cuisine-unifiee")
	game.queue_free(); await process_frame; quit()
