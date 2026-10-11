extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://main.gd").new(); root.add_child(game)
	game.new_service(); game.ui.hide_page()
	for number in [8,4]:
		game.customer_state="waiting"; game.customer_x=946; game.order=0
		assert(game.tables.welcome(number))
	for i in range(3): game.tables._process(20)
	game.inventory.moonleaf=3; game.inventory.sunfruit=3
	game.selected=0
	assert(game.cook_store(8)); assert(game.cook_store(4))
	assert(game.holding==-1 and game.counter_items.size()==2)
	assert(game.inventory.moonleaf==1 and game.inventory.sunfruit==1)
	assert(game.tables.status(game.tables.person(8))=="Prêt au comptoir")
	var saved: Dictionary=game.snapshot()
	game.counter_items.clear(); game.apply_snapshot(saved)
	assert(game.counter_items.size()==2)
	var first: int=game.counter_items[0].id
	assert(game.take_order(first)); assert(not game.take_order(first))
	assert(game.counter_items.size()==1 and game.holding==0)
	assert(game.tables.serve_table(8))
	assert(game.tables.person(4).state=="waiting" and game.counter_items.size()==1)
	assert(game.take_order(int(game.counter_items[0].id)))
	assert(game.tables.serve_table(4))
	assert(game.coins==24 and game.served==2 and game.counter_items.is_empty())
	game.restore_counter([{"id":7,"recipe":5,"table":1},{"id":7,"recipe":0,"table":4},{"id":8,"recipe":-1,"table":4}])
	assert(game.counter_items.size()==1)
	assert(game.take_order(7) and game.holding==5)
	game.holding=-1
	game.ui.show_page("cookwrap"); await process_frame
	game.ui.show_page("counter"); await process_frame
	assert(game.clicked_target(Vector2(845,470)).action=="counter")
	game.new_service(); assert(game.counter_items.is_empty())
	print("PASS counter: multiple orders, ingredients charged once, save/load, distinct table delivery, duplicate pickup rejected, drinks, UI, reset")
	game.queue_free(); await process_frame; quit()
