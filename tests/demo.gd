extends SceneTree

var game: Node2D
var frames := 0

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	game = load("res://main.gd").new()
	root.add_child(game)
	game.ui.hide_page()
	game.customer = 5
	game.actor_customer = 5
	game.player.x = 838
	game.facing = 1
	game.order = 0
	game.coins = 0
	game.served = 0

func _process(_delta: float) -> bool:
	if not is_instance_valid(game): return false
	frames += 1
	if frames==110:
		game.selected = 0
		for id in game.recipe(0).ingredients: game.inventory[id] = 1
		game.cook()
	if frames==130: game.serve()
	if frames>=335: quit(0)
	return false
