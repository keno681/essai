extends SceneTree
func _initialize() -> void: run.call_deferred()
func wait_for(condition: Callable) -> void:
	var start:=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<12000: await create_timer(0.02).timeout
	assert(condition.call())
func run() -> void:
	var game=load("res://main.gd").new(); root.add_child(game); game.new_service(); game.ui.hide_page()
	assert(game.dayflow.number==1 and game.dayflow.limit()==5 and game.order==0)
	assert("1/5" in game.guide_step().text)
	game.ui.show_page("tutorial"); await process_frame; game.ui.hide_page()
	game.customer_state="waiting"; game.customer_x=946
	assert(game.tables.welcome(8)); assert("2/5" in game.guide_step().text)
	game.planters.open("moonleaf"); game.planters.open("sunfruit")
	assert("3/5" in game.guide_step().text)
	assert(game.prepare_crop("moonleaf") and game.prepare_crop("sunfruit"))
	assert("4/5" in game.guide_step().text)
	game.selected=0; assert(game.cook()); assert("5/5" in game.guide_step().text)
	game.new_service(); game.ui.hide_page()
	for number in range(1,6):
		game.customer_state="waiting"; game.customer_x=946
		assert(game.order in [0,1]); assert(game.tables.welcome(number))
	assert(game.dayflow.admitted==5 and game.customer_state=="closed" and game.customer_queue.people.is_empty())
	game.customer_state="waiting"; assert(not game.tables.welcome(6)); game.customer_state="closed"
	for i in range(3): game.tables._process(20)
	for number in range(1,6):
		game.holding=int(game.tables.person(number).recipe) if number<5 else 5
		assert(game.tables.serve_table(number))
	assert(game.dayflow.resolved==5 and game.dayflow.happy==4 and game.dayflow.number==1)
	assert(not game.dayflow.next_day())
	for i in range(3): game.tables._process(20)
	game.dayflow.tick(); assert(game.ui.page=="day_end")
	var saved: Dictionary=game.snapshot(); game.dayflow.reset(); game.apply_snapshot(saved)
	assert(game.dayflow.number==1 and game.dayflow.resolved==5 and game.customer_state=="closed")
	var coins: int=game.coins; game.inventory.raw_sunfruit=2
	assert(game.dayflow.next_day()); assert(game.dayflow.number==2 and game.coins==coins and game.inventory.raw_sunfruit==2)
	game.new_service(); game.ui.hide_page(); game.online.host()
	var guest=load("res://main.gd").new(); root.add_child(guest); guest.new_service(); guest.ui.hide_page()
	guest.online.join("127.0.0.1",game.online.password); await wait_for(func(): return guest.online.authenticated)
	game.customer_state="waiting"; game.customer_x=946; game.online.send_world()
	await wait_for(func(): return guest.customer_state=="waiting")
	guest.player.x=946; guest.tables.welcome(8)
	await wait_for(func(): return not guest.online.pending and guest.dayflow.admitted==1)
	assert(game.dayflow.admitted==1)
	game.tables.reset(); game.dayflow.admitted=5; game.dayflow.resolved=5; game.customer_state="closed"; game.online.send_world()
	await wait_for(func(): return guest.dayflow.resolved==5)
	game.ui.show_page("day_end"); guest.dayflow.next_day()
	await wait_for(func(): return not guest.online.pending and guest.dayflow.number==2)
	await wait_for(func(): return not game.menu)
	assert(game.dayflow.number==2)
	game.online.leave(); guest.online.leave(); game.queue_free(); guest.queue_free(); await process_frame
	print("PASS day one: five simple orders only, tutorial, closed queue, correct/wrong resolution, departure before summary, save, next-day stock retention, guest day sync and next day")
	quit()
