extends SceneTree
const PREP=preload("res://ingredient_prep.gd")
func _initialize() -> void: run.call_deferred()
func find_bench(node: Node) -> Node:
	if node is PREP.Bench: return node
	for child in node.get_children():
		var found=find_bench(child)
		if found: return found
	return null
func run() -> void:
	var game=load("res://main.gd").new(); root.add_child(game); game.new_service(); game.ui.show_page("cookwrap"); await process_frame
	var bench=find_bench(game.ui)
	await process_frame
	assert(bench.bowl.size==Vector2(112,82))
	for id in ["sunfruit","moonleaf","starlime","crystalrice"]:
		game.inventory["raw_"+id]=1
		var before: int=game.inventory[id]
		bench.selected_tool=""; bench.place_crop(id)
		var click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true; click.position=bench.board.center()
		bench.board._gui_input(click); assert(game.inventory[id]==before and game.inventory["raw_"+id]==1)
		var motion=InputEventMouseMotion.new(); motion.relative=Vector2(200,0); motion.position=bench.board.center()
		for i in range(5): bench.board._gui_input(motion)
		assert(game.inventory[id]==before)
		var index: int=["knife","press","sieve"].find(PREP.tool_for(id))
		click.position=bench.board.rack(index).get_center(); bench.board._gui_input(click)
		assert(game.inventory[id]==before)
		click.position=bench.board.center(); bench.board._gui_input(click)
		assert(game.inventory[id]==before+1 and game.inventory["raw_"+id]==0 and bench.last_crop==id)
		bench.board._gui_input(click); assert(game.inventory[id]==before+1)
	assert(bench.raw_texture("sunfruit")!=bench.ready_texture("sunfruit"))
	assert(bench.raw_texture("moonleaf")!=bench.ready_texture("moonleaf"))
	assert(bench.raw_texture("starlime")!=bench.ready_texture("starlime"))
	print("PASS click preparation: select tool then food, no hover treatment, wrong/missing tool rejected, exact stock, raw/ready distinct art")
	game.queue_free(); await process_frame; quit()
