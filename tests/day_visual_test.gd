extends SceneTree
func _initialize() -> void: run.call_deferred()
func capture(name: String) -> void:
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	assert(root.get_texture().get_image().save_png("user://captures/"+name+".png")==OK)
func run() -> void:
	var game=load("res://main.gd").new(); root.add_child(game); game.new_service()
	game.ui.show_page("tutorial"); await capture("tutoriel-jour-1")
	game.ui.hide_page(); game.customer_state="waiting"; game.customer_x=946
	await capture("guide-accueil")
	game.queue_free(); await process_frame; quit()
