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
var menu := true
var completed := false
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	sheet = JSON.parse_string(FileAccess.get_file_as_string("res://data/design.json"))
	for item in sheet.ingredients:
		inventory[item.id] = 0
		cooldowns[item.id] = 0.0
	load_progress()

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
	draw_circle(position + Vector2(0, -23), 23, color)
	panel(Rect2(position + Vector2(-19, -9), Vector2(38, 39)), color)
	draw_circle(position + Vector2(-8, -26), 5, Color("17243d"))
	draw_circle(position + Vector2(8, -26), 5, Color("17243d"))
	draw_arc(position + Vector2(0,-17), 7, 0, PI, 12, Color("17243d"), 2)
	draw_line(position + Vector2(-10,27), position + Vector2(-12,39), color, 8)
	draw_line(position + Vector2(10,27), position + Vector2(12,39), color, 8)
	if chef:
		panel(Rect2(position + Vector2(-19,-55),Vector2(38,17)),Color("fff1d8"),5)
		for x in [-12,0,12]: draw_circle(position + Vector2(x,-58), 10, Color("fff1d8"))
		panel(Rect2(position + Vector2(-13,-4),Vector2(26,26)),Color("fff1d8"),4)

func _draw() -> void:
	if sheet.is_empty(): return
	for i in range(85):
		var point := Vector2(fmod(i * 127.7,1200), fmod(i * 73.3,420) + 75)
		draw_circle(point, 1.0 + (i % 3) * 0.4, Color(0.7,0.8,1,0.25 + 0.2 * sin(clock + i)))
	draw_circle(Vector2(180,220),85,Color("242e53"))
	draw_arc(Vector2(180,220),110,-0.3,3.4,64,Color("41486f"),12)
	for i in range(7):
		draw_circle(Vector2(i*210,530),110,Color("1d354b"))
	draw_rect(Rect2(0,545,1200,175),Color("253748"))
	draw_line(Vector2(0,546),Vector2(1200,546),Color("6ea593"),4)
	panel(Rect2(485,260,690,285),Color("203140"),20)
	panel(Rect2(475,255,710,45),Color("dc9876"),8)
	label_at("COSMO WRAP",Vector2(650,286),26,Color("182637"))
	for x in [520,735,950]:
		panel(Rect2(x,323,175,98),Color("101b32"),8)
		for j in range(5): draw_circle(Vector2(x+20+j*31,342+j%2*42),2,Color("85b4c5"))
	label_at("LE JARDIN ORBITAL",Vector2(80,370),20,Color("91dbc2"))
	for item in sheet.ingredients:
		var x := float(item.x)
		panel(Rect2(x-30,517,60,28),Color("9b6c66"),6)
		draw_line(Vector2(x,520),Vector2(x,455),Color("78b492"),5)
		var color := Color(item.color) if cooldowns[item.id] <= 0 else Color("495a65")
		for shift in [-17,0,17]: draw_circle(Vector2(x+shift,473-abs(shift)),14,color)
		label_at(item.name,Vector2(x-65,580),15)
		if cooldowns[item.id] > 0: label_at("%ds" % ceili(cooldowns[item.id]),Vector2(x-12,441),16)
		if absf(player.x-x)<58 and not menu: label_at("[E] Récolter",Vector2(x-45,410),16,Color("f9d47b"))
	panel(Rect2(598,472,105,73),Color("7297a0"),8)
	draw_rect(Rect2(590,462,120,12),Color("dce4dd"))
	for x in [620,655,685]: draw_circle(Vector2(x,462),8,Color("ffb579"))
	panel(Rect2(792,476,125,69),Color("c89170"),8)
	panel(Rect2(1018,478,139,67),Color("7e8e80") if upgraded else Color("415460"),8)
	label_at("Cuisine [E]",Vector2(605,580),17)
	label_at("Servir [E]",Vector2(803,580),17)
	label_at("Terrasse ouverte" if upgraded else "Terrasse : 35 [E]",Vector2(1018,580),16)
	if upgraded:
		for x in [1035,1130]:
			draw_line(Vector2(x,478),Vector2(x,403),Color("d4ba8c"),4)
			draw_colored_polygon(PackedVector2Array([Vector2(x-33,416),Vector2(x,389),Vector2(x+33,416)]),Color("f9d47b"))
	alien(Vector2(941,501 + sin(clock*2)*2),Color(sheet.customers[customer].color))
	panel(Rect2(795,355,362,90),Color("fff1d8"),12)
	label_at(sheet.customers[customer].name + " commande",Vector2(810,380),18,Color("445064"))
	label_at(recipe(order).name,Vector2(810,406),22,Color("253748"))
	label_at(sheet.customers[customer].line,Vector2(810,431),13,Color("596273"))
	alien(player,Color("bca2e9"),true)
	if holding >= 0:
		panel(Rect2(player+Vector2(18,-12),Vector2(27,17)),Color("e6c18b"),5)
		draw_line(player+Vector2(22,-9),player+Vector2(40,-9),Color("83d79d"),4)
	panel(Rect2(22,19,1156,64),Color("162538"))
	label_at("COSMO / WRAP",Vector2(42,58),25,Color("ffd696"))
	label_at("PREMIER SERVICE · SOLO · TRANQUILLE",Vector2(300,56),16,Color("91b2bc"))
	label_at("%d crédits    %d / 3 clients" % [coins,served],Vector2(880,57),21,Color("f9d47b"))
	for i in range(3):
		var x := 25 + i*390
		panel(Rect2(x,98,370,92),Color("334755") if selected==i else Color("18283b"))
		label_at("%d  %s" % [i+1,recipe(i).name],Vector2(x+15,127),21,Color("ffd696") if selected==i else Color("c4d4df"))
		var parts: Array[String] = []
		for id in recipe(i).ingredients:
			for ingredient in sheet.ingredients:
				if ingredient.id == id: parts.append("%s (%d)" % [ingredient.name,inventory[id]])
		label_at(" + ".join(parts),Vector2(x+15,153),13)
		label_at(recipe(i).joke,Vector2(x+15,174),13,Color("91b2bc"))
	panel(Rect2(25,612,1150,82),Color("162538"))
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
