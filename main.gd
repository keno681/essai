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
var customer_emotion := "calm"
var customer_state := "arriving"
var customer_x := 1250.0
var actor_customer := 0
var npc_cycle := 0.0
var appearance: Dictionary = {}
var queued_appearance: Dictionary = {}
var customer_rng := RandomNumberGenerator.new()
var fullscreen := false
var sound_enabled := true
var brightness := 1.0
var speed_setting := 1
var sound_player: AudioStreamPlayer
var room := "restaurant"
var camera_x := 0.0
var room_textures: Dictionary = {}
var discovered: Array = ["moonleaf","sunfruit","mushroom"]
var node_cooldowns: Dictionary = {}
var deliveries: Array = []
var voice_enabled := true
var speech := ""
var speech_time := 0.0
var speech_elapsed := 0.0
var speech_pid := -1
var chat_log: Array = []
var chat_memory: Dictionary = {}
var dialogue_engine: RefCounted
var accessory_texture: Texture2D
var saving_notice := "Aucune sauvegarde sur ce canapé."

func _ready() -> void:
	get_tree().auto_accept_quit = false
	sheet = JSON.parse_string(FileAccess.get_file_as_string("res://data/design.json"))
	for item in sheet.ingredients:
		inventory[item.id] = 0
		cooldowns[item.id] = 0.0
	for row in sheet.beds + sheet.wild_nodes: node_cooldowns[row.id] = 0.0
	for row in sheet.rooms:
		room_textures[row.id] = load("res://"+row.asset)
	customer_rng.randomize()
	choose_customer()
	actor_customer = customer
	appearance = queued_appearance.duplicate(true)
	next_order()
	dialogue_engine = load("res://dialogue.gd").new()
	load_progress()
	load_settings()
	accessory_texture = load("res://art/accessories.svg")
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

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress()
		if OS.get_name()=="Windows": DisplayServer.tts_stop()
		get_tree().quit()

func recipe(index: int) -> Dictionary:
	return sheet.recipes[index]

func say(words: String) -> void:
	message = words
	message_time = 5.0

func cook() -> bool:
	if holding >= 0:
		say("Vous portez déjà une commande. Servez-le au comptoir !")
		return false
	if not recipe_unlocked(selected):
		say("Cette recette sera débloquée avec votre réputation et vos découvertes.")
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
	say("Commande prête ! Direction le comptoir.")
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
	var previous_level := restaurant_level()
	coins += int(recipe(order).price) + (5 if upgraded else 0) + int(sheet.progression[previous_level].bonus)
	served += 1
	customer_emotion="happy"
	reset_customer_conversation()
	action_time = float(animation("serve").duration)
	holding = -1
	customer_state = "leaving"
	play_sound(740)
	choose_customer()
	next_order()
	speak_dialogue("thanks")
	if served == 3:
		completed = true
		say("Premier service réussi ! Continuez et agrandissez votre restaurant.")
	else:
		say("Merci ! Un client heureux, un pourboire intergalactique.")
	if restaurant_level()>previous_level:
		say("Nouveau rang : "+sheet.progression[restaurant_level()].name+" ! Bonus de vente et nouvelles boissons.")
	save_progress()
	return true

func interact() -> void:
	for door in sheet.doors:
		if door.room==room and absf(player.x-float(door.x))<30:
			travel(door.target,float(door.arrival_x))
			return
	if room=="office":
		if absf(player.x-440)<80: ui.show_page("save")
		elif absf(player.x-830)<80: ui.show_page("shop")
		else: say("Approchez du canapé ou du PC, puis appuyez sur E.")
		return
	if room in ["garden","planet"]:
		for node in sheet.beds if room=="garden" else sheet.wild_nodes:
			if absf(player.x-float(node.x))<62:
				harvest_node(node)
				return
		say("E près d'une plante pour récolter. Explorez vers la droite !")
		return
	for item in sheet.ingredients:
		if not item.starter: continue
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
	if absf(player.x - 745) < 36:
		if recipe(selected).get("kind", "wrap")=="drink": cook()
		else: say("Choisissez une boisson : 6 ou 7, puis E.")
	elif absf(player.x - 650) < 65:
		if recipe(selected).get("kind", "wrap")=="wrap": cook()
		else: say("Les boissons se fabriquent à la machine à droite de la cuisine.")
	elif absf(player.x - 845) < 65:
		serve()
	elif absf(player.x - 1090) < 65:
		if upgraded:
			say("Votre terrasse est déjà ouverte ! +5 wrapcoincoins par commande.")
		elif coins >= 35:
			coins -= 35
			upgraded = true
			save_progress()
			say("Terrasse ouverte ! +5 wrapcoincoins par commande.")
		else:
			say("La terrasse coûte 35 wrapcoincoins. Encore quelques wraps !")
	else:
		say("Approchez d'une plante ou d'un poste, puis appuyez sur E.")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_ESCAPE:
		if menu: ui.hide_page()
		else: ui.show_page("menu")
	elif event.keycode == KEY_T:
		ui.show_page("chat")
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
			KEY_4:
				if recipe_unlocked(3): selected=3
			KEY_5:
				if recipe_unlocked(4): selected=4
			KEY_6:
				if recipe_unlocked(5): selected=5
			KEY_7:
				if recipe_unlocked(6): selected=6
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
	customer_emotion="calm"
	reset_customer_conversation()
	room = "restaurant"
	player.x = 565
	discovered = ["moonleaf","sunfruit","mushroom"]
	deliveries.clear()
	chat_log.clear()
	for id in node_cooldowns: node_cooldowns[id] = 0.0
	coins = 0
	served = 0
	upgraded = false
	completed = false
	choose_customer()
	actor_customer = customer
	appearance = queued_appearance.duplicate(true)
	next_order()
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
			if room=="restaurant": speak_dialogue("greeting")
	elif customer_state == "leaving":
		var hurry := float(sheet.customer_reactions[0].speed_multiplier) if customer_emotion=="angry" else 1.0
		customer_x = move_toward(customer_x,float(flow.exit_x),float(flow.speed)*hurry*delta)
		npc_cycle += delta*float(animation("walk").frequency)
		if is_equal_approx(customer_x,float(flow.exit_x)):
			actor_customer = customer
			customer_emotion="calm"
			reset_customer_conversation()
			appearance = queued_appearance.duplicate(true)
			customer_x = float(flow.spawn_x)
			customer_state = "arriving"

func _process(delta: float) -> void:
	if not menu:
		clock += delta
		if room=="restaurant": update_customers(delta)
		speech_time = maxf(0.0,speech_time-delta)
		speech_elapsed += delta
		update_deliveries(delta)
		var axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_LEFT))
		walking = absf(axis) > 0
		if walking:
			facing = signf(axis)
			walk_cycle += delta * float(animation("walk").frequency)
		action_time = maxf(0.0, action_time - delta)
		player.x = clampf(player.x + axis * [180,240,310][speed_setting] * delta, 40, 3560 if room=="planet" else 1160)
		camera_x = clampf(player.x-600,0,2400) if room=="planet" else 0
		vertical += 1100 * delta
		player.y = minf(505, player.y + vertical * delta)
		if player.y >= 505: vertical = 0
		for id in cooldowns: cooldowns[id] = maxf(0, cooldowns[id] - delta)
		for id in node_cooldowns: node_cooldowns[id] = maxf(0,node_cooldowns[id]-delta)
		message_time -= delta
	queue_redraw()

func save_progress() -> void:
	write_snapshot("user://progress.json")

func load_progress() -> void:
	if not FileAccess.file_exists("user://progress.json"): return
	var saved = JSON.parse_string(FileAccess.get_file_as_string("user://progress.json"))
	if saved is Dictionary: apply_snapshot(saved)

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
	var look: Dictionary = {} if chef else appearance
	var height := 152.0*float(look.get("size",1.0))
	var width := height*cell.x/cell.y
	var cut := 0.76
	draw_set_transform(foot,0,Vector2(1.6,0.28))
	draw_circle(Vector2.ZERO,20,Color(0.03,0.02,0.01,0.35))
	for side in [0,1]:
		var hip := Vector2((side-0.5)*width*0.5,-height*(1-cut)+bob)
		var angle := stride*(-1 if side==0 else 1)
		draw_set_transform(foot+Vector2(hip.x*direction,hip.y),angle*direction,Vector2(direction,1))
		for part in [[0.76,0.92,"pants_colors"],[0.92,1.0,"shoe_colors"]]:
			var start := float(part[0])
			var length := float(part[1])-start
			draw_texture_rect_region(race_texture,Rect2(-width*0.25,height*(start-cut),width*0.5,height*length),Rect2(source_x+cell.x*side*0.5,cell.y*start,cell.x*0.5,cell.y*length),Color(look.get(part[2],"ffffff")))
	var gesture := sin(action_time*22)*0.025 if chef and action_time>0 else 0.0
	draw_set_transform(foot+Vector2(0,bob),gesture,Vector2(direction,1))
	draw_texture_rect_region(race_texture,Rect2(-width*0.5,-height*0.66,width,height*0.42),Rect2(source_x,cell.y*0.34,cell.x,cell.y*0.42),Color(look.get("clothing_colors","ffffff")))
	var head_height := height*0.34*float(look.get("head",1.0))
	var head_width := width*float(look.get("head_width",1.0))
	draw_texture_rect_region(race_texture,Rect2(-head_width*0.5,-height*0.66-head_height,head_width,head_height),Rect2(source_x,0,cell.x,cell.y*0.34),Color(look.get("skin_colors","ffffff")))
	if not chef and not look.is_empty(): draw_accessories(head_width,height*0.66+head_height,look)
	if chef and holding>=0 and recipe(holding).get("kind","wrap")=="drink":
		draw_drink(Vector2(20,-57),Color("a5d5b7") if holding==5 else Color("d08bea"))
	elif chef and holding>=0:
		panel(Rect2(9,-65,25,16),Color("efd1a0"),4)
		draw_line(Vector2(12,-62),Vector2(29,-62),Color("679958"),4,true)
		draw_line(Vector2(16,-62),Vector2(26,-62),Color("c4583f"),3,true)
	if not chef and customer_state=="leaving" and customer_emotion!="angry":
		panel(Rect2(9,-65,25,16),Color("efd1a0"),4)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if sheet.is_empty(): return
	if room!="restaurant":
		draw_other_room()
		return
	if backdrop:
		draw_texture_rect(backdrop,Rect2(0,0,float(sheet.visuals[0].width),float(sheet.visuals[0].height)),false,Color(brightness,brightness,brightness))
	else:
		draw_rect(Rect2(0,190,1200,420),Color("463e39"))
	draw_restaurant_details()
	# Soft room lighting and active stations stay legible without covering the art.
	for item in sheet.ingredients:
		if not item.starter: continue
		var x := float(item.x)
		if cooldowns[item.id] > 0:
			panel(Rect2(x-23,455,46,22),Color("332f29"),6)
			label_at("%ds" % ceili(cooldowns[item.id]),Vector2(x-11,471),14,Color("e4c69b"))
		if absf(player.x-x)<58 and not menu:
			panel(Rect2(x-64,393,128,30),Color("302b27"),6)
			label_at("E · Récolter",Vector2(x-47,413),17,Color("f9d47b"))
		label_at(item.name,Vector2(x-64,594),14,Color("edd8b7"))
	for station in sheet.stations:
		if station.room!=room: continue
		var x := float(station.x)
		if absf(player.x-x)<65 and not menu:
			panel(Rect2(x-62,383,124,29),Color("302b27"),6)
			label_at("E · "+station.name,Vector2(x-53,403),16,Color("f9d47b"))
	label_at("CUISINE",Vector2(615,594),14,Color("edd8b7"))
	label_at("COMPTOIR",Vector2(809,594),14,Color("edd8b7"))
	label_at("TERRASSE OUVERTE" if upgraded else "TERRASSE · 35 WCC",Vector2(1030,594),13,Color("edd8b7"))
	# Heat drifting from the grill, with gentle ambient light movement.
	for i in range(5):
		var rise := fmod(clock*22+i*17,78)
		draw_arc(Vector2(628+sin(clock+i)*8,407-rise),9,0.2,2.4,14,Color(1,0.92,0.76,(1-rise/78)*0.13),2,true)
	if upgraded:
		draw_circle(Vector2(1127,432),26,Color(1,0.7,0.3,0.1))
		label_at("+5 WCC / wrap",Vector2(1060,366),16,Color("f9d47b"))
	alien(Vector2(customer_x,505),Color(sheet.customers[actor_customer].color))
	if customer_emotion=="angry":
		label_at("!",Vector2(customer_x-4,365),27,Color("f28c78"))
	alien(player,Color("bca2e9"),true)
	panel(Rect2(763,205,407,107),Color("eee2c9"),10)
	label_at((sheet.customers[customer].name+" · "+recipe(order).name) if customer_state=="waiting" else (("Client en colère : il s’en va !" if customer_emotion=="angry" else "Merci, à bientôt !") if customer_state=="leaving" else "Un client arrive…"),Vector2(778,232),19,Color("44382e"))
	var excerpt: String = speech.left(105)+"… [T : texte complet]" if speech.length()>130 else speech
	var spoken: String = excerpt.left(int(speech_elapsed*35)) if speech_time>0 else sheet.customers[actor_customer].line
	var words := spoken.split(" ")
	var line := ""
	var row_y := 254
	for word in words:
		if (line+word).length()>53:
			label_at(line,Vector2(778,row_y),13,Color("685446"))
			row_y += 17
			line = ""
		line += word+" "
	label_at(line,Vector2(778,row_y),13,Color("685446"))
	label_at("T : discuter · Voix et sous-titres",Vector2(778,299),12,Color("8b7055"))
	draw_doors()

func save_settings() -> void:
	var file := FileAccess.open("user://settings.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"race":player_race,"fullscreen":fullscreen,"sound":sound_enabled,"brightness":brightness,"speed":speed_setting,"voices":voice_enabled}))

func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"): return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	if not data is Dictionary: return
	for race in sheet.races:
		if race.id==data.get("race","human"): player_race=race.id
	sound_enabled = bool(data.get("sound",true))
	voice_enabled = bool(data.get("voices",true))
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

func ingredient(id: String) -> Dictionary:
	for row in sheet.ingredients:
		if row.id==id: return row
	return {}

func system(id: String) -> Dictionary:
	for row in sheet.systems:
		if row.id==id: return row
	return {}

func roll_appearance() -> Dictionary:
	var config: Dictionary = sheet.customer_variation[0]
	var result := {"size":customer_rng.randf_range(config.size_min,config.size_max),"head":customer_rng.randf_range(config.head_min,config.head_max),"head_width":customer_rng.randf_range(0.9,1.12),"length":customer_rng.randf_range(config.tentacle_length_min,config.tentacle_length_max),"seed":customer_rng.randf_range(0,TAU)}
	for key in ["hats","glasses","tentacle_counts","tentacle_forms","skin_colors","clothing_colors","pants_colors","shoe_colors"]:
		var choices: Array = config[key]
		result[key] = choices[customer_rng.randi_range(0,choices.size()-1)]
	return result

func choose_customer() -> void:
	var choices: Array[int] = []
	for index in range(sheet.customers.size()):
		if index != actor_customer: choices.append(index)
	customer = choices[customer_rng.randi_range(0,choices.size()-1)]
	queued_appearance = roll_appearance()

func next_order() -> void:
	var choices: Array[int] = []
	for index in range(sheet.recipes.size()):
		if recipe_unlocked(index): choices.append(index)
	order = choices[customer_rng.randi_range(0,choices.size()-1)]

func recipe_unlocked(index: int) -> bool:
	if restaurant_level()<int(recipe(index).get("level",0)): return false
	for id in recipe(index).ingredients:
		if not id in discovered: return false
	return true

func travel(destination: String, arrival_x: float) -> void:
	room = destination
	player = Vector2(arrival_x,505)
	vertical = 0
	camera_x = 0
	speech_time = 0
	if OS.get_name()=="Windows": DisplayServer.tts_stop()
	say({"office":"Le canapé sauvegarde votre partie. Le PC commande des ingrédients.","garden":"Six bacs supplémentaires ! La planète se trouve à droite.","planet":"Explorez la vallée. E près d'une plante inconnue pour la découvrir.","restaurant":"De retour au snack ! Vos clients vous attendent."}.get(room,"Bienvenue !"))

func harvest_node(node: Dictionary) -> bool:
	if float(node_cooldowns[node.id])>0:
		say("Cette plante repousse. Revenez dans %d secondes." % ceili(node_cooldowns[node.id]))
		return false
	var item := ingredient(node.ingredient)
	inventory[node.ingredient] += 2
	node_cooldowns[node.id] = float(node.regrow_seconds)
	if not node.ingredient in discovered:
		discovered.append(node.ingredient)
		say("Découverte : "+item.name+" ! Disponible au PC et dans vos recettes.")
	else: say("+2 "+item.name)
	play_sound(620)
	action_time = float(animation("harvest").duration)
	return true

func purchase(id: String) -> bool:
	var item := ingredient(id)
	if item.is_empty() or not id in discovered:
		say("Explorez la planète pour découvrir cet ingrédient d'abord.")
		return false
	var batch := int(system("shopping").batch_size)
	var cost := int(item.buy_price)*batch
	if coins<cost:
		say("Il manque des wrapcoincoins pour cette commande.")
		return false
	coins -= cost
	deliveries.append({"ingredient":id,"quantity":batch,"remaining":float(system("shopping").delivery_seconds)})
	say("Commande passée : 3 "+item.name+". Livraison dans 4 secondes de jeu.")
	play_sound(580)
	return true

func update_deliveries(delta: float) -> void:
	for i in range(deliveries.size()-1,-1,-1):
		deliveries[i].remaining -= delta
		if deliveries[i].remaining<=0:
			var row: Dictionary = deliveries[i]
			inventory[row.ingredient] += int(row.quantity)
			say("Livraison reçue : +%d %s." % [row.quantity,ingredient(row.ingredient).name])
			deliveries.remove_at(i)
			play_sound(880)

func speak_dialogue(kind: String) -> void:
	var actor_id: String = sheet.customers[actor_customer].id
	for row in sheet.dialogues:
		if row.id==actor_id:
			speech = row[kind]
			if kind=="greeting": speech += " Je prendrai "+recipe(order).name+"."
			break
	speech_elapsed = 0
	speech_time = maxf(5,speech.length()/12.0)
	if voice_enabled:
		if OS.get_name()=="Windows":
			var voices := DisplayServer.tts_get_voices_for_language("fr")
			if voices.is_empty():
				var all_voices := DisplayServer.tts_get_voices()
				if not all_voices.is_empty(): voices.append(all_voices[0].id)
			if not voices.is_empty(): DisplayServer.tts_speak(speech,voices[0],75,1.0,1.0,0,true)
		else: play_sound(240+actor_customer*35)

func snapshot() -> Dictionary:
	return {"version":6,"customer_emotion":customer_emotion,"chat_memory":chat_memory.duplicate(true),"chat_log":chat_log.duplicate(true),"appearance":appearance.duplicate(true),"queued_appearance":queued_appearance.duplicate(true),"coins":coins,"served":served,"upgraded":upgraded,"inventory":inventory.duplicate(),"discovered":discovered.duplicate(),"room":room,"player_x":player.x,"order":order,"customer":customer,"actor_customer":actor_customer,"customer_state":customer_state,"customer_x":customer_x,"holding":holding,"player_race":player_race,"cooldowns":cooldowns.duplicate(),"node_cooldowns":node_cooldowns.duplicate(),"deliveries":deliveries.duplicate(true)}

func write_snapshot(path: String) -> bool:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(snapshot()))
	file.close()
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func save_at_sofa() -> bool:
	if room!="office": return false
	if not write_snapshot("user://sofa-save.json"):
		saving_notice = "Échec de sauvegarde. Votre ancienne partie est conservée."
		return false
	saving_notice = "Partie sauvegardée sur le canapé : %d wrapcoincoins." % coins
	say(saving_notice)
	return true

func load_at_sofa() -> bool:
	if room!="office" or not FileAccess.file_exists("user://sofa-save.json"):
		saving_notice = "Aucune sauvegarde sur ce canapé."
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://sofa-save.json"))
	if not data is Dictionary or not data.get("inventory") is Dictionary:
		saving_notice = "Sauvegarde illisible. La partie actuelle est conservée."
		return false
	apply_snapshot(data)
	saving_notice = "Partie chargée : inventaire, découvertes et wrapcoincoins restaurés."
	say(saving_notice)
	return true

func apply_snapshot(data: Dictionary) -> void:
	reset_customer_conversation()
	if data.get("chat_memory") is Dictionary: chat_memory=dialogue_engine.restore_memory(data.chat_memory,sheet)
	chat_log.clear()
	for entry in data.get("chat_log",[]):
		if entry is String: chat_log.append(entry.left(int(sheet.local_chat[0].response_limit)+50))
	while chat_log.size()>20: chat_log.pop_front()
	coins = maxi(0,int(data.get("coins",0)))
	served = maxi(0,int(data.get("served",0)))
	upgraded = bool(data.get("upgraded",false))
	customer = posmod(int(data.get("customer",0)),sheet.customers.size())
	actor_customer = posmod(int(data.get("actor_customer",customer)),sheet.customers.size())
	appearance = restore_appearance(data.get("appearance",{}))
	queued_appearance = restore_appearance(data.get("queued_appearance",{}))
	order = posmod(int(data.get("order",0)),sheet.recipes.size())
	completed = served>=3
	for id in inventory:
		inventory[id] = maxi(0,int(data.get("inventory",{}).get(id,0)))
		cooldowns[id] = maxf(0,float(data.get("cooldowns",{}).get(id,0)))
	for id in node_cooldowns: node_cooldowns[id] = maxf(0,float(data.get("node_cooldowns",{}).get(id,0)))
	discovered = ["moonleaf","sunfruit","mushroom"]
	for id in data.get("discovered",[]):
		if id in inventory and not id in discovered: discovered.append(id)
	room = data.get("room","restaurant")
	if not room in ["restaurant","office","garden","planet"]: room="restaurant"
	player = Vector2(clampf(float(data.get("player_x",565)),40,3560 if room=="planet" else 1160),505)
	camera_x = clampf(player.x-600,0,2400) if room=="planet" else 0
	holding = clampi(int(data.get("holding",-1)),-1,sheet.recipes.size()-1)
	customer_emotion=data.get("customer_emotion","calm")
	if customer_emotion not in ["calm","happy","angry"]: customer_emotion="calm"
	customer_state = data.get("customer_state","arriving")
	if not customer_state in ["arriving","waiting","leaving"]: customer_state="arriving"
	customer_x = clampf(float(data.get("customer_x",1250)),946,1270)
	for row in sheet.races:
		if row.id==data.get("player_race",player_race): player_race=row.id
	deliveries.clear()
	for row in data.get("deliveries",[]):
		if row is Dictionary and row.get("ingredient") in discovered:
			deliveries.append({"ingredient":row.ingredient,"quantity":clampi(int(row.get("quantity",3)),1,3),"remaining":clampf(float(row.get("remaining",4)),0,4)})
	speech_time = 0
	vertical = 0

func draw_doors() -> void:
	for door in sheet.doors:
		if door.room!=room: continue
		var x := float(door.x)-camera_x
		var names := {"restaurant":"SNACK","office":"BUREAU","garden":"SERRE","planet":"PLANÈTE"}
		panel(Rect2(x-29,488,58,56),Color(0.08,0.17,0.2,0.8),4)
		draw_rect(Rect2(x-18,502,36,28),Color("597888"),false,2)
		label_at("→",Vector2(x-9,526),22,Color("efcb82"))
		label_at(names[door.target],Vector2(clampf(x-33,5,1100),569),12,Color("f4d59a"))
		if absf(player.x-float(door.x))<30 and not menu:
			panel(Rect2(clampf(x-65,5,1060),443,130,28),Color("152433"),3)
			label_at("E · "+names[door.target],Vector2(clampf(x-55,15,1070),462),15)

func draw_other_room() -> void:
	var texture: Texture2D = room_textures.get(room)
	if texture:
		if room=="planet":
			for i in range(3): draw_texture_rect(texture,Rect2(i*1200-camera_x,0,1200,768),false,Color(brightness,brightness,brightness))
		else: draw_texture_rect(texture,Rect2(0,0,1200,768),false,Color(brightness,brightness,brightness))
	var nodes: Array = sheet.wild_nodes if room=="planet" else (sheet.beds if room=="garden" else [])
	for node in nodes:
		var x := float(node.x)-camera_x
		if x < -80 or x > 1280: continue
		var item := ingredient(node.ingredient)
		if room=="planet":
			draw_line(Vector2(x,536),Vector2(x,468),Color("83b3a0"),5,true)
			for j in range(5): draw_circle(Vector2(x+sin(j*1.5)*19,482+cos(j*1.5)*15),10,Color(item.color).darkened(0.4 if node_cooldowns[node.id]>0 else 0))
			if node.ingredient=="crystalrice":
				for j in range(4): draw_line(Vector2(x+j*8-12,530),Vector2(x+j*8-12,480-j*4),Color("a7edef"),5,true)
		var known: bool = node.ingredient in discovered
		label_at(item.name if known else "Plante inconnue",Vector2(x-66,594),13,Color("c6efdc"))
		if absf(player.x-float(node.x))<62 and not menu:
			panel(Rect2(x-65,414,138,28),Color("142630"),4)
			label_at("E · Récolter" if node_cooldowns[node.id]<=0 else "%ds · Repousse" % ceili(node_cooldowns[node.id]),Vector2(x-56,433),15)
	if room=="office":
		for station in sheet.stations:
			if station.room!="office": continue
			var x := float(station.x)
			label_at("CANAPÉ / SAUVEGARDE" if station.id=="couch" else "PC / COMMANDES",Vector2(x-92,594),13,Color("f4d59a"))
			if absf(player.x-x)<80:
				panel(Rect2(x-84,363,176,31),Color("152433"),4)
				label_at("E · Sauver / charger" if station.id=="couch" else "E · Commander",Vector2(x-75,384),15)
	if room=="planet":
		label_at("VALLÉE DES COMÈTES · %d m" % int(player.x/10),Vector2(32,184),16,Color("bce9dc"))
		label_at("DÉCOUVERTES : %d / 3" % (discovered.size()-3),Vector2(930,184),16,Color("bce9dc"))
	alien(Vector2(player.x-camera_x,player.y),Color("bca2e9"),true)
	draw_doors()

func restore_appearance(saved: Variant) -> Dictionary:
	var result := roll_appearance()
	if not saved is Dictionary: return result
	var config: Dictionary = sheet.customer_variation[0]
	for key in ["hats","glasses","tentacle_counts","tentacle_forms","skin_colors","clothing_colors","pants_colors","shoe_colors"]:
		if saved.get(key) in config[key]: result[key] = saved[key]
	for key in ["size","head","head_width","length","seed"]:
		if saved.get(key) is float or saved.get(key) is int:
			var limits: Dictionary = {"size":[config.size_min,config.size_max],"head":[config.head_min,config.head_max],"head_width":[0.9,1.12],"length":[config.tentacle_length_min,config.tentacle_length_max],"seed":[0,TAU]}
			result[key] = clampf(float(saved[key]),limits[key][0],limits[key][1])
	return result

func draw_accessories(width: float, height: float, look: Dictionary) -> void:
	var head_top := -height
	var face := Vector2(width*0.21,head_top+height*0.17)
	var ink := Color("243340")
	var skin := Color(look.skin_colors)
	for index in range(int(look.tentacle_counts)):
		var side := -1.0 if index%2==0 else 1.0
		var start := Vector2(side*width*0.31,head_top+height*0.24+index*2)
		var points := PackedVector2Array()
		for step in range(17):
			var t := step/16.0
			var sway := sin(t*TAU+float(look.seed)+clock*2)*4
			if look.tentacle_forms=="curled": sway = sin(t*TAU*1.4+clock)*8
			elif look.tentacle_forms=="zigzag": sway = (absf(fmod(t*4,2)-1)-0.5)*12+sin(clock)*2
			points.append(start+Vector2(side*(t*float(look.length)*0.65+sway),t*float(look.length)))
		draw_polyline(points,ink,6,true)
		draw_polyline(points,skin.darkened(0.18),4,true)
		for step in [5,9,13]: draw_circle(points[step],1.3,skin.lightened(0.2))
	var hat: String = look.hats
	var hat_index := ["none","fez","fedora","cap","helmet","beanie"].find(hat)
	if hat_index>0 and accessory_texture:
		draw_texture_rect_region(accessory_texture,Rect2(-width*0.48,head_top-12,width*0.96,40),Rect2((hat_index-1)*100,0,100,80))
	var glasses_index := ["none","round","dark","visor"].find(look.glasses)
	if glasses_index>0 and accessory_texture:
		draw_texture_rect_region(accessory_texture,Rect2(face-Vector2(19,9),Vector2(33,15)),Rect2((glasses_index-1)*100,80,100,45))

func restaurant_level() -> int:
	var result := 0
	for index in range(sheet.progression.size()):
		if served>=int(sheet.progression[index].served): result=index
	return result

func chat_with_customer(words: String) -> bool:
	words = words.strip_edges().left(int(sheet.local_chat[0].message_limit))
	if words.is_empty(): return false
	if room!="restaurant" or customer_state!="waiting":
		say("Attendez un client au comptoir pour discuter.")
		return false
	chat_log.append("Vous : "+words)
	append_customer_reply(local_customer_reply(words))
	if chat_memory.get("topic")=="dismiss": dismiss_customer()
	return true

func local_customer_reply(words: String) -> String:
	var person: Dictionary = sheet.customers[actor_customer]
	var names: Array[String] = []
	for id in recipe(order).ingredients: names.append(ingredient(id).name)
	var context := {"name":person.name,"race":person.race,"order":recipe(order).name,"price":int(recipe(order).price),"ingredients":" et ".join(names),"rank":sheet.progression[restaurant_level()].name,"bonus":int(sheet.progression[restaurant_level()].bonus)+(5 if upgraded else 0)}
	return dialogue_engine.reply(words,context,chat_memory,sheet)

func append_customer_reply(reply: String) -> void:
	chat_log.append(sheet.customers[actor_customer].name+" : "+reply)
	while chat_log.size()>20: chat_log.pop_front()
	speech=reply
	speech_elapsed=0
	speech_time=maxf(8.0,reply.length()/35.0+4)
	if voice_enabled and OS.get_name()=="Windows":
		var voices := DisplayServer.tts_get_voices_for_language("fr")
		if not voices.is_empty(): DisplayServer.tts_speak(reply,voices[0],70,1,1,0,true)
	save_progress()

func reset_customer_conversation() -> void:
	chat_memory.clear()

func draw_drink(at: Vector2, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at+Vector2(-9,-16),at+Vector2(9,-16),at+Vector2(6,3),at+Vector2(-6,3)]),Color("bacbd0"))
	draw_colored_polygon(PackedVector2Array([at+Vector2(-7,-12),at+Vector2(7,-12),at+Vector2(5,1),at+Vector2(-5,1)]),tint.darkened(0.2))
	draw_line(at+Vector2(-5,-11),at+Vector2(-3,0),Color(1,1,1,0.7),2,true)
	draw_line(at+Vector2(3,-8),at+Vector2(6,-25),Color("e8c599"),2,true)

func draw_restaurant_details() -> void:
	# Tiny decorative ball tucked on a shelf; intentionally has no hitbox.
	var ball := Vector2(1045,377)
	draw_circle(ball+Vector2(1,2),6,Color(0,0,0,0.45))
	draw_circle(ball,5,Color("dad8ce"))
	draw_colored_polygon(PackedVector2Array([ball+Vector2(-5,0),ball+Vector2(-4,-3),ball+Vector2(0,-5),ball+Vector2(4,-3),ball+Vector2(5,0)]),Color("a93932"))
	draw_line(ball-Vector2(5,0),ball+Vector2(5,0),Color("302a26"),1.5,true)
	draw_circle(ball,2,Color("302a26"))
	draw_circle(ball,1,Color("eae0cc"))
	# Beverage dispenser, with a lit panel, nozzle and metal drip tray.
	panel(Rect2(724,421,39,59),Color("28343b"),3)
	panel(Rect2(727,424,33,39),Color("566570"),3)
	draw_rect(Rect2(733,430,20,17),Color("183139"))
	draw_line(Vector2(736,435),Vector2(750,435),Color("81c7c5"),2,true)
	draw_line(Vector2(743,451),Vector2(743,462),Color("b8bab5"),4,true)
	for offset in range(5): draw_line(Vector2(729+offset*6,473),Vector2(729+offset*6,478),Color("87949a"),2,true)
	label_at("BOISSONS",Vector2(709,612),12,Color("d5d8cd"))
	if restaurant_level()>=1:
		label_at("★".repeat(restaurant_level()),Vector2(1006,340),22,Color("e7c078"))

func dismiss_customer() -> bool:
	if customer_state!="waiting": return false
	customer_emotion="angry"
	customer_state="leaving"
	choose_customer()
	next_order()
	say("Le client part en colère, sans achat. Un autre voyageur arrivera après son départ.")
	save_progress()
	return true
