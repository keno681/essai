extends SceneTree
var host_game: Node
var guest_game: Node
func _initialize() -> void:
	run.call_deferred()
func wait_for(condition: Callable, seconds: float=5) -> void:
	var start := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-start<int(seconds*1000): await create_timer(0.02).timeout
	if not condition.call():
		push_error("Condition réseau expirée")
		quit(1)
		await create_timer(100).timeout
func run() -> void:
	host_game=load("res://main.gd").new()
	guest_game=load("res://main.gd").new()
	root.add_child(host_game)
	root.add_child(guest_game)
	host_game.new_service()
	guest_game.new_service()
	host_game.order=0
	host_game.menu=true
	guest_game.menu=true
	guest_game.coins=987
	var solo_coins: int=guest_game.coins
	host_game.online.host()
	host_game.ui.show_page("online")
	assert(host_game.online.active)
	guest_game.online.join("127.0.0.1",host_game.online.password)
	await wait_for(func(): return guest_game.online.authenticated and host_game.online.authenticated)
	await wait_for(func(): return guest_game.coins==host_game.coins)
	assert(host_game.online.partner_id!=0)
	# A paused host menu must not stop the shared simulation.
	await wait_for(func(): return host_game.customer_state=="waiting")
	guest_game.room="restaurant"
	guest_game.player=Vector2(130,505)
	guest_game.planters.harvest("moonleaf")
	await wait_for(func(): return not guest_game.online.pending)
	assert(host_game.inventory.moonleaf==3)
	await wait_for(func(): return guest_game.inventory.moonleaf==3)
	# Two harvesters cannot take the same ready crop twice.
	guest_game.planters.harvest("moonleaf")
	await wait_for(func(): return not guest_game.online.pending)
	assert(host_game.inventory.moonleaf==3)
	guest_game.player=Vector2(270,505)
	guest_game.planters.harvest("sunfruit")
	await wait_for(func(): return not guest_game.online.pending)
	assert(host_game.inventory.sunfruit==3)
	guest_game.player=Vector2(650,505)
	guest_game.selected=0
	guest_game.cook()
	await wait_for(func(): return not guest_game.online.pending)
	await wait_for(func(): return guest_game.holding==0)
	assert(host_game.holding==-1)
	assert(host_game.inventory.moonleaf==2 and host_game.inventory.sunfruit==2)
	host_game.selected=0
	host_game.inventory.moonleaf=0
	assert(not host_game.cook())
	guest_game.player=Vector2(host_game.customer_x,505)
	guest_game.serve()
	await wait_for(func(): return not guest_game.online.pending)
	assert(host_game.served==1)
	await wait_for(func(): return guest_game.served==1 and guest_game.holding==-1)
	assert(host_game.coins==12)
	# An incorrect drink served by the guest is consumed, without revenue.
	host_game.customer_state="waiting"
	host_game.order=0
	host_game.online.partner.holding=5
	host_game.online.send_world()
	await wait_for(func(): return guest_game.holding==5 and guest_game.customer_state=="waiting")
	guest_game.player=Vector2(host_game.customer_x,505)
	guest_game.serve()
	await wait_for(func(): return not guest_game.online.pending and guest_game.holding==-1)
	assert(host_game.customer_emotion=="angry" and host_game.customer_state=="leaving")
	assert(host_game.coins==12 and host_game.served==1)
	await wait_for(func(): return guest_game.customer_emotion=="angry")
	# Pass a wrap to the other chef, then back, without duplicating ingredients.
	host_game.inventory.moonleaf=1
	host_game.inventory.sunfruit=1
	host_game.online.send_world()
	await wait_for(func(): return guest_game.inventory.moonleaf==1)
	guest_game.player=Vector2(650,505)
	guest_game.cook()
	await wait_for(func(): return not guest_game.online.pending and guest_game.holding==0)
	guest_game.online.handoff()
	await wait_for(func(): return not guest_game.online.pending and guest_game.holding==-1)
	assert(host_game.holding==0)
	host_game.online.handoff()
	await wait_for(func(): return guest_game.holding==0)
	assert(host_game.holding==-1)
	guest_game.return_wrap()
	await wait_for(func(): return not guest_game.online.pending and guest_game.holding==-1)
	assert(host_game.inventory.moonleaf==1 and host_game.inventory.sunfruit==1)
	# Different rooms and races remain local; partner renders in the matching room.
	guest_game.travel("planet",850)
	guest_game.player_race="avian"
	await wait_for(func(): return host_game.online.partner.get("room","")=="planet")
	assert(host_game.room=="restaurant")
	guest_game.player=Vector2(420,505)
	guest_game.harvest_node(guest_game.sheet.wild_nodes[0])
	await wait_for(func(): return not guest_game.online.pending)
	assert("starlime" in host_game.discovered)
	await wait_for(func(): return "starlime" in guest_game.discovered)
	assert(host_game.inventory.starlime==2)
	# Return to offline play must restore the guest's solo save.
	guest_game.online.leave()
	assert(guest_game.coins==solo_coins)
	await wait_for(func(): return not host_game.online.authenticated)
	assert(host_game.online.active)
	# Bad password and mismatching version cannot enter the restaurant.
	guest_game.online.join("127.0.0.1","incorrect")
	await wait_for(func(): return not guest_game.online.active)
	assert(not host_game.online.authenticated)
	await wait_for(func(): return host_game.online.partner_id==0)
	guest_game.online.join("127.0.0.1",host_game.online.password)
	await wait_for(func(): return guest_game.online.authenticated)
	guest_game.room="restaurant"
	guest_game.player=Vector2(130,505)
	guest_game.planters.empty("moonleaf")
	await wait_for(func(): return not guest_game.online.pending)
	assert(host_game.planters.plants.moonleaf=="")
	var seed_before: int=host_game.seed_count("mushroom")
	guest_game.planters.plant("moonleaf","mushroom")
	await wait_for(func(): return not guest_game.online.pending)
	assert(host_game.planters.plants.moonleaf=="mushroom")
	assert(host_game.seed_count("mushroom")==seed_before-1)
	await wait_for(func(): return guest_game.seed_count("mushroom")==seed_before-1)
	host_game.planters.plant("moonleaf","mushroom")
	assert(host_game.seed_count("mushroom")==seed_before-1)
	assert(host_game.planters.timer("moonleaf")>0)
	guest_game.player=Vector2(650,505)
	guest_game.cook()
	await wait_for(func(): return not guest_game.online.pending and guest_game.holding==0)
	var carry_save: Dictionary=host_game.snapshot()
	assert(carry_save.coop_carried==0)
	host_game.online.leave()
	assert(not host_game.online.active)
	assert(host_game.inventory.moonleaf==1 and host_game.inventory.sunfruit==1)
	host_game.apply_snapshot(carry_save)
	assert(host_game.inventory.moonleaf==1 and host_game.inventory.sunfruit==1)
	await wait_for(func(): return not guest_game.online.active)
	assert(guest_game.coins==solo_coins)
	print("PASS COOP : connexion privee, stocks partages, recolte concurrente, cuisine, service, monnaie, pieces independantes, exploration, replantation, transfert de commande, fermeture du salon, restauration solo et mot de passe refuse")
	host_game.queue_free()
	guest_game.queue_free()
	await process_frame
	quit()
