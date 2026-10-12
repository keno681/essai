extends SceneTree
const PREP=preload("res://ingredient_prep.gd")
const KITCHEN=preload("res://kitchen_dragdrop.gd")
func _initialize() -> void: run.call_deferred()
func find_type(node: Node, type: Script) -> Node:
	if node.get_script()==type: return node
	for child in node.get_children():
		var found=find_type(child,type)
		if found: return found
	return null
func run() -> void:
	var game=load("res://main.gd").new(); root.add_child(game); game.new_service(); game.ui.hide_page()
	game.inventory.raw_sunfruit=2; game.inventory.raw_moonleaf=2
	game.customer_state="waiting"; game.customer_x=946; game.order=0; assert(game.tables.welcome(8)); game.tables.selected=8
	game.ui.show_page("cookwrap"); await process_frame
	var bench=find_type(game.ui,PREP.Bench); var kitchen=find_type(game.ui,KITCHEN.Kitchen)
	bench.place_crop("sunfruit"); bench.use_tool("knife")
	var stroke=InputEventMouseMotion.new(); stroke.position=bench.board.center(); stroke.relative=Vector2(0,40); stroke.button_mask=MOUSE_BUTTON_MASK_LEFT
	bench.board._gui_input(stroke); bench.board._gui_input(stroke)
	assert(game.inventory.sunfruit==0 and bench.progress==0.5)
	bench.gesture(Vector2(0,40)); bench.gesture(Vector2(0,40)); assert(bench.processed and game.inventory.sunfruit==0); bench.commit_current(); assert(game.inventory.sunfruit==1 and game.inventory.raw_sunfruit==1 and bench.crop=="")
	bench.commit_current(); assert(game.inventory.sunfruit==1)
	bench.place_crop("moonleaf"); bench.use_tool("press"); assert(not bench.processed)
	bench.use_tool("knife")
	for i in range(4): bench.gesture(Vector2(0,40))
	bench.commit_current(); assert(game.inventory.moonleaf==1)
	await process_frame
	var click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=false
	kitchen.icons[0]._gui_input(click); kitchen.icons[1]._gui_input(click)
	assert(kitchen.chosen.size()==2 and kitchen.match_index==0 and "2/2" in kitchen.caption.text)
	assert(not kitchen.prepare.disabled and not kitchen.store.disabled)
	for id in ["starlime","crystalrice"]:
		game.inventory["raw_"+id]=1
		var before: int=game.inventory[id]
		bench.place_crop(id); bench.use_tool(PREP.tool_for(id))
		for i in range(4): bench.gesture(Vector2(40,0))
		assert(bench.processed and game.inventory[id]==before)
		bench.commit_current(); assert(game.inventory[id]==before+1 and game.inventory["raw_"+id]==0)
	print("PASS fun kitchen: tool selection and physical gestures, exact stock, correct tools, no repeated reward, click assembly, live order checklist, drag compatibility")
	game.queue_free(); await process_frame; quit()
