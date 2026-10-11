extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var game=load("res://main.gd").new()
	root.add_child(game)
	game.new_service()
	game.ui.hide_page()
	for _step in range(160): game.update_customers(0.1)
	assert(game.customer_state=="waiting")
	assert(game.customer_queue.people.size()==3)
	var x: float=game.customer_x
	for person in game.customer_queue.people:
		assert(is_equal_approx(float(person.x),x+70))
		x=float(person.x)
	var next: Dictionary=game.customer_queue.people[0].duplicate(true)
	game.holding=game.order
	assert(game.serve())
	assert(game.customer==int(next.customer))
	assert(game.queued_appearance==next.appearance)
	assert(game.customer_queue.people.size()==3)
	var saved: Dictionary=game.snapshot()
	game.apply_snapshot(JSON.parse_string(JSON.stringify(saved)))
	assert(game.customer_queue.reserved.customer==next.customer)
	assert(game.customer_state=="leaving")
	for _step in range(160): game.update_customers(0.1)
	assert(game.customer_state=="waiting")
	assert(game.actor_customer==int(next.customer))
	for key in next.appearance:
		if next.appearance[key] is float:
			assert(is_equal_approx(float(game.appearance[key]),float(next.appearance[key])))
		else: assert(game.appearance[key]==next.appearance[key])
	next=game.customer_queue.people[0].duplicate(true)
	assert(game.dismiss_customer())
	for _step in range(160): game.update_customers(0.1)
	assert(game.customer_state=="waiting")
	assert(game.actor_customer==int(next.customer))
	assert(game.customer_emotion=="calm")
	var old_save: Dictionary=game.snapshot()
	old_save.erase("waiting_queue")
	game.apply_snapshot(old_save)
	assert(game.customer_queue.people.size()==3)
	print("PASS: FIFO, espace entre clients, service, depart en colere, sauvegarde et ancienne sauvegarde")
	game.queue_free()
	await process_frame
	quit()
