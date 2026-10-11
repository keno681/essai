extends SceneTree
func _initialize() -> void: run.call_deferred()
func ready_customer(game: Node, recipe_index: int) -> void:
	game.customer_state="waiting"
	game.customer_x=946
	game.order=recipe_index
func run() -> void:
	var game=load("res://main.gd").new()
	root.add_child(game)
	game.new_service()
	game.ui.hide_page()
	ready_customer(game,0)
	assert(game.tables.welcome(8))
	ready_customer(game,1)
	assert(game.tables.welcome(4))
	assert(game.tables.people.size()==2 and not game.tables.welcome(4))
	for i in range(3): game.tables._process(20)
	assert(game.tables.person(8).state=="waiting" and game.tables.person(4).state=="waiting")
	game.tables.select_table(8)
	assert(game.selected==0 and game.ui.page=="cookwrap")
	game.ui.hide_page()
	game.inventory.moonleaf=1; game.inventory.sunfruit=1
	assert(game.cook())
	game.room="dining"
	assert(game.tables.serve_table(8))
	assert(game.coins==12 and game.served==1 and game.holding==-1)
	assert(game.tables.person(8).state=="eating")
	assert(not game.tables.serve_table(8))
	assert(game.tables.person(4).state=="waiting")
	var saved: Dictionary=game.snapshot()
	game.tables.reset()
	game.apply_snapshot(saved)
	assert(game.room=="dining" and game.tables.people.size()==2)
	game.holding=5
	assert(game.tables.serve_table(4))
	assert(game.tables.person(4).emotion=="angry" and game.coins==12 and game.served==1)
	game.ui.hide_page()
	for i in range(3): game.tables._process(20)
	assert(game.tables.people.is_empty())
	game.dayflow.number=2; game.dayflow.admitted=0; game.dayflow.resolved=0; game.dayflow.happy=0
	for number in range(1,9):
		ready_customer(game,0)
		assert(game.tables.welcome(number))
	assert(game.tables.free_tables().is_empty())
	ready_customer(game,0)
	assert(not game.tables.welcome(8))
	assert(game.tables.people.size()==8)
	var old: Dictionary=game.snapshot(); old.erase("table_orders"); old.erase("selected_table")
	game.apply_snapshot(old)
	assert(game.tables.people.is_empty())
	game.room="restaurant"
	ready_customer(game,0)
	var target: Dictionary=game.clicked_target(Vector2(946,420))
	assert(target.action=="welcome")
	game.start_click_action(Vector2(946,420)); game.finish_click_action()
	assert(game.ui.page=="reception")
	game.ui.hide_page()
	game.room="dining"
	assert(game.clicked_target(Vector2(940,535)).table==8)
	print("PASS tables: 8/4 independent orders, choose/cook/serve, angry wrong drink, no double payment, seating, full room, save and click targets")
	game.queue_free()
	await process_frame
	quit()
