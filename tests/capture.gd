extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.gd").new()
	root.add_child(game)
	game.ui.hide_page()
	game.actor_customer = 4
	game.customer = 4
	game.customer_x = 946
	game.customer_state = "waiting"
	game.player.x = 715
	game.holding = 0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("/tmp/cosmo-gameplay.png")
	game.ui.show_page("inventory")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cosmo-inventory.png")
	game.ui.show_page("options")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cosmo-options.png")
	game.ui.show_page("menu")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cosmo-menu.png")
	print("Gameplay capture result: ", error)
	quit(error)
