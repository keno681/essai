extends SceneTree
var game: Node
var role := ""
var shared := ""
var fail_apply := false
var drinks := false
var seeds := false
var test_root := ""
var was_resume := false
var injected := false
var last_state := "INITIAL"
func _initialize() -> void:
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--role="): role=value.trim_prefix("--role=")
		if value.begins_with("--shared="): shared=value.trim_prefix("--shared=")
		if value=="--fail-apply": fail_apply=true
		if value=="--drinks": drinks=true
		if value=="--seeds": seeds=true
		if value.begins_with("--test-root="): test_root=value.trim_prefix("--test-root=")
	process_frame.connect(inject_failure)
	run.call_deferred()
func inject_failure() -> void:
	if is_instance_valid(game) and game.online and game.online.updates.state!=last_state:
		last_state=game.online.updates.state
		print("SYNC STATE "+role+" : "+last_state+" · "+game.console_node.status)
	if fail_apply and role=="guest" and not was_resume and not injected and is_instance_valid(game) and game.online and game.online.updates.state=="await_commit":
		game.online.updates.patch="invalid json for simulated application failure"
		injected=true
func wait_for(condition: Callable, seconds: float=90) -> void:
	var begin := Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec()-begin<int(seconds*1000): await create_timer(0.02).timeout
	if not condition.call():
		push_error("Sync test expired : "+role)
		quit(1)
func marker(name: String) -> void:
	var file=FileAccess.open(shared+"/"+name,FileAccess.WRITE)
	file.store_string("ok"); file.close()
func run() -> void:
	was_resume=FileAccess.file_exists(ProjectSettings.globalize_path("res://.console-runtime/coop-resume.json"))
	game=load("res://main.gd").new()
	root.add_child(game)
	if not was_resume:
		game.new_service()
		game.ui.hide_page()
		game.menu=true
		if role=="host":
			game.coins=123
			game.inventory.moonleaf=1
			game.inventory.sunfruit=1
			game.online.password="sync-test-secret"
			game.online.host()
			await wait_for(func(): return game.online.authenticated)
			game.online.partner.holding=0
			game.online.send_world()
			await wait_for(func(): return FileAccess.file_exists(shared+"/guest-ready"))
			var patch := {"format":"cosmowrap-patch-v1","title":"Couleur commune","files":[{"path":"ui.gd","old":"var CYAN = Color(\"edc478\")","new":"var CYAN = Color(\"63b8ad\")"}]}
			game.console_node.draft=FileAccess.get_file_as_string(test_root+"/downloads/Graines-Pokeball.json") if seeds else FileAccess.get_file_as_string(test_root+"/downloads/Ingredients-Boissons-Pokeball.json") if drinks else JSON.stringify(patch)
			game.console_node.send_and_restart()
			print("SYNC BEGIN : "+game.online.updates.state+" · "+game.console_node.status)
			if game.online.updates.state.is_empty(): push_error(game.console_node.status); quit(1); return
			await create_timer(95).timeout
			push_error("Host did not restart"); quit(1)
		else:
			game.coins=777
			game.online.join("127.0.0.1","sync-test-secret")
			await wait_for(func(): return game.online.authenticated and game.coins==123 and game.holding==0)
			marker("guest-ready")
			await create_timer(95).timeout
			push_error("Guest did not restart"); quit(1)
		return
	await wait_for(func(): return game.online.authenticated and game.online.updates.state.is_empty())
	var expected := "edc478" if fail_apply or drinks or seeds else "63b8ad"
	assert(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://ui.gd")).contains('var CYAN = Color("'+expected+'")'))
	assert(game.coins==123)
	if seeds:
		assert(game.inventory.has("seed_moonleaf") and game.seed_count("moonleaf")==3)
		assert(game.ingredient("moonleaf").has("seed_price"))
	if drinks:
		assert(game.inventory.has("mineralwater"))
		assert(game.recipe(6).ingredients==["mineralwater","nebulasyrup","starlime"])
		assert(FileAccess.file_exists("res://art/drink_ingredients.svg"))
	assert(game.inventory.moonleaf==1 and game.inventory.sunfruit==1)
	if role=="host":
		assert(game.holding==-1)
		assert(game.online.partner.holding==0)
		marker("host-reconnected")
		await wait_for(func(): return FileAccess.file_exists(shared+"/guest-reconnected"))
		game.online.leave()
		assert(game.inventory.moonleaf==2 and game.inventory.sunfruit==2)
		await wait_for(func(): return FileAccess.file_exists(shared+"/guest-done"))
		marker("host-done")
		print("PASS sync host : "+("rollback" if fail_apply else "apply"))
	else:
		assert(game.holding==0)
		await wait_for(func(): return FileAccess.file_exists(shared+"/host-reconnected"))
		marker("guest-reconnected")
		await wait_for(func(): return not game.online.active)
		assert(game.coins==777)
		game.save_progress()
		marker("guest-done")
		print("PASS sync guest : "+("rollback" if fail_apply else "apply"))
	quit()
