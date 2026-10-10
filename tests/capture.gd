extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.gd").new()
	root.add_child(game)
	game.ui.hide_page()
	game.appearance = game.roll_appearance()
	game.appearance.hats = "fez"
	game.appearance.tentacle_counts = 3
	game.appearance.glasses = "round"
	game.actor_customer = 4
	game.customer = 4
	game.customer_x = 946
	game.customer_state = "waiting"
	game.served=8
	game.discovered.append_array(["starlime","firepepper"])
	game.player.x = 715
	game.holding = 0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("/tmp/cosmo-gameplay.png")
	game.chat_with_customer("bonjour")
	game.chat_with_customer("ma commande ?")
	game.ui.show_page("chat")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cosmo-chat.png")
	game.ui.show_page("ai")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cosmo-ai.png")
	game.ui.show_page("progress")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cosmo-progress.png")
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
	game.ui.hide_page()
	for target in ["office","garden","planet"]:
		game.travel(target,440 if target=="office" else (600 if target=="garden" else 1080))
		game.camera_x = 480 if target=="planet" else 0
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/cosmo-"+target+".png")
	game.travel("office",440)
	game.ui.show_page("save")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cosmo-save.png")
	game.ui.show_page("shop")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/cosmo-shop.png")
	print("Gameplay capture result: ", error)
	quit(error)
