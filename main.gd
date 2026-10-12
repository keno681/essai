extends Node2D
const ART=preload("res://visual_library.gd")

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
var customer_queue: RefCounted
var online: Node
var customer_rng := RandomNumberGenerator.new()
var fullscreen := false
var sound_enabled := true
var brightness := 1.0
var speed_setting := 1
var sound_player: AudioStreamPlayer
var room := "restaurant"
var camera_x := 0.0
var room_textures: Dictionary = {}
var discovered: Array = ["moonleaf","sunfruit","mushroom","mineralwater","lunartea","nebulasyrup"]
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
var move_goal := -1.0
var click_target: Dictionary = {}
var ambient_clock := 0.0
var ambience_enabled := true
var music_player: AudioStreamPlayer
var console_node: Node
var counter_items: Array = []
var counter_serial := 0
var dayflow: RefCounted
var tables: Node
var planters: Node
var saving_notice := "Aucune sauvegarde sur ce canapé."

func _ready() -> void:
	migrate_previous_saves()
	get_tree().auto_accept_quit = false
	sheet = JSON.parse_string(FileAccess.get_file_as_string("res://data/design.json"))
	dayflow=preload("res://day_flow.gd").new(); dayflow.game=self
	add_improvised_recipes()
	for item in sheet.ingredients:
		inventory[item.id] = 0
		if not item.get("pantry",false): inventory["raw_"+item.id]=0
		if not item.get("pantry",false): inventory["seed_"+item.id]=3 if item.starter else 0
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
	planters=preload("res://planters_compact.gd").new()
	add_child(planters)
	customer_queue = load("res://customer_queue.gd").new()
	customer_queue.setup(self)
	tables=preload("res://tables.gd").new()
	add_child(tables)
	load_progress()
	load_settings()
	set_fullscreen(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	accessory_texture = load("res://art/accessories.svg")
	race_texture = load("res://art/races.png")
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	setup_ambience()
	console_node = load("res://console.gd").new()
	add_child(console_node)
	add_child(load("res://hover_highlight.gd").new())
	ui = load("res://ui.gd").new()
	add_child(ui)
	online=load("res://online_coop.gd").new()
	add_child(online)
	var art_path: String = "res://" + sheet.visuals[0].asset
	if ResourceLoader.exists(art_path):
		backdrop = load(art_path)
	if console_node.reopen: ui.show_page("console")

func animation(id: String) -> Dictionary:
	for row in sheet.animations:
		if row.id == id: return row
	return {}

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if online and online.active: online.leave()
		save_progress()
		if OS.get_name()=="Windows": DisplayServer.tts_stop()
		get_tree().quit()

func recipe(index: int) -> Dictionary:
	return sheet.recipes[index]

func say(words: String) -> void:
	message = words
	message_time = 5.0

func add_improvised_recipes() -> void:
	for kind in ["wrap","drink"]:
		var ids: Array=[]
		for row in sheet.recipes:
			if row.get("kind","wrap")==kind:
				for id in row.ingredients:
					if id not in ids: ids.append(id)
		for mask in range(1,1<<ids.size()):
			var parts: Array=[]
			for i in range(ids.size()):
				if mask & (1<<i): parts.append(ids[i])
			var sorted=parts.duplicate(); sorted.sort()
			var exists=false
			for row in sheet.recipes:
				var required=row.ingredients.duplicate(); required.sort()
				if row.get("kind","wrap")==kind and required==sorted: exists=true; break
			if not exists: sheet.recipes.append({"id":"custom_"+kind+"_"+str(mask),"name":"Boisson improvisée" if kind=="drink" else "Wrap improvisé","kind":kind,"ingredients":parts,"price":0,"custom":true,"joke":"Une création hors menu."})

func discard_preparation(kind: String, ids: Array) -> bool:
	if online and online.request("discard_preparation",{"kind":kind,"ingredients":ids}): return false
	if kind not in ["wrap","drink"] or ids.is_empty() or ids.size()>sheet.ingredients.size(): return false
	var seen: Array=[]
	for id in ids:
		if not id is String or id in seen or inventory.get(id,0)<1: say("Stock insuffisant pour cette préparation."); return false
		var allowed=false
		for row in sheet.recipes:
			if row.get("kind","wrap")==kind and id in row.ingredients: allowed=true; break
		if not allowed: return false
		seen.append(id)
	for id in seen: inventory[id]-=1
	say("Préparation jetée. Les ingrédients sont perdus.")
	save_progress()
	return true

func discard_order(at_trash: bool = false) -> bool:
	if online and online.request("discard_order",{"trash":at_trash}): return false
	if holding<0:
		say("Tu ne portes aucune commande à jeter.")
		return false
	holding=-1
	say("Commande jetée, sans récupérer les ingrédients.")
	save_progress()
	return true

func cook() -> bool:
	if online and online.request("cook",{"recipe":selected}): return false
	if holding >= 0:
		say("Vous portez déjà une commande. Servez-le au comptoir !")
		return false
	if not recipe_unlocked(selected):
		say("Cette recette sera débloquée avec votre réputation et vos découvertes.")
		return false
	for ingredient in recipe(selected).ingredients:
		if inventory[ingredient] < 1:
			say("Traite les récoltes sur la TABLE DE TRAVAIL avant de cuisiner." if inventory.get("raw_"+ingredient,0)>0 else "Il manque des ingrédients : fais un tour au jardin !")
			return false
	for ingredient in recipe(selected).ingredients:
		inventory[ingredient] -= 1
	holding = selected
	action_time = float(animation("cook").duration)
	play_sound(440)
	say("Commande prête ! Entre dans la SALLE et clique sur la table à servir.")
	return true

func serve() -> bool:
	if online and online.request("serve"): return false
	if customer_state != "waiting":
		say("Le prochain client arrive. Attendez-le au comptoir.")
		return false
	if holding < 0:
		say("Votre client attend " + recipe(order).name + ".")
		return false
	if holding != order:
		var wanted: String=recipe(order).name
		var received: String=recipe(holding).name
		holding=-1
		reset_customer_conversation()
		dismiss_customer()
		speech="J’ai demandé "+wanted+", pas "+received+" ! Garde tes recettes, je ne paierai pas !"
		speech_elapsed=0
		speech_time=maxf(5,speech.length()/12.0)
		action_time=float(animation("serve").duration)
		play_sound(180)
		say("Mauvaise commande ! Le client part furieux, sans payer. La commande est perdue.")
		save_progress()
		return true
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
	if room=="restaurant" and absf(player.x-780)<25:
		discard_order(true)
		return
	if room=="restaurant" and absf(player.x-845)<45:
		ui.show_page("counter")
		return
	for door in sheet.doors:
		if door.room==room and absf(player.x-float(door.x))<30:
			travel(door.target,float(door.arrival_x))
			return
	if room=="dining":
		ui.show_page("orders")
		return
	if room=="office":
		if absf(player.x-440)<80: ui.show_page("save")
		elif absf(player.x-830)<80: ui.show_page("shop")
		else: say("Approchez du canapé ou du PC, puis appuyez sur E.")
		return
	if room in ["garden","planet"]:
		for node in sheet.beds if room=="garden" else sheet.wild_nodes:
			if absf(player.x-float(node.x))<62:
				if room=="garden": planters.open(node.id)
				else: harvest_node(node)
				return
		say("E près d'une plante pour récolter. Explorez vers la droite !")
		return
	if room=="restaurant" and customer_state=="waiting" and absf(player.x-customer_x)<52:
		ui.show_page("reception")
		return
	for item in sheet.ingredients:
		if item.starter and absf(player.x-float(item.x))<58:
			planters.open(item.id)
			return
	if absf(player.x - 745) < 36:
		ui.set_meta("wrap_composition",[])
		ui.show_page("cookdrink")
	elif absf(player.x - 650) < 65:
		ui.set_meta("wrap_composition",[])
		ui.show_page("cookwrap")
	elif absf(player.x - 1090) < 65:
		if online and online.request("upgrade"): return
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
			KEY_O: ui.show_page("orders")
			KEY_R: discard_order()
			KEY_N: ui.show_page("confirm")

func return_wrap() -> void:
	if online and online.request("return"): return
	if holding >= 0:
		for ingredient in recipe(holding).ingredients: inventory[ingredient] += 1
		holding = -1
		say("Ingrédients rangés : rien n'est perdu.")

func new_service() -> void:
	if online and online.active:
		say("Quitte la coop avant de recommencer un service.")
		return
	dayflow.reset()
	move_goal=-1
	click_target.clear()
	customer_emotion="calm"
	reset_customer_conversation()
	room = "restaurant"
	player.x = 565
	discovered = ["moonleaf","sunfruit","mushroom","mineralwater","lunartea","nebulasyrup"]
	planters.reset()
	tables.reset()
	counter_items.clear()
	counter_serial=0
	deliveries.clear()
	chat_log.clear()
	for id in node_cooldowns: node_cooldowns[id] = 0.0
	coins = 0
	served = 0
	upgraded = false
	completed = false
	customer_queue.reset()
	choose_customer()
	actor_customer = customer
	appearance = queued_appearance.duplicate(true)
	next_order()
	holding = -1
	customer_state = "arriving"
	customer_x = customer_queue.enter_service()
	for id in inventory:
		inventory[id] = 0
		cooldowns[id] = 0.0
	for item in sheet.ingredients:
		if not item.get("pantry",false): inventory["seed_"+item.id]=3 if item.starter else 0
	inventory.mineralwater=3
	save_progress()
	say("Jour 1 · cinq clients. Le guide débutant est disponible dans le menu.")

func update_customers(delta: float) -> void:
	customer_queue.update(delta)
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
			if dayflow.admitted>=dayflow.limit(): customer_state="closed"; return
			actor_customer = customer
			customer_emotion="calm"
			reset_customer_conversation()
			appearance = queued_appearance.duplicate(true)
			customer_x = customer_queue.enter_service()
			customer_state = "arriving"

func _process(delta: float) -> void:
	if ui and online: dayflow.tick()
	if not online or not online.active or online.hosting: inventory.mineralwater=maxi(3,int(inventory.get("mineralwater",0)))
	ambient_clock+=delta
	if is_instance_valid(music_player): music_player.volume_db=float(sheet.ambience[0].volume_db)-(6 if menu else 0)
	var connected: bool = online != null and online.active
	var authority: bool = (not connected or online.hosting) and (not connected or online.updates.state.is_empty())
	if not menu or connected:
		clock += delta
		if authority: update_customers(delta)
		speech_time = maxf(0.0,speech_time-delta)
		speech_elapsed += delta
		if authority: update_deliveries(delta)
		if not menu and (not connected or online.updates.state.is_empty()):
			var axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_LEFT))
			if absf(axis)>0:
				move_goal=-1
				click_target.clear()
			elif move_goal>=0:
				axis=signf(move_goal-player.x)
			walking = absf(axis) > 0
			if walking:
				facing = signf(axis)
				walk_cycle += delta * float(animation("walk").frequency)
			action_time = maxf(0.0, action_time - delta)
			if move_goal>=0:
				player.x=move_toward(player.x,move_goal,[180,240,310][speed_setting]*delta)
				if absf(player.x-move_goal)<float(sheet.interaction_ui[0].arrival_distance): finish_click_action()
			else:
				player.x = clampf(player.x + axis * [180,240,310][speed_setting] * delta, 40, 3560 if room=="planet" else 1160)
			camera_x = clampf(player.x-600,0,2400) if room=="planet" else 0
			vertical += 1100 * delta
			player.y = minf(505, player.y + vertical * delta)
			if player.y >= 505: vertical = 0
		else: walking=false
		if authority:
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

func alien(position: Vector2, color: Color, chef: bool = false, queued: Dictionary = {}) -> void:
	if not race_texture: return
	var person_id: int = int(queued.get("customer",actor_customer))
	var race_id: String = str(queued.get("race",player_race)) if chef else sheet.customers[person_id].race
	var race_index := 0
	var sprite_row: Dictionary = sheet.races[0]
	for row in sheet.races:
		if row.id == race_id:
			race_index = int(row.sprite_index)
			sprite_row = row
	var moving: bool = bool(queued.get("moving",walking)) if chef else bool(queued.get("moving",customer_state != "waiting"))
	var phase: float = float(queued.get("phase",walk_cycle)) if chef else float(queued.get("phase",npc_cycle))
	var stride := sin(phase)*0.2 if moving else 0.0
	var direction: float = float(queued.get("facing",facing)) if chef else float(queued.get("facing",1.0 if queued.is_empty() and customer_state=="leaving" else -1.0))
	var breathe := sin(clock*2.0)*1.2
	var bob := absf(cos(phase))*2 if moving else breathe
	var foot := position+Vector2(0,39)
	var cell := Vector2(float(sprite_row.source_width),race_texture.get_height())
	var source_x := float(sprite_row.source_x)
	var look: Dictionary = {} if chef else queued.get("appearance",appearance)
	var height := 152.0*float(look.get("size",1.0))
	var width := height*cell.x/cell.y
	var cut := 0.76
	draw_set_transform(foot,0,Vector2(1.6,0.28))
	draw_circle(Vector2.ZERO,20,Color(0.03,0.02,0.01,0.35))
	for side in [0,1]:
		var hip := Vector2((side-0.5)*width*0.5,-height*(1-cut)+bob)
		var angle := (-0.9 if side==0 else -0.65) if queued.get("seated",false) else stride*(-1 if side==0 else 1)
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
	var displayed_holding: int = int(queued.get("holding",holding))
	if chef and displayed_holding>=0 and recipe(displayed_holding).get("kind","wrap")=="drink":
		draw_drink(Vector2(20,-57),Color("a5d5b7") if displayed_holding==5 else Color("d08bea"))
	elif chef and displayed_holding>=0:
		draw_texture_rect(ART.object(15),Rect2(9,-72,26,30),false)
	if not chef and queued.is_empty() and customer_state=="leaving" and customer_emotion!="angry":
		draw_texture_rect(ART.object(15),Rect2(9,-72,26,30),false)
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if sheet.is_empty(): return
	if room!="restaurant":
		draw_other_room()
		if online: online.draw_partner()
		return
	if backdrop:
		draw_texture_rect(backdrop,Rect2(0,0,float(sheet.visuals[0].width),float(sheet.visuals[0].height)),false,Color(brightness,brightness,brightness))
	else:
		draw_rect(Rect2(0,190,1200,420),Color("463e39"))
	draw_ambient_decor()
	draw_restaurant_details()
	planters.paint()
	# Soft room lighting and active stations stay legible without covering the art.
	for item in sheet.ingredients:
		if not item.starter: continue
		var x := float(item.x)
		if cooldowns[item.id] > 0:
			panel(Rect2(x-23,455,46,22),Color("332f29"),6)
			label_at("%ds" % ceili(cooldowns[item.id]),Vector2(x-11,471),14,Color("e4c69b"))
	# Heat drifting from the grill, with gentle ambient light movement.
	for i in range(5):
		var rise := fmod(clock*22+i*17,78)
		draw_arc(Vector2(628+sin(clock+i)*8,407-rise),9,0.2,2.4,14,Color(1,0.92,0.76,(1-rise/78)*0.13),2,true)
	if upgraded:
		draw_circle(Vector2(1127,432),26,Color(1,0.7,0.3,0.1))
		label_at("+5 WCC / wrap",Vector2(1060,366),16,Color("f9d47b"))
	tables.draw_arrivals()
	customer_queue.draw_people()
	if customer_state!="closed": alien(Vector2(customer_x,520 if customer_state=="leaving" else 505),Color(sheet.customers[actor_customer].color))
	if customer_emotion=="angry":
		label_at("!",Vector2(customer_x-4,365),27,Color("f28c78"))
	alien(player,Color("bca2e9"),true)
	draw_style_box(ART.panel_frame(Color(0.65,0.68,0.70)),Rect2(763,205,407,107))
	var bubble_title: String = (sheet.customers[customer].name+" · "+recipe(order).name) if customer_state=="waiting" else (("Client en colère : il s’en va !" if customer_emotion=="angry" else "Merci, à bientôt !") if customer_state=="leaving" else "Un client arrive…")
	if customer_state=="closed": bubble_title="Jour %d · %d/%d clients accueillis" % [dayflow.number,dayflow.admitted,dayflow.limit()]
	var title_text := TextParagraph.new()
	title_text.width = 371
	title_text.max_lines_visible = 1
	title_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_text.add_string(bubble_title,font,18)
	title_text.draw(get_canvas_item(),Vector2(781,219),Color("f4dec0"))
	var spoken: String = speech.left(int(speech_elapsed*35)) if speech_time>0 else sheet.customers[actor_customer].line
	if customer_state=="closed": spoken="Termine les commandes en salle. Le bilan apparaît après le départ des cinq clients." if dayflow.number==1 else "Termine les commandes en salle pour clôturer le jour."
	var body_text := TextParagraph.new()
	body_text.width = 371
	body_text.max_lines_visible = 3
	body_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body_text.add_string(spoken,font,13)
	body_text.draw(get_canvas_item(),Vector2(781,247),Color("e1d8c6"))
	draw_doors()
	draw_interaction_markers()

	if online: online.draw_partner()

func save_settings() -> void:
	var file := FileAccess.open("user://settings.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"race":player_race,"fullscreen":fullscreen,"sound":sound_enabled,"brightness":brightness,"speed":speed_setting,"voices":voice_enabled,"ambience":ambience_enabled}))

func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"): return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://settings.json"))
	if not data is Dictionary: return
	for race in sheet.races:
		if race.id==data.get("race","human"): player_race=race.id
	sound_enabled = bool(data.get("sound",true))
	voice_enabled = bool(data.get("voices",true))
	ambience_enabled=bool(data.get("ambience",true))
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

func seed_count(id: String) -> int:
	return int(inventory.get("seed_"+id,0))

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
	if customer_queue:
		customer_queue.take_next()
		return
	var choices: Array[int] = []
	for index in range(sheet.customers.size()):
		if index != actor_customer: choices.append(index)
	customer = choices[customer_rng.randi_range(0,choices.size()-1)]
	queued_appearance = roll_appearance()

func next_order() -> void:
	if dayflow.number==1:
		order=0 if dayflow.admitted%2==0 else 1
		return
	var choices: Array[int] = []
	for index in range(sheet.recipes.size()):
		if not recipe(index).get("custom",false) and recipe_unlocked(index): choices.append(index)
	order = choices[customer_rng.randi_range(0,choices.size()-1)]

func recipe_unlocked(index: int) -> bool:
	if restaurant_level()<int(recipe(index).get("level",0)): return false
	for id in recipe(index).ingredients:
		if not id in discovered: return false
	return true

func travel(destination: String, arrival_x: float) -> void:
	move_goal=-1
	click_target.clear()
	room = destination
	player = Vector2(arrival_x,505)
	vertical = 0
	camera_x = 0
	speech_time = 0
	if OS.get_name()=="Windows": DisplayServer.tts_stop()
	say({"office":"Le canapé sauvegarde votre partie. Le PC commande des graines.","garden":"Six bacs supplémentaires ! La planète se trouve à droite.","planet":"Explorez la vallée. E près d'une plante inconnue pour la découvrir.","dining":"Salle orbitale : clique sur une table pour consulter ou servir sa commande.","restaurant":"De retour au snack ! Vos clients vous attendent."}.get(room,"Bienvenue !"))

func harvest_node(node: Dictionary) -> bool:
	if online and online.request("wild",{"id":node.id}): return false
	if float(node_cooldowns[node.id])>0:
		say("Cette plante repousse. Revenez dans %d secondes." % ceili(node_cooldowns[node.id]))
		return false
	var item := ingredient(node.ingredient)
	inventory["raw_"+node.ingredient] += 2
	node_cooldowns[node.id] = float(node.regrow_seconds)
	if not node.ingredient in discovered:
		discovered.append(node.ingredient)
		say("Découverte : "+item.name+" ! Disponible au PC et dans vos recettes.")
	else: say("+2 "+item.name+" bruts · à traiter en cuisine.")
	play_sound(620)
	action_time = float(animation("harvest").duration)
	return true

func purchase(id: String) -> bool:
	if online and online.request("purchase",{"id":id}): return false
	var item := ingredient(id)
	if item.is_empty() or item.get("pantry",false) or not id in discovered:
		say("Explorez la planète pour découvrir cet ingrédient d'abord.")
		return false
	var batch := int(system("shopping").batch_size)
	var cost := int(item.get("seed_price",item.buy_price))*batch
	if coins<cost:
		say("Il manque des wrapcoincoins pour cette commande.")
		return false
	coins -= cost
	deliveries.append({"ingredient":id,"kind":"seed","quantity":batch,"remaining":float(system("shopping").delivery_seconds)})
	say("Commande passée : 3 graines · "+item.name+". Livraison dans 4 secondes de jeu.")
	play_sound(580)
	return true

func update_deliveries(delta: float) -> void:
	for i in range(deliveries.size()-1,-1,-1):
		deliveries[i].remaining -= delta
		if deliveries[i].remaining<=0:
			var row: Dictionary = deliveries[i]
			inventory["seed_"+row.ingredient] = seed_count(row.ingredient)+int(row.quantity)
			say("Livraison reçue : +%d graines · %s." % [row.quantity,ingredient(row.ingredient).name])
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
	return {"day_flow":dayflow.snapshot(),"coop_carried":int(online.partner.get("holding",-1)) if online and online.active and online.hosting else -1,"counter_items":counter_items.duplicate(true),"table_orders":tables.snapshot(),"selected_table":tables.selected,"waiting_queue":customer_queue.snapshot(),"version":10,"plantings":planters.plants.duplicate(),"customer_emotion":customer_emotion,"chat_memory":chat_memory.duplicate(true),"chat_log":chat_log.duplicate(true),"appearance":appearance.duplicate(true),"queued_appearance":queued_appearance.duplicate(true),"coins":coins,"served":served,"upgraded":upgraded,"inventory":inventory.duplicate(),"discovered":discovered.duplicate(),"room":room,"player_x":player.x,"order":order,"customer":customer,"actor_customer":actor_customer,"customer_state":customer_state,"customer_x":customer_x,"holding":holding,"player_race":player_race,"cooldowns":cooldowns.duplicate(),"node_cooldowns":node_cooldowns.duplicate(),"deliveries":deliveries.duplicate(true)}

func write_snapshot(path: String) -> bool:
	if online and online.active and (not online.hosting or online.executing_remote): return false
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(snapshot()))
	file.close()
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func save_at_sofa() -> bool:
	if online and online.active and not online.hosting:
		saving_notice="En coop, seul l’hôte sauvegarde le restaurant."
		return false
	if room!="office": return false
	if not write_snapshot("user://sofa-save.json"):
		saving_notice = "Échec de sauvegarde. Votre ancienne partie est conservée."
		return false
	saving_notice = "Partie sauvegardée sur le canapé : %d wrapcoincoins." % coins
	say(saving_notice)
	return true

func load_at_sofa() -> bool:
	if online and online.active:
		saving_notice="Quitte la coop avant de charger une autre sauvegarde."
		return false
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
	move_goal=-1
	click_target.clear()
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
		inventory[id] = maxi(0,int(data.get("inventory",{}).get(id,3 if id.begins_with("seed_") and ingredient(id.trim_prefix("seed_")).get("starter",false) else 0)))
		cooldowns[id] = maxf(0,float(data.get("cooldowns",{}).get(id,0)))
	var coop_carried := int(data.get("coop_carried",-1))
	if coop_carried>=0 and coop_carried<sheet.recipes.size():
		for id in recipe(coop_carried).ingredients: inventory[id]+=1
	for id in node_cooldowns: node_cooldowns[id] = maxf(0,float(data.get("node_cooldowns",{}).get(id,0)))
	discovered = ["moonleaf","sunfruit","mushroom","mineralwater","lunartea","nebulasyrup"]
	for id in data.get("discovered",[]):
		if id in inventory and not id in discovered: discovered.append(id)
	planters.restore(data.get("plantings",{}))
	room = data.get("room","restaurant")
	if not room in ["restaurant","office","garden","planet","dining"]: room="restaurant"
	player = Vector2(clampf(float(data.get("player_x",565)),40,3560 if room=="planet" else 1160),505)
	camera_x = clampf(player.x-600,0,2400) if room=="planet" else 0
	holding = clampi(int(data.get("holding",-1)),-1,sheet.recipes.size()-1)
	customer_emotion=data.get("customer_emotion","calm")
	if customer_emotion not in ["calm","happy","angry"]: customer_emotion="calm"
	customer_state = data.get("customer_state","arriving")
	if not customer_state in ["arriving","waiting","leaving","closed"]: customer_state="arriving"
	customer_x = clampf(float(data.get("customer_x",1250)),946,1270)
	for row in sheet.races:
		if row.id==data.get("player_race",player_race): player_race=row.id
	deliveries.clear()
	for row in data.get("deliveries",[]):
		if row is Dictionary and row.get("ingredient") in discovered and not ingredient(row.ingredient).get("pantry",false):
			deliveries.append({"ingredient":row.ingredient,"kind":"seed","quantity":clampi(int(row.get("quantity",3)),1,3),"remaining":clampf(float(row.get("remaining",4)),0,4)})
	customer_queue.restore(data.get("waiting_queue",{}))
	tables.restore(data.get("table_orders",[]))
	dayflow.restore(data.get("day_flow"))
	while customer_queue.people.size()>customer_queue.capacity(): customer_queue.people.pop_back()
	if dayflow.admitted>=dayflow.limit() and customer_state!="leaving": customer_state="closed"
	restore_counter(data.get("counter_items",[]))
	tables.selected=clampi(int(data.get("selected_table",0)),0,8)
	speech_time = 0
	vertical = 0

func door_hitbox(door: Dictionary) -> Rect2:
	var bounds={"snack_garden":Rect2(0,250,84,295),"snack_office":Rect2(508,250,84,295),"office_snack":Rect2(28,195,194,315),"garden_snack":Rect2(0,235,110,305),"garden_planet":Rect2(1100,220,100,330),"planet_garden":Rect2(0,260,84,285)}
	return bounds.get(door.id,Rect2(float(door.x)-42,250,84,295))

func draw_door_art() -> void:
	if room not in ["restaurant","planet","dining"]: return
	for door in sheet.doors:
		if door.room!=room: continue
		var rect:=door_hitbox(door)
		rect.position.x-=camera_x
		draw_texture_rect(ART.object(0),rect,false,Color(brightness,brightness,brightness))

func draw_doors() -> void:
	pass

func draw_other_room() -> void:
	if room=="dining": tables.draw_dining(); return
	var texture: Texture2D = room_textures.get(room)
	if texture:
		if room=="planet":
			for i in range(3): draw_texture_rect(texture,Rect2(i*1200-camera_x,0,1200,768),false,Color(brightness,brightness,brightness)*Color(console_node.config.planet_color))
		else: draw_texture_rect(texture,Rect2(0,0,1200,768),false,Color(brightness,brightness,brightness))
	draw_door_art()
	draw_ambient_decor()
	if room=="planet":
		label_at(console_node.config.planet_name,Vector2(25,165),24)
		for prop in console_node.config.decor:
			draw_circle(Vector2(prop.x-camera_x,prop.y),prop.size,Color(prop.color))
	planters.paint()
	var nodes: Array = sheet.wild_nodes if room=="planet" else (sheet.beds if room=="garden" else [])
	for node in nodes:
		var x := float(node.x)-camera_x
		if x < -80 or x > 1280: continue
		var item := ingredient(node.ingredient)
		if room=="planet":
			var crop_index: int = ["moonleaf","sunfruit","mushroom","starlime","firepepper","crystalrice"].find(str(node.ingredient))
			var scale := 0.6 if float(node_cooldowns[node.id]) > 0 else 1.0
			var height := 110.0 * scale
			draw_texture_rect(ART.crop(crop_index),Rect2(x-55*scale,536-height,110*scale,height),false,Color(brightness,brightness,brightness))
	if room=="planet":
		label_at("VALLÉE DES COMÈTES · %d m" % int(player.x/10),Vector2(32,184),16,Color("bce9dc"))
		label_at("DÉCOUVERTES : %d / 3" % discovered.filter(func(id): return id in system("exploration").new_ingredients).size(),Vector2(930,184),16,Color("bce9dc"))
	alien(Vector2(player.x-camera_x,player.y),Color("bca2e9"),true)
	draw_doors()
	draw_interaction_markers()

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
		draw_texture_rect(ART.accessory(hat_index-1),Rect2(-width*0.48,head_top-16,width*0.96,42),false)
	var glasses_index := ["none","round","dark","visor"].find(look.glasses)
	if glasses_index>0 and accessory_texture:
		draw_texture_rect(ART.accessory(4+glasses_index),Rect2(face-Vector2(19,9),Vector2(33,16)),false)

func restaurant_level() -> int:
	var result := 0
	for index in range(sheet.progression.size()):
		if served>=int(sheet.progression[index].served): result=index
	return result

func chat_with_customer(words: String) -> bool:
	if online and online.request("chat",{"text":words}): return false
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
	draw_texture_rect(ART.object(11 if tint.g > tint.r else 12),Rect2(at+Vector2(-10,-25),Vector2(20,30)),false)

func draw_restaurant_details() -> void:
	draw_texture_rect(preload("res://art/kitchen_trash.svg"),Rect2(759,464,42,82),false,Color(brightness,brightness,brightness))
	for i in range(counter_items.size()):
		var dish: Dictionary=counter_items[i]
		var at:=Vector2(800+(i%4)*26,425-floori(i/4.0)*35)
		draw_texture_rect(ART.object(11 if recipe(int(dish.recipe)).get("kind","wrap")=="drink" else 10),Rect2(at,Vector2(25,28)),false)
		label_at(str(dish.table),at+Vector2(7,27),12,Color("fff1ac"))
	draw_door_art()
	draw_texture_rect(ART.object(13),Rect2(1037,369,16,16),false,Color(brightness,brightness,brightness))
	draw_texture_rect(ART.object(1),Rect2(708,335,77,104),false,Color(brightness,brightness,brightness))
	if restaurant_level()>=1:
		label_at("★".repeat(restaurant_level()),Vector2(1006,340),22,Color("e7c078"))

func dismiss_customer() -> bool:
	if customer_state!="waiting": return false
	if not dayflow.accept(): return false
	dayflow.finish(false)
	customer_emotion="angry"
	customer_state="leaving"
	if dayflow.admitted<dayflow.limit():
		choose_customer()
		next_order()
	else:
		customer_queue.people.clear(); customer_queue.reserved.clear()
	say("Le client part en colère, sans achat. Un autre voyageur arrivera après son départ.")
	save_progress()
	return true

func interaction_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var destinations := {"restaurant":"SNACK","office":"BUREAU","garden":"SERRE","planet":"EXPLORER","dining":"SALLE"}
	for door in sheet.doors:
		if door.room!=room: continue
		var rect:=door_hitbox(door)
		result.append({"id":door.id,"x":float(door.x),"label":destinations[door.target],"rect":rect,"action":"interact"})
	if room=="restaurant":
		result.append({"id":"trash","x":780.0,"label":"POUBELLE","rect":Rect2(759,464,42,82),"action":"trash"})
		for item in sheet.ingredients:
			if item.starter: result.append({"id":item.id,"x":float(item.x),"label":"RÉCOLTER","rect":Rect2(float(item.x)-55,400,110,146),"action":"interact"})
	var bounds := {"kitchen":Rect2(595,320,108,224),"counter":Rect2(795,435,114,110),"drinks":Rect2(712,333,69,111),"upgrade":Rect2(1030,400,130,146),"couch":Rect2(344,390,300,155),"computer":Rect2(755,325,260,220)}
	var names := {"kitchen":"CUISINER","counter":"SERVIR","drinks":"BOISSONS","upgrade":"TERRASSE","couch":"SAUVEGARDER","computer":"COMMANDER"}
	for station in sheet.stations:
		if station.id=="counter":
			if station.room==room: result.append({"id":"counter","x":845.0,"label":"COMPTOIR DES COMMANDES","rect":bounds.counter,"action":"counter"})
			continue
		if station.room==room: result.append({"id":station.id,"x":float(station.x),"label":names[station.id],"rect":bounds[station.id],"action":"interact"})
	for node in sheet.beds if room=="garden" else (sheet.wild_nodes if room=="planet" else []):
		result.append({"id":node.id,"x":float(node.x),"label":"RÉCOLTER" if node.ingredient in discovered else "DÉCOUVRIR","rect":Rect2(float(node.x)-58,425,116,120),"action":"interact"})
	if room=="restaurant" and customer_state=="waiting": result.append({"id":"client","x":customer_x,"label":"SERVIR LE CLIENT","rect":Rect2(customer_x-32,360,64,185),"action":"welcome"})
	if room=="dining": result.append_array(tables.targets())
	return result

func clicked_target(at: Vector2) -> Dictionary:
	if room=="restaurant" and Rect2(1032,364,26,26).has_point(at):
		return {"id":"console","label":"CONSOLE POKÉBALL","rect":Rect2(1032,364,26,26),"x":1045.0,"action":"console"}
	var world := at+Vector2(camera_x,0)
	for target in interaction_targets():
		if target.rect.has_point(world): return target
	return {}

func start_click_action(at: Vector2) -> bool:
	if menu: return false
	if clicked_target(at).get("action", "")=="console":
		ui.show_page("console")
		return true
	click_target=clicked_target(at)
	if not click_target.is_empty():
		move_goal=float(click_target.x)
		say("En route : "+str(click_target.label).to_lower()+"…")
		return true
	if at.y>495 and at.y<630:
		move_goal=clampf(at.x+camera_x,40,3560 if room=="planet" else 1160)
		return true
	return false

func finish_click_action() -> void:
	if move_goal<0: return
	player.x=move_goal
	move_goal=-1
	var target:=click_target.duplicate()
	click_target.clear()
	if target.is_empty(): return
	if target.action=="welcome":
		ui.show_page("reception")
	elif target.action=="table_visit":
		tables.visit(int(target.table))
	elif target.action=="trash":
		discard_order(true)
	elif target.action=="counter":
		ui.show_page("counter")
	elif target.action=="serve":
		serve()
	else: interact()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if start_click_action(event.position): get_viewport().set_input_as_handled()

func guide_step() -> Dictionary:
	var lesson: Dictionary=dayflow.guide()
	if not lesson.is_empty(): return lesson
	if customer_state=="closed" and tables.people.is_empty(): return {"text":"Jour terminé : ouvre le MENU pour commencer le jour suivant.","target":""}
	if room=="dining": return {"text":"Clique sur une table pour la servir. TABLES [O] affiche les commandes à préparer.","target":""}
	if room=="restaurant" and tables and not tables.people.is_empty(): return {"text":"%d tables occupées : TABLES [O] pour choisir une commande, puis SALLE pour servir." % tables.people.size(),"target":"snack_dining" if holding>=0 else "kitchen"}
	if room=="restaurant" and customer_state=="waiting": return {"text":"Accueille le client et choisis une table libre.","target":"client"}
	if room=="office": return {"text":"Cliquez sur le PC pour commander, ou sur le canapé pour sauvegarder.","target":"computer"}
	if room=="garden": return {"text":"Récoltez dans les bacs. EXPLORER mène aux ingrédients sauvages.","target":"garden_planet"}
	if room=="planet": return {"text":"Cliquez sur les plantes sauvages pour découvrir de nouveaux ingrédients.","target":""}
	if customer_state!="waiting": return {"text":"Un client arrive. Profitez-en pour récolter ou visiter le bureau.","target":"moonleaf"}
	if holding>=0:
		if holding!=order: return {"text":"Ce n’est pas sa commande ! Clique pour la donner quand même (client furieux), ou R pour la jeter.","target":""}
		return {"text":"Commande prête ! Clique sur le client pour lui donner.","target":"client"}
	for id in recipe(order).ingredients:
		if inventory[id]<1:
			if ingredient(id).starter and not planters.plants.get(id,"").is_empty(): return {"text":"Il manque "+ingredient(id).name+" : cliquez sur le bac pour récolter.","target":id}
			if coins>=int(ingredient(id).buy_price)*3: return {"text":"Il manque "+ingredient(id).name+" : achetez ses graines au PC, puis plantez-les dans un bac vide.","target":"snack_office"}
			return {"text":"Il manque "+ingredient(id).name+" : plantez une graine dans un bac vide ou explorez la planète.","target":"snack_garden"}
	return {"text":"Ingrédients prêts ! Cliquez sur "+("BOISSONS." if recipe(order).get("kind","wrap")=="drink" else "CUISINER."),"target":"drinks" if recipe(order).get("kind","wrap")=="drink" else "kitchen"}

func draw_interaction_markers() -> void:
	if menu: return
	var hover:=clicked_target(get_global_mouse_position())
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if not hover.is_empty() else Input.CURSOR_ARROW)
	if not hover.is_empty() and hover.get("id")!="console":
		var object_name:=object_hover_name(hover)
		var width:=maxf(120,ThemeDB.fallback_font.get_string_size(object_name,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+20)
		var at:=get_global_mouse_position()
		at.x=clampf(at.x+15,10,1190-width)
		at.y=clampf(at.y-34,90,630)
		panel(Rect2(at,Vector2(width,28)),Color("172b35"),4)
		label_at(object_name,at+Vector2(10,19),14,Color("8edce5"))
	if move_goal>=0:
		var x:=move_goal-camera_x
		draw_arc(Vector2(x,540),12,0,TAU,24,Color("8ed4d5"),2,true)

func object_hover_name(target: Dictionary) -> String:
	if target.get("action")=="welcome": return "Accueil du client"
	if target.get("action")=="table_visit": return "Table %d" % int(target.table)
	var id: String=target.get("id","")
	var names={"trash":"Poubelle","kitchen":"Grill à wraps","counter":"Comptoir","drinks":"Distributeur de boissons","upgrade":"Terrasse","couch":"Canapé","computer":"Ordinateur","console":"Pokéball"}
	if names.has(id): return names[id]
	if id=="client": return str(sheet.customers[actor_customer].name)
	if planters.plants.has(id): return planters.name_of(id)
	for item in sheet.ingredients:
		if item.id==id: return str(item.name)
	for plant in sheet.beds+sheet.wild_nodes:
		if plant.id==id:
			return str(ingredient(plant.ingredient).name) if plant.ingredient in discovered else "Plante inconnue"
	var doors={"restaurant":"Porte du restaurant","office":"Porte du bureau","garden":"Porte de la serre","planet":"Passage vers la planète","dining":"Porte de la salle"}
	for door in sheet.doors:
		if door.id==id: return str(doors.get(door.target,"Porte"))
	return "Objet"

func setup_ambience() -> void:
	music_player=AudioStreamPlayer.new()
	var stream: AudioStreamWAV=load("res://art/orbital-lounge.wav")
	stream=stream.duplicate()
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_end=int(stream.get_length()*stream.mix_rate)
	music_player.stream=stream
	music_player.volume_db=float(sheet.ambience[0].volume_db)
	add_child(music_player)
	music_player.play()
	music_player.stream_paused=not ambience_enabled

func set_ambience(value: bool) -> void:
	ambience_enabled=value
	if is_instance_valid(music_player): music_player.stream_paused=not value
	save_settings()

func draw_ambient_decor() -> void:
	var t:=ambient_clock
	if room=="restaurant":
		for index in range(22):
			var x:=35+fmod(index*61.0+t*(1+index%3),438)
			var y:=198+fmod(index*37.0,163)
			var alpha:=0.25+0.2*sin(t*1.3+index)
			draw_circle(Vector2(x,y),0.8+index%2*0.4,Color(0.7,0.86,1,alpha))
		var ship:=Vector2(42+fmod(t*17,420),248+sin(t*0.3)*12)
		draw_line(ship-Vector2(10,0),ship+Vector2(12,0),Color("bec8cf"),3,true)
		draw_line(ship-Vector2(6,3),ship+Vector2(5,-4),Color("768b9b"),2,true)
		draw_line(ship-Vector2(12,0),ship-Vector2(23+sin(t*10)*3,0),Color(0.48,0.85,1,0.4),2,true)
		for index in range(4):
			var rise:=fmod(t*15+index*19,65)
			draw_arc(Vector2(640+sin(t+index)*5,405-rise),8,0.1,2.5,12,Color(1,0.9,0.7,(1-rise/65)*0.15),2,true)
		for at in [Vector2(511,225),Vector2(1085,231)]:
			draw_circle(at,16,Color(1,0.78,0.45,0.04+sin(t*2)*0.015))
	elif room=="office":
		var y:=337+fmod(t*13,52)
		draw_line(Vector2(824,y),Vector2(977,y),Color(0.25,0.86,1,0.25),1,true)
		draw_arc(Vector2(899,365),19, t,t+PI*1.5,28,Color(0.45,0.9,1,0.5),1.5,true)
		for index in range(6): draw_line(Vector2(832+index*6,383),Vector2(832+index*6,377-sin(t*2+index)*5),Color(0.4,0.9,1,0.45),2,true)
	else:
		for index in range(16):
			var x:=fmod(index*83+t*(6+index%4),1200)
			var y:=280+sin(t*0.5+index)*65+index%5*18
			var tint:=Color(0.8,1,0.55,0.2+0.2*sin(t*2+index)) if room=="garden" else Color(0.4,0.85,1,0.2+0.15*sin(t+index))
			draw_circle(Vector2(x,y),1.7,tint)
			if room=="garden": draw_circle(Vector2(x,y),4,Color(tint.r,tint.g,tint.b,tint.a*0.13))
		if room=="planet":
			var fall:=fmod(t*40,1400)
			draw_line(Vector2(1200-fall,165+fall*0.1),Vector2(1225-fall,161+fall*0.1),Color(0.7,0.85,1,0.35),2,true)

func migrate_previous_saves() -> void:
	var current=ProjectSettings.globalize_path("user://").trim_suffix("/")
	var previous=current.get_base_dir()+"/Cosmo Wrap — Premier service"
	if not DirAccess.dir_exists_absolute(previous): return
	DirAccess.make_dir_recursive_absolute(current)
	for name in ["progress.json","sofa-save.json","settings.json","creator-world.json"]:
		if not FileAccess.file_exists(current+"/"+name) and FileAccess.file_exists(previous+"/"+name):
			DirAccess.copy_absolute(previous+"/"+name,current+"/"+name)

func restore_counter(value: Variant) -> void:
	counter_items.clear()
	if not value is Array: return
	var seen: Array=[]
	for item in value:
		if not item is Dictionary or counter_items.size()>=12: continue
		var id:=int(item.get("id",0))
		var index:=int(item.get("recipe",-1))
		var number:=int(item.get("table",0))
		if id<=0 or id in seen or index<0 or index>=sheet.recipes.size() or number<0 or number>8: continue
		seen.append(id)
		counter_serial=maxi(counter_serial,id)
		counter_items.append({"id":id,"recipe":index,"table":number})
func store_order(number: int) -> bool:
	if online and online.request("store_order",{"table":number}): return false
	if holding<0 or counter_items.size()>=12 or number<0 or number>8:
		say("Il faut une commande en main et une place au comptoir."); return false
	counter_serial+=1
	counter_items.append({"id":counter_serial,"recipe":holding,"table":number})
	holding=-1
	say("Commande posée au comptoir · table %d. Tu peux continuer à cuisiner." % number)
	save_progress()
	return true
func cook_store(number: int) -> bool:
	if online and online.request("cook_store",{"table":number,"recipe":selected}): return false
	var entry: Dictionary=tables.person(number)
	if entry.is_empty() or entry.state in ["eating","leaving"] or counter_items.size()>=12:
		say("Choisis un ticket actif ; le comptoir peut accueillir 12 commandes."); return false
	if not cook(): return false
	return store_order(number)
func take_order(id: int) -> bool:
	if online and online.request("take_order",{"id":id}): return false
	if holding>=0: say("Tes mains sont déjà occupées."); return false
	for i in range(counter_items.size()):
		if int(counter_items[i].id)==id:
			holding=int(counter_items[i].recipe)
			say("À servir : table %d · %s." % [counter_items[i].table,recipe(holding).name])
			counter_items.remove_at(i)
			save_progress()
			return true
	say("Cette commande a déjà été récupérée.")
	return false
func build_counter(box: VBoxContainer) -> void:
	box.add_child(ui.label("%d / 12 commandes prêtes · récupère puis clique sur la table dans la salle." % counter_items.size(),15))
	if holding>=0:
		box.add_child(ui.button("POSER · TABLE %d" % tables.selected,func():
			if store_order(tables.selected): ui.show_page("counter")))
	for item in counter_items:
		var dish: Dictionary=item.duplicate()
		var b: Button=ui.button("TABLE %d · %s · RÉCUPÉRER" % [dish.table,recipe(int(dish.recipe)).name],func():
			if take_order(int(dish.id)): ui.hide_page())
		b.disabled=holding>=0
		box.add_child(b)
	if counter_items.is_empty(): box.add_child(ui.label("Prépare un ticket en cuisine et choisis PRÉPARER ET POSER.",16))

func prepare_crop(id: String) -> bool:
	if online and online.request("prepare_crop",{"id":id}): return false
	if preload("res://ingredient_prep.gd").tool_for(id).is_empty() or inventory.get("raw_"+id,0)<1:
		say("Il manque une récolte brute à traiter."); return false
	inventory["raw_"+id]-=1
	inventory[id]+=1
	say("+1 "+str(ingredient(id).name)+" préparé dans le saladier.")
	play_sound(620)
	save_progress()
	return true
