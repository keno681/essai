extends SceneTree
const KITCHEN=preload("res://kitchen_dragdrop.gd")
const PREP=preload("res://ingredient_prep.gd")
func _initialize() -> void: run.call_deferred()
func wait_for(condition: Callable) -> void:
	var start:=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<12000: await create_timer(0.02).timeout
	assert(condition.call())
func run() -> void:
	var game=load("res://main.gd").new(); root.add_child(game)
	game.new_service(); game.ui.hide_page()
	game.planters.open("sunfruit")
	assert(game.inventory.raw_sunfruit==3 and game.inventory.sunfruit==0)
	game.ui.show_page("cookwrap"); await process_frame
	var bench: Node
	bench=find_bench(game.ui)
	assert(bench!=null and bench.compact and bench.cells.size()==8)
	assert(bench.cells.sunfruit.food.visible and game.inventory.sunfruit==0)
	game.inventory.raw_crystalrice=2
	await process_frame
	assert(bench.cells.crystalrice.food.visible and "2 bruts" in bench.cells.crystalrice.label.text)
	var board: Control=bench.board
	var raw={"bench":bench,"type":"raw","id":"sunfruit"}
	assert(board._can_drop_data(Vector2.ZERO,raw)); board._drop_data(Vector2.ZERO,raw)
	bench.gesture(Vector2(1,1)); assert(not bench.processed and bench.progress==0)
	assert(board._get_drag_data(Vector2.ZERO)==null)
	var knife={"bench":bench,"type":"tool","id":"knife"}
	assert(board._can_drop_data(Vector2.ZERO,knife)); board._drop_data(Vector2.ZERO,knife)
	for i in range(2): bench.gesture(Vector2(0,40))
	assert(not bench.processed and game.inventory.sunfruit==0)
	var bowl: Control=bench.bowl
	var result={"bench":bench,"type":"processed","id":"sunfruit"}
	assert(not bowl._can_drop_data(Vector2.ZERO,result)); bench.gesture(Vector2(0,40))
	assert(game.inventory.sunfruit==1 and game.inventory.raw_sunfruit==2 and bench.crop=="")
	assert(not bowl._can_drop_data(Vector2.ZERO,result))
	await process_frame
	assert("2 bruts" in bench.cells.sunfruit.label.text and game.ui.page=="cookwrap")
	var kitchen=find_kitchen(game.ui)
	assert(kitchen!=null and kitchen.compact)
	assert(kitchen.stocks[1].text=="TOMATE × 1" and kitchen.icons[1].modulate.a==1.0)
	for id in PREP.TOOLS:
		game.inventory["raw_"+id]=1
		assert(game.prepare_crop(id)); assert(game.inventory["raw_"+id]==0)
	assert(not game.prepare_crop("sunfruit")); assert(not game.prepare_crop("mineralwater"))
	var save: Dictionary=game.snapshot(); game.inventory.raw_sunfruit=7; game.apply_snapshot(save)
	assert(game.inventory.raw_sunfruit==0)
	game.ui.hide_page(); game.online.host()
	var guest=load("res://main.gd").new(); root.add_child(guest); guest.new_service(); guest.ui.hide_page()
	guest.online.join("127.0.0.1",game.online.password); await wait_for(func(): return guest.online.authenticated)
	game.inventory.raw_sunfruit=1; game.inventory.sunfruit=0; game.online.send_world()
	await wait_for(func(): return guest.inventory.raw_sunfruit==1)
	guest.player.x=650; guest.prepare_crop("sunfruit")
	assert(game.prepare_crop("sunfruit"))
	await wait_for(func(): return not guest.online.pending and guest.inventory.sunfruit==1)
	assert(game.inventory.raw_sunfruit==0 and game.inventory.sunfruit==1)
	game.online.leave(); guest.online.leave(); game.queue_free(); guest.queue_free(); await process_frame
	print("PASS preparation: raw harvest, correct-tool gestures, bowl transfer, no timer, exact stock, all crops, save, concurrent coop stock")
	quit()
func find_bench(node: Node) -> Node:
	if node is PREP.Bench: return node
	for child in node.get_children():
		var found=find_bench(child)
		if found: return found
	return null

func find_kitchen(node: Node) -> Node:
	if node is KITCHEN.Kitchen: return node
	for child in node.get_children():
		var found=find_kitchen(child)
		if found: return found
	return null
