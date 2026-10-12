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
	bench.place_crop("sunfruit"); bench.tap(); bench.tap()
	assert(game.inventory.sunfruit==0 and bench.hits==2)
	bench.tap(); assert(game.inventory.sunfruit==1 and game.inventory.raw_sunfruit==1 and bench.crop=="")
	bench.tap(); assert(game.inventory.sunfruit==1)
	bench.place_crop("moonleaf"); bench.use_tool("press"); assert(not bench.processed)
	bench.use_tool("knife"); assert(game.inventory.moonleaf==1)
	await process_frame
	var click=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=false
	kitchen.icons[0]._gui_input(click); kitchen.icons[1]._gui_input(click)
	assert(kitchen.chosen.size()==2 and kitchen.match_index==0 and "2/2" in kitchen.caption.text)
	assert(not kitchen.prepare.disabled and not kitchen.store.disabled)
	print("PASS fun kitchen: three gestures, exact stock, correct tools, no repeated reward, click assembly, live order checklist, drag compatibility")
	game.queue_free(); await process_frame; quit()
