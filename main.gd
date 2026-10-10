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

func _ready() -> void:
	sheet = JSON.parse_string(FileAccess.get_file_as_string("res://data/design.json"))
	for item in sheet.ingredients:
		inventory[item.id] = 0
		cooldowns[item.id] = 0.0
	load_progress()
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
	say("Wrap prêt ! Direction le comptoir.")
	return true

func serve() -> bool:
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
	if not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_ESCAPE:
		menu = not menu
	elif menu and event.keycode in [KEY_ENTER, KEY_SPACE]:
		menu = false
	elif not menu:
		match event.keycode:
			KEY_1: selected = 0
			KEY_2: selected = 1
			KEY_3: selected = 2
			KEY_E: interact()
			KEY_SPACE:
				if player.y >= 505: vertical = -450
			KEY_R:
				if holding >= 0:
					for ingredient in recipe(holding).ingredients:
						inventory[ingredient] += 1
					holding = -1
					say("Ingrédients rangés : rien n'est perdu.")
			KEY_N:
				coins = 0
				served = 0
				upgraded = false
				completed = false
				customer = 0
				order = 0
				holding = -1
				for id in inventory:
					inventory[id] = 0
					cooldowns[id] = 0.0
				save_progress()
				say("Nouveau service !")

func _process(delta: float) -> void:
	clock += delta
	if not menu:
		var axis := float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_LEFT))
		walking = absf(axis) > 0
		if walking:
			facing = signf(axis)
			walk_cycle += delta * float(animation("walk").frequency)
		action_time = maxf(0.0, action_time - delta)
		player.x = clampf(player.x + axis * 240 * delta, 40, 1160)
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
		customer = posmod(int(saved.get("customer", 0)), 3)
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
	var phase := walk_cycle if chef else clock * float(animation("idle").frequency)
	var stride := sin(phase) * float(animation("walk").amplitude) if chef and walking else sin(phase) * float(animation("idle").amplitude)
	var bounce := absf(cos(phase)) * 2.0 if chef and walking else sin(clock * 2) * 1.0
	var direction := facing if chef else -1.0
	var skin := Color("e5b388") if chef else color.lightened(0.2)
	var shirt := Color("f6eddc") if chef else color.darkened(0.3)
	var pants := Color("343940")
	var origin := position + Vector2(0, -6 - bounce)
	draw_set_transform(position + Vector2(0,37), 0, Vector2(1.6,0.28))
	draw_circle(Vector2.ZERO,22,Color(0.05,0.03,0.02,0.3))
	draw_set_transform(origin,0,Vector2(direction,1))
	# Articulated knees, forearms and feet: a proper walking silhouette.
	for side in [-1,1]:
		var hip := Vector2(side*7,9)
		var knee := Vector2(side*7 + stride*side*0.55,23)
		var ankle := Vector2(side*7 + stride*side,40)
		draw_line(hip,knee,pants.darkened(0.12 if side<0 else 0),11,true)
		draw_line(knee,ankle,pants,9,true)
		panel(Rect2(ankle+Vector2(-5,-3),Vector2(17,7)),Color("352b2b"),3)
	panel(Rect2(-18,-22,36,37),shirt,8)
	if chef:
		panel(Rect2(-12,-12,24,32),Color("b16b47"),3)
		draw_line(Vector2(-11,-22),Vector2(-7,6),Color("b16b47"),3,true)
		draw_line(Vector2(11,-22),Vector2(7,6),Color("b16b47"),3,true)
		panel(Rect2(-7,5,14,8),Color("8f5039"),2)
	else:
		draw_line(Vector2(0,-20),Vector2(0,11),shirt.lightened(0.18),2,true)
	for side in [-1,1]:
		var shoulder := Vector2(side*18,-15)
		var elbow := Vector2(side*22 - stride*side*0.35,0)
		var hand := Vector2(side*20-stride*side*0.7,13)
		if chef and side==1 and (holding>=0 or action_time>0):
			elbow = Vector2(26,-4)
			hand = Vector2(37,-16 + sin(action_time*24)*4 if action_time>0 else -13)
		draw_line(shoulder,elbow,shirt.darkened(0.1),10,true)
		draw_line(elbow,hand,skin,7,true)
		draw_circle(hand,4,skin)
		if chef and side==1 and holding>=0:
			draw_set_transform(origin+Vector2(hand.x*direction,hand.y-6),-0.2*direction)
			panel(Rect2(-6,-13,22,17),Color("efd1a0"),5)
			draw_line(Vector2(-3,-10),Vector2(12,-10),Color("6a9e50"),4,true)
			draw_line(Vector2(1,-9),Vector2(9,-9),Color("c85240"),3,true)
			draw_set_transform(origin,0,Vector2(direction,1))
	draw_line(Vector2(0,-22),Vector2(0,-31),skin.darkened(0.1),10,true)
	panel(Rect2(-15,-59,30,32),skin,12)
	draw_circle(Vector2(15,-41),4,skin.darkened(0.03))
	draw_circle(Vector2(8,-47),2,Color("302e35"))
	draw_line(Vector2(5,-51),Vector2(11,-51),Color("644a3d"),2,true)
	draw_line(Vector2(10,-36),Vector2(4,-34),Color("935c50"),2,true)
	draw_circle(Vector2(14,-42),2,Color("f0bf95") if chef else skin)
	if chef:
		panel(Rect2(-18,-63,36,9),Color("fff7e7"),3)
		for x in [-10,0,10]: draw_circle(Vector2(x,-66),9,Color("fff7e7"))
		draw_line(Vector2(-15,-55),Vector2(12,-55),Color("dcc9ac"),2,true)
	else:
		panel(Rect2(-16,-63,30,11),color.darkened(0.5),5)
		draw_line(Vector2(-10,-59),Vector2(-15,-72),color,3,true)
		draw_circle(Vector2(-15,-73),4,color.lightened(0.25))
	draw_set_transform(Vector2.ZERO)

func _draw() -> void:
	if sheet.is_empty(): return
	if backdrop:
		draw_texture_rect(backdrop,Rect2(0,0,float(sheet.visuals[0].width),float(sheet.visuals[0].height)),false)
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
	alien(Vector2(946,505),Color(sheet.customers[customer].color))
	alien(player,Color("bca2e9"),true)
	panel(Rect2(803,205,367,77),Color("eee2c9"),10)
	label_at(sheet.customers[customer].name+" · "+recipe(order).name,Vector2(818,232),19,Color("44382e"))
	label_at(sheet.customers[customer].line,Vector2(818,254),13,Color("685446"))
	label_at("Client patient · Prenez votre temps",Vector2(818,273),12,Color("8b7055"))
	panel(Rect2(22,19,1156,64),Color("302b27"))
	label_at("COSMO / WRAP",Vector2(42,58),25,Color("ffd696"))
	label_at("PREMIER SERVICE · SOLO · TRANQUILLE",Vector2(300,56),16,Color("91b2bc"))
	label_at("%d crédits    %d / 3 clients" % [coins,served],Vector2(880,57),21,Color("f9d47b"))
	for i in range(3):
		var x := 25 + i*390
		panel(Rect2(x,98,370,92),Color("67503a") if selected==i else Color("302b27"))
		label_at("%d  %s" % [i+1,recipe(i).name],Vector2(x+15,127),21,Color("ffd696") if selected==i else Color("c4d4df"))
		var parts: Array[String] = []
		for id in recipe(i).ingredients:
			for ingredient in sheet.ingredients:
				if ingredient.id == id: parts.append("%s (%d)" % [ingredient.name,inventory[id]])
		label_at(" + ".join(parts),Vector2(x+15,153),13)
		label_at(recipe(i).joke,Vector2(x+15,174),13,Color("91b2bc"))
	panel(Rect2(25,612,1150,82),Color("302b27"))
	label_at(message if message_time > 0 else "Prenez votre temps. Vos clients ne partent jamais sans leur wrap.",Vector2(45,642),18,Color("ffd696"))
	label_at("← → / Q D : marcher    E : agir    1 2 3 : recette    Espace : sauter    R : ranger    Échap : pause    N : recommencer",Vector2(45,677),15,Color("91b2bc"))
	if menu:
		draw_rect(Rect2(0,0,1200,720),Color(0.02,0.03,0.08,0.85))
		panel(Rect2(260,190,680,355),Color("203140"),22)
		label_at("COSMO WRAP",Vector2(370,266),48,Color("ffd696"))
		label_at("Une petite cuisine. Un très grand univers.",Vector2(370,309),21)
		label_at("1. Récoltez deux ingrédients au jardin, à gauche.",Vector2(310,367),20)
		label_at("2. Choisissez la recette commandée, puis cuisinez.",Vector2(310,402),20)
		label_at("3. Servez trois aliens et ouvrez votre terrasse !",Vector2(310,437),20)
		label_at("ENTRÉE pour jouer · Aucun chrono, aucun stress",Vector2(325,506),21,Color("91dbc2"))
