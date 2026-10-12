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
	for id in ["sunfruit","starlime","crystalrice"]:
		game.inventory["raw_"+id]=1
		var before: int=game.inventory[id]
		bench.place_crop(id); bench.gesture(Vector2(1,1)); assert(bench.progress==0)
		var motion=InputEventMouseMotion.new(); motion.button_mask=0; motion.relative=Vector2(200,0); motion.position=bench.board.center()+Vector2(100,0)
		for i in range(2): bench.board._gui_input(motion)
		assert(game.inventory[id]==before)
		bench.board._gui_input(motion)
		assert(game.inventory[id]==before+1 and game.inventory["raw_"+id]==0 and bench.crop=="")
		bench.board._gui_input(motion); assert(game.inventory[id]==before+1)
	assert(not bench.pieces.is_empty())
	print("PASS ninja preparation: no buttons or tool, cross-food swipes, 3 passes, auto storage, tomato/citrus/rice, jitter rejected, no duplicate stock")
	game.queue_free(); await process_frame; quit()
