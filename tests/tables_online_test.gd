extends SceneTree
var host_game: Node
var guest_game: Node
func _initialize() -> void: run.call_deferred()
func wait_for(condition: Callable) -> void:
	var start:=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<12000: await create_timer(0.02).timeout
	assert(condition.call())
func run() -> void:
	host_game=load("res://main.gd").new(); root.add_child(host_game)
	guest_game=load("res://main.gd").new(); root.add_child(guest_game)
	host_game.new_service(); guest_game.new_service()
	host_game.online.host()
	guest_game.online.join("127.0.0.1",host_game.online.password)
	await wait_for(func(): return guest_game.online.authenticated)
	host_game.customer_state="waiting"; host_game.customer_x=946; host_game.order=0
	host_game.online.send_world()
	await wait_for(func(): return guest_game.customer_state=="waiting" and guest_game.order==0)
	guest_game.player.x=946
	guest_game.tables.welcome(8)
	assert(host_game.tables.welcome(8))
	await wait_for(func(): return not guest_game.online.pending and guest_game.tables.people.size()==1)
	assert(host_game.tables.people.size()==1)
	host_game.customer_state="waiting"; host_game.customer_x=946; host_game.order=1
	host_game.online.send_world()
	await wait_for(func(): return guest_game.customer_state=="waiting" and guest_game.order==1)
	guest_game.tables.welcome(4)
	await wait_for(func(): return not guest_game.online.pending and guest_game.tables.people.size()==2)
	await wait_for(func(): return host_game.tables.person(8).get("state")=="waiting" and host_game.tables.person(4).get("state")=="waiting")
	host_game.inventory.moonleaf=1; host_game.inventory.sunfruit=1
	host_game.online.send_world()
	await wait_for(func(): return guest_game.inventory.moonleaf==1)
	guest_game.player.x=650; guest_game.selected=0; guest_game.cook()
	await wait_for(func(): return not guest_game.online.pending and guest_game.holding==0)
	guest_game.travel("dining",940)
	guest_game.tables.serve_table(8)
	await wait_for(func(): return not guest_game.online.pending and guest_game.holding==-1)
	assert(host_game.coins==12 and host_game.served==1 and host_game.tables.person(4).state=="waiting")
	await wait_for(func(): return guest_game.tables.person(8).get("state")=="eating")
	host_game.online.partner.holding=5
	host_game.online.send_world()
	await wait_for(func(): return guest_game.holding==5)
	guest_game.tables.serve_table(4)
	await wait_for(func(): return not guest_game.online.pending and guest_game.holding==-1)
	assert(host_game.coins==12 and host_game.tables.person(4).emotion=="angry")
	await wait_for(func(): return guest_game.tables.person(4).get("emotion")=="angry")
	assert(host_game.online.partner.room=="dining")
	host_game.online.leave()
	await wait_for(func(): return not guest_game.online.active)
	assert(guest_game.tables.people.is_empty())
	print("PASS online tables: concurrent welcome, two distinct orders, guest cooks/serves, shared payment, wrong drink anger, dining movement, solo restore")
	host_game.queue_free(); guest_game.queue_free()
	await process_frame
	quit()
