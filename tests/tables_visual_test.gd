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
	game.room="dining"; game.player.x=1090
	await capture("salle-orbitale")
	game.ui.show_page("orders")
	await capture("carnet-commandes")
	game.ui.hide_page(); game.room="restaurant"; game.player.x=650
	game.tables.select_table(8)
	await capture("cuisine-table-8")
	assert(game.tables.people.size()==3 and game.tables.selected==8)
	print("PASS visual tables: dining room, eight numbers, order book, table-specific kitchen")
	game.queue_free(); await process_frame; quit()
