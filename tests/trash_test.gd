extends SceneTree
func _initialize() -> void: run.call_deferred()
func wait_for(condition: Callable) -> void:
	var start:=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<12000: await create_timer(0.02).timeout
	assert(condition.call())
func run() -> void:
	var host=load("res://main.gd").new(); root.add_child(host)
	host.new_service(); host.ui.hide_page(); host.holding=0
	var stocks: Dictionary=host.inventory.duplicate()
	var target: Dictionary=host.clicked_target(Vector2(1007,500))
	assert(target.action=="trash" and host.object_hover_name(target)=="Poubelle")
	assert(host.start_click_action(Vector2(1007,500)))
	host.finish_click_action()
	assert(host.holding==-1 and not host.menu and host.inventory==stocks)
	assert(not host.discard_order(true))
	host.holding=5; host.interact()
	assert(host.holding==-1 and host.inventory==stocks)
	host.online.host()
	var guest=load("res://main.gd").new(); root.add_child(guest); guest.new_service(); guest.ui.hide_page()
	guest.online.join("127.0.0.1",host.online.password)
	await wait_for(func(): return guest.online.authenticated)
	host.holding=1; host.online.partner.holding=5; host.online.send_world()
	await wait_for(func(): return guest.holding==5)
	guest.player.x=650; guest.discard_order(true)
	await wait_for(func(): return not guest.online.pending)
	assert(guest.holding==5)
	guest.player.x=1007; guest.discard_order(true)
	await wait_for(func(): return not guest.online.pending and guest.holding==-1)
	assert(host.holding==1 and host.online.partner.holding==-1 and not guest.menu and host.inventory==stocks)
	host.online.leave(); guest.online.leave(); host.queue_free(); guest.queue_free(); await process_frame
	print("PASS trash: click target, immediate disposal without menu, wraps/drinks, no refund, empty hands, guest disposal and host holding preserved, distance validation")
	quit()
