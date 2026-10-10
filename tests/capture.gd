extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://main.gd").new()
	root.add_child(game)
	game.menu = false
	game.player.x = 715
	game.holding = 0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("/tmp/cosmo-gameplay.png")
	print("Gameplay capture result: ", error)
	quit(error)
