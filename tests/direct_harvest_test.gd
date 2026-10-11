extends SceneTree
func _initialize() -> void: run.call_deferred()
func wait_for(condition: Callable) -> void:
	var start:=Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<12000: await create_timer(0.02).timeout
	assert(condition.call())
func run() -> void:
	var host=load("res://main.gd").new(); root.add_child(host)
	host.new_service(); host.ui.hide_page()
	host.planters.open("moonleaf")
	assert(host.inventory.moonleaf==3 and host.planters.plants.moonleaf=="")
	assert(not is_instance_valid(host.planters.popup) and not host.menu)
	host.planters.open("moonleaf")
	assert(is_instance_valid(host.planters.popup) and host.menu)
	host.planters.plant("moonleaf","moonleaf")
	await process_frame
	assert(not host.menu)
	host.planters.open("moonleaf")
	assert(host.inventory.moonleaf==3 and not host.menu)
	host.cooldowns.moonleaf=0
	host.planters.open("moonleaf")
	assert(host.inventory.moonleaf==6 and host.planters.plants.moonleaf=="")
	host.new_service(); host.ui.hide_page()
	var guest=load("res://main.gd").new(); root.add_child(guest)
	guest.new_service(); guest.ui.hide_page()
	host.online.host(); guest.online.join("127.0.0.1",host.online.password)
	await wait_for(func(): return guest.online.authenticated)
	guest.player.x=float(host.ingredient("moonleaf").x)
	guest.planters.open("moonleaf")
	await wait_for(func(): return not guest.online.pending and guest.inventory.moonleaf==3)
	assert(host.inventory.moonleaf==3 and host.planters.plants.moonleaf=="")
	assert(not is_instance_valid(guest.planters.popup) and not guest.menu)
	host.online.leave(); guest.online.leave()
	host.queue_free(); guest.queue_free(); await process_frame
	print("PASS direct harvest: one click yields three, no menu, growth preserved, empty-bed seeds, planting closes menu, coop no automatic popup")
	quit()
