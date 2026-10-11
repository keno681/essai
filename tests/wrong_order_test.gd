extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game=load("res://main.gd").new()
	root.add_child(game)
	for received in [1,5,6]:
		game.new_service()
		game.customer_state="waiting"
		game.order=0
		game.holding=received
		game.coins=40
		var stock: Dictionary=game.inventory.duplicate()
		assert(game.serve())
		assert(game.holding==-1 and game.coins==40 and game.served==0)
		assert(game.customer_emotion=="angry" and game.customer_state=="leaving")
		assert(game.speech.contains("J’ai demandé") and game.inventory==stock)
		assert(not game.serve())
		var saved: Dictionary=game.snapshot()
		game.apply_snapshot(saved)
		assert(game.customer_emotion=="angry" and game.customer_state=="leaving")
		game.update_customers(20)
		assert(game.customer_state=="arriving" and game.customer_emotion=="calm")
	game.new_service()
	game.customer_state="waiting"
	game.order=0
	game.holding=0
	assert(game.serve() and game.served==1 and game.coins>0)
	print("PASS: wrong wraps and drinks consumed without payment, angry exit, save, next client and normal sales")
	game.queue_free()
	await process_frame
	quit()
