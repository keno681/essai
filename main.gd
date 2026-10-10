extends Node2D

var sheet: Dictionary
var inventory: Dictionary = {}
var cooldowns: Dictionary = {}
var player := Vector2(565, 505)
var vertical := 0.0
var selected := 0
var customer := 0
var order := 0
var coins := 0
var served := 0
var upgraded := false
var holding := -1
var message := "Bienvenue ! Récoltez à gauche, cuisinez à droite."
var message_time := 8.0
var clock := 0.0
var walk_cycle := 0.0
var walking := false
var facing := 1.0
var action_time := 0.0
var backdrop: Texture2D
var menu := true
var completed := false
var font: Font = ThemeDB.fallback_font
var ui: CanvasLayer
var race_texture: Texture2D
var player_race := "human"
var customer_state := "arriving"
var customer_x := 1250.0
var actor_customer := 0
var npc_cycle := 0.0
var fullscreen := false
var sound_enabled := true
var brightness := 1.0
var speed_setting := 1
var sound_player: AudioStreamPlayer

func _ready() -> void:
	sheet = JSON.parse_string(FileAccess.get_file_as_string("res://data/design.json"))
	for item in sheet.ingredients:
		inventory[item.id] = 0
		cooldowns[item.id] = 0.0
	load_progress()
	load_settings()
	actor_customer = customer
	race_texture = load("res://art/races.png")
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	ui = load("res://ui.gd").new()
	add_child(ui)
	var art_path: String = "res://" + sheet.visuals[0].asset
	if ResourceLoader.exists(art_path):
		backdrop = load(art_path)

func animation(id: String) -> Dictionary:
	for row in sheet.animations:
		if row.id == id: return row
	return {}

func recipe(index: int) -> Dictionary:
	return sheet.recipes[index]

func say(words: String) -> void:
	message = words
	message_time = 5.0

func cook() -> bool:
	if holding >= 0:
		say("Vous portez déjà un wrap. Servez-le au comptoir !")
		return false
	for ingredient in recipe(selected).ingredients:
		if inventory[ingredient] < 1:
			say("Il manque des ingrédients : faites un tour au jardin !")
			return false
	for ingredient in recipe(selected).ingredients:
		inventory[ingredient] -= 1
	holding = selected
	action_time = float(animation("cook").duration)
	play_sound(440)
	say("Wrap prêt ! Direction le comptoir.")
	return true

func serve() -> bool:
	if customer_state != "waiting":
		say("Le prochain client arrive. Attendez-le au comptoir.")
		return false
	if holding < 0:
		say("Votre client attend " + recipe(order).name + ".")
		return false
	if holding != order:
		say("Ce n'est pas sa commande. 1 / 2 / 3 : choisissez la bonne recette ; R : ranger ce wrap.")
		return false
	coins += int(recipe(order).price) + (5 if upgraded else 0)
	served += 1
	action_time = float(animation("serve").duration)
	holding = -1
	customer_state = "leaving"
	play_sound(740)
	customer = (customer + 1) % sheet.customers.size()
	order = (order + 1) % sheet.recipes.size()
	if served == 3:
		completed = true
		say("Premier service réussi ! Continuez et agrandissez votre restaurant.")
	else:
		say("Merci ! Un client heureux, un pourboire intergalactique.")
	save_progress()
	return true

func interact() -> void:
	for item in sheet.ingredients:
		if absf(player.x - float(item.x)) < 58:
			if cooldowns[item.id] > 0:
				say("Ça repousse tranquillement… Essayez une autre plante.")
			else:
				inventory[item.id] += 1
				play_sound(320)
				action_time = float(animation("harvest").duration)
				cooldowns[item.id] = float(item.regrow_seconds)
				say("+1 " + item.name)
			return
	if absf(player.x - 650) < 65:
		cook()
	elif absf(player.x - 845) < 65:
		serve()
	elif absf(player.x - 1090) < 65:
		if upgraded:
			say("Votre terrasse est déjà ouverte ! +5 crédits par commande.")
		elif coins >= 35:
			coins -= 35
			upgraded = true
			save_progress()
			say("Terrasse ouverte ! +5 crédits par commande.")
		else:
			say("La terrasse coûte 35 crédits. Encore quelques wraps !")
	else:
		say("Approchez d'une plante ou d'un poste, puis appuyez sur E.")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_ESCAPE:
		if menu: ui.hide_page()
		else: ui.show_page("menu")
	elif event.keycode == KEY_I:
		if menu and ui.page == "inventory": ui.hide_page()
		else: ui.show_page("inventory")
	elif menu and event.keycode in [KEY_ENTER,KEY_SPACE]:
		ui.hide_page()
	elif not menu:
		match event.keycode:
			KEY_1: selected = 0
			KEY_2: selected = 1
			KEY_3: selected = 2
			KEY_E: interact()
			KEY_SPACE:
				if player.y >= 505: vertical = -450
			KEY_R: return_wrap()
			KEY_N: ui.show_page("confirm")

func return_wrap() -> void:
	if holding >= 0:
		for ingredient in recipe(holding).ingredients: inventory[ingredient] += 1
		holding = -1
		say("Ingrédients rangés : rien n'est perdu.")

func new_service() -> void:
	coins = 0
	served = 0
	upgraded = false
	completed = false
	customer = 0
	actor_customer = 0
	order = 0
	holding = -1
	customer_state = "arriving"
	customer_x = 1250
	for id in inventory:
		inventory[id] = 0
		cooldowns[id] = 0.0
	save_progress()
	say("Nouveau service !")

func update_customers(delta: float) -> void:
	var flow: Dictionary = sheet.systems[2]
	if customer_state == "arriving":
		customer_x = move_toward(customer_x,float(flow.waiting_x),float(flow.speed)*delta)
		npc_cycle += delta*float(animation("walk").frequency)
		if is_equal_approx(customer_x,float(flow.waiting_x)):
			customer_state = "waiting"
			say(sheet.customers[customer].name+" commande "+recipe(order).name+".")
	elif customer_state == "leaving":
		customer_x = move_toward(customer_x,float(flow.exit_x),float(flow.speed)*delta)
		npc_cycle += delta*float(animation("walk").frequency)
		if is_equal_approx(customer_x,float(flow.exit_x)):
			actor_customer = customer
			customer_x = float(flow.spawn_x)
			customer_state = "arriving"

func _process(delta: float) -> void:
	if not menu:
		clock += delta
		update_customers(delta)
		var axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_LEFT))
		walking = absf(axis) > 0
		if walking:
			facing = signf(axis)
			walk_cycle += delta * float(animation("walk").frequency)
		action_time = maxf(0.0, action_time - delta)
		player.x = clampf(player.x + axis * [180,240,310][speed_setting] * delta, 40, 1160)
		vertical += 1100 * delta
		player.y = minf(505, player.y + vertical * delta)
		if player.y >= 505: vertical = 0
		for id in cooldowns: cooldowns[id] = maxf(0, cooldowns[id] - delta)
		message_time -= delta
	queue_redraw()

func save_progress() -> void:
	var file := FileAccess.open("user://progress.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"coins":coins,"served":served,"upgraded":upgraded,"customer":customer,"order":order}))

func load_progress() -> void:
	if not FileAccess.file_exists("user://progress.json"): return
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://progress.json"))
	if saved is Dictionary:
		coins = maxi(0, int(saved.get("coins", 0)))
		served = maxi(0, int(saved.get("served", 0)))
		upgraded = bool(saved.get("upgraded", false))
		customer = posmod(int(saved.get("customer", 0)), sheet.customers.size())
		order = posmod(int(saved.get("order", 0)), 3)
		completed = served >= 3

func label_at(words: String, position: Vector2, size: int = 18, color: Color = Color("dce8ef")) -> void:
	draw_string(font, position, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, color: Color, radius: int = 14) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style, rect)

func alien(position: Vector2, color: Color, chef: bool = false) -> void:
	if not race_texture: return
	var race_id: String = player_race if chef else sheet.customers[actor_customer].race
	var race_index := 0
	var sprite_row: Dictionary = sheet.races[0]
	for row in sheet.races:
		if row.id == race_id:
			race_index = int(row.sprite_index)
			sprite_row = row
	var moving := walking if chef else customer_state != "waiting"
	var phase := walk_cycle if chef else npc_cycle
	var stride := sin(phase)*0.2 if moving else 0.0
	var direction := facing if chef else (1.0 if customer_state=="leaving" else -1.0)
	var breathe := sin(clock*2.0)*1.2
	var bob := absf(cos(phase))*2 if moving else breathe
	var foot := position+Vector2(0,39)
	var cell := Vector2(float(sprite_row.source_width),race_texture.get_height())
	var source_x := float(sprite_row.source_x)
	var height := 152.0
	var width := height*cell.x/cell.y
	var cut := 0.76
	draw_set_transform(foot,0,Vector2(1.6,0.28))
	draw_circle(Vector2.ZERO,20,Color(0.03,0.02,0.01,0.35))
	# Split the HD sheet into an upper body and two leg pieces for cutout motion.
	for side in [0,1]:
		var hip := Vector2((side-0.5)*width*0.5,-height*(1-cut)+bob)
		var angle := stride*(-1 if side==0 else 1)
		draw_set_transform(foot+Vector2(hip.x*direction,hip.y),angle*direction,Vector2(direction,1))
		draw_texture_rect_region(race_texture,Rect2(-width*0.25,0,width*0.5,height*(1-cut)),Rect2(source_x+cell.x*side*0.5,cell.y*cut,cell.x*0.5,cell.y*(1-cut)))
	var gesture := sin(action_time*22)*0.025 if chef and action_time>0 else 0.0
	draw_set_transform(foot+Vector2(0,bob),gesture,Vector2(direction,1))
	draw_texture_rect_region(race_texture,Rect2(-width*0.5,-height,width,height*cut),Rect2(source_x,0,cell.x,cell.y*cut))
	if chef and holding>=0:
		panel(Rect2(9,-65,25,16),Color("efd1a0"),4)
		draw_line(Vector2(12,-62),Vector2(29,-62),Color("679958"),4,true)
		draw_line(Vector2(16,-62),Vector2(26,-62),Color("c4583f"),3,true)
	if not chef and customer_state=="leaving":
		panel(Rect2(9,-65,25,16),Color("efd1a0"),4)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if sheet.is_empty(): return
	if backdrop:
		draw_texture_rect(backdrop,Rect2(0,0,float(sheet.visuals[0].width),float(sheet.visuals[0].height)),false,Color(brightness,brightness,brightness))
	else:
		draw_rect(Rect2(0,190,1200,420),Color("463e39"))
	# Soft room lighting and active stations stay legible without covering the art.
	for item in sheet.ingredients:
		var x := float(item.x)
		if cooldowns[item.id] > 0:
			panel(Rect2(x-23,455,46,22),Color("332f29"),6)
			label_at("%ds" % ceili(cooldowns[item.id]),Vector2(x-11,471),14,Color("e4c69b"))
		if absf(player.x-x)<58 and not menu:
			panel(Rect2(x-64,393,128,30),Color("302b27"),6)
			label_at("E · Récolter",Vector2(x-47,413),17,Color("f9d47b"))
		label_at(item.name,Vector2(x-64,594),14,Color("edd8b7"))
	for station in sheet.stations:
		var x := float(station.x)
		if absf(player.x-x)<65 and not menu:
			panel(Rect2(x-62,383,124,29),Color("302b27"),6)
			label_at("E · "+station.name,Vector2(x-53,403),16,Color("f9d47b"))
	label_at("CUISINE",Vector2(615,594),14,Color("edd8b7"))
	label_at("COMPTOIR",Vector2(809,594),14,Color("edd8b7"))
	label_at("TERRASSE OUVERTE" if upgraded else "TERRASSE · 35 CR",Vector2(1030,594),13,Color("edd8b7"))
	# Heat drifting from the grill, with gentle ambient light movement.
	for i in range(5):
		var rise := fmod(clock*22+i*17,78)
		draw_arc(Vector2(628+sin(clock+i)*8,407-rise),9,0.2,2.4,14,Color(1,0.92,0.76,(1-rise/78)*0.13),2,true)
	if upgraded:
		draw_circle(Vector2(1127,432),26,Color(1,0.7,0.3,0.1))
		label_at("+5 / wrap",Vector2(1060,366),16,Color("f9d47b"))
	alien(Vector2(customer_x,505),Color(sheet.customers[actor_customer].color))
	alien(player,Color("bca2e9"),true)
	panel(Rect2(803,205,367,77),Color("eee2c9"),10)
	label_at((sheet.customers[customer].name+" · "+recipe(order).name) if customer_state=="waiting" else ("Merci, à bientôt !" if customer_state=="leaving" else "Un client arrive…"),Vector2(818,232),19,Color("44382e"))
	label_at(sheet.customers[actor_customer].line,Vector2(818,254),13,Color("685446"))
	label_at("Client patient · Prenez votre temps",Vector2(818,273),12,Color("8b7055"))

func save_settings() -> void:
	var file := FileAccess.open("user://settings.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"race":player_race,"fullscreen":fullscreen,"sound":sound_enabled,"brightness":brightness,"speed":speed_setting}))

func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"): return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	if not data is Dictionary: return
	for race in sheet.races:
		if race.id==data.get("race","human"): player_race=race.id
	sound_enabled = bool(data.get("sound",true))
	brightness = clampf(float(data.get("brightness",1)),0.55,1.25)
	speed_setting = clampi(int(data.get("speed",1)),0,2)
	set_fullscreen(bool(data.get("fullscreen",false)))

func set_fullscreen(value: bool) -> void:
	fullscreen = value
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	save_settings()

func play_sound(frequency: float) -> void:
	if not sound_enabled or not is_instance_valid(sound_player): return
	var bytes := PackedByteArray()
	for i in range(5000):
		var sample := int(sin(i*frequency*TAU/22050.0)*6000*(1.0-i/5000.0))
		bytes.append(sample & 255)
		bytes.append((sample >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	sound_player.stream = stream
	sound_player.play()
