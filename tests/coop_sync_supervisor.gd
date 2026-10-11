extends "res://launcher.gd"
func start_game() -> void:
	var arguments=["--headless","--audio-driver","Dummy","--path",game_root,"--script",driver_path(),"--","--console-managed"]
	arguments.append_array(OS.get_cmdline_user_args())
	pid=OS.create_process(OS.get_executable_path(),arguments)
	if pid<0: get_tree().quit(1)

func driver_path() -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--test-root="): return value.trim_prefix("--test-root=")+"/tests/coop_sync_driver.gd"
	return ""
