extends CanvasLayer

var game: Node2D
var header: PanelContainer
var hotbar: HBoxContainer
var status: Label
var credits: Label
var task: Label
var slots: Array[Button] = []
var overlay: Control
var window: PanelContainer
var page := "menu"
var race_buttons: Array[Button] = []

const CYAN = Color("72d8ee")
const TEXT = Color("dfecf5")

class IngredientIcon extends Control:
	var kind := 0
	func _draw() -> void:
		var center := size*0.5
		if kind==0:
			for i in range(5):
				draw_circle(center+Vector2(sin(i*1.4)*9,cos(i*1.4)*4),7,Color("70b965") if i%2==0 else Color("98d576"))
			draw_line(center+Vector2(-6,8),center+Vector2(7,-7),Color("c1e88e"),2,true)
		elif kind==1:
			draw_circle(center,12,Color("c74e3a"))
			draw_circle(center+Vector2(-3,-3),8,Color("e57651"))
			for i in range(5): draw_line(center+Vector2(0,-10),center+Vector2(sin(i*TAU/5)*6,-10+cos(i*TAU/5)*4),Color("86ba69"),3,true)
		else:
			draw_rect(Rect2(center+Vector2(-3,-1),Vector2(6,13)),Color("dcc9af"))
			draw_circle(center+Vector2(0,-2),12,Color("a67abb"))
			draw_circle(center+Vector2(-4,-5),7,Color("c59cce"))
			draw_line(center+Vector2(-10,4),center+Vector2(10,4),Color("665775"),3,true)

func skin(bg: Color, border: Color = Color("496881"), width: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_content_margin_all(12)
	s.shadow_color = Color(0,0,0,0.4)
	s.shadow_size = 5
	return s

func label(words: String, size: int = 18, tint: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = words
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size",size)
	node.add_theme_color_override("font_color",tint)
	return node

func button(words: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = words
	node.custom_minimum_size = Vector2(0,42)
	node.add_theme_font_size_override("font_size",17)
	node.add_theme_color_override("font_color",TEXT)
	node.add_theme_stylebox_override("normal",skin(Color("192a3d")))
	node.add_theme_stylebox_override("hover",skin(Color("29485e"),CYAN))
	node.add_theme_stylebox_override("pressed",skin(Color("375d70"),CYAN))
	node.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	node.pressed.connect(action)
	return node

func _ready() -> void:
	game = get_parent()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	header = PanelContainer.new()
	header.position = Vector2(16,14)
	header.size = Vector2(1168,67)
	header.add_theme_stylebox_override("panel",skin(Color("111d2e")))
	root.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	header.add_child(row)
	row.add_child(label("COSMO WRAP",22,CYAN))
	var vitals := VBoxContainer.new()
	vitals.custom_minimum_size.x = 150
	row.add_child(vitals)
	vitals.add_child(label("VITALITÉ   100 / 100",12,Color("ef9a98")))
	var health := ProgressBar.new()
	health.value = 100
	health.show_percentage = false
	health.custom_minimum_size.y = 8
	health.add_theme_stylebox_override("background",skin(Color("2a2130"),Color("2a2130"),0))
	health.add_theme_stylebox_override("fill",skin(Color("d87980"),Color("d87980"),0))
	vitals.add_child(health)
	credits = label("",17,Color("efd37d"))
	credits.custom_minimum_size.x = 130
	row.add_child(credits)
	task = label("",15)
	task.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(task)
	row.add_child(button("SAC [I]",func(): show_page("inventory")))
	row.add_child(button("MENU [Échap]",func(): show_page("menu")))
	hotbar = HBoxContainer.new()
	hotbar.position = Vector2(374,93)
	hotbar.add_theme_constant_override("separation",7)
	root.add_child(hotbar)
	for i in range(3):
		var index := i
		var slot := button("",func(): game.selected=index)
		slot.custom_minimum_size = Vector2(148,57)
		slot.add_theme_font_size_override("font_size",14)
		hotbar.add_child(slot)
		slots.append(slot)
	var footer := PanelContainer.new()
	footer.position = Vector2(16,634)
	footer.size = Vector2(1168,70)
	footer.add_theme_stylebox_override("panel",skin(Color("111d2e")))
	root.add_child(footer)
	var text_column := VBoxContainer.new()
	footer.add_child(text_column)
	status = label("",17,Color("efd37d"))
	text_column.add_child(status)
	text_column.add_child(label("← → / Q D : marcher   E : agir   1 2 3 : recette   Espace : sauter   R : ranger   I : inventaire",13,Color("9fb9cb")))
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01,0.02,0.05,0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	show_page("menu")

func clear_window(title: String) -> VBoxContainer:
	if is_instance_valid(window):
		overlay.remove_child(window)
		window.queue_free()
	window = PanelContainer.new()
	window.position = Vector2(270,164)
	window.size = Vector2(660,0)
	window.add_theme_stylebox_override("panel",skin(Color("101d2e"),CYAN))
	overlay.add_child(window)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	window.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var heading := label(title,26,CYAN)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	top.add_child(button("FERMER",hide_page))
	box.add_child(HSeparator.new())
	return box

func hide_page() -> void:
	overlay.hide()
	game.menu = false
	game.save_settings()

func show_page(name: String) -> void:
	page = name
	game.menu = true
	overlay.show()
	var box := clear_window({"menu":"COSMO WRAP / MENU","inventory":"INVENTAIRE","options":"OPTIONS DE JEU","races":"CHOISIR UNE RACE","confirm":"NOUVEAU SERVICE"}.get(name,"MENU"))
	if name=="inventory": window.position.y = 82
	elif name=="races": window.position.y = 100
	match name:
		"menu":
			box.add_child(label("Snack orbital • Solo • Clients patients",16,Color("9fb9cb")))
			box.add_child(button("JOUER / REPRENDRE",hide_page))
			box.add_child(button("INVENTAIRE",func(): show_page("inventory")))
			box.add_child(button("PERSONNAGE ET RACES",func(): show_page("races")))
			box.add_child(button("OPTIONS",func(): show_page("options")))
			box.add_child(button("NOUVEAU SERVICE",func(): show_page("confirm")))
			box.add_child(button("QUITTER LE JEU",func(): game.save_progress(); get_tree().quit()))
		"confirm":
			box.add_child(label("Recommencer remet les crédits et la terrasse à zéro.",17))
			box.add_child(button("RECOMMENCER",func(): game.new_service(); hide_page()))
			box.add_child(button("ANNULER",func(): show_page("menu")))
		"inventory":
			box.add_child(label("Ingrédients disponibles • Les wraps ne périment pas",15,Color("9fb9cb")))
			var grid := GridContainer.new()
			grid.columns = 6
			grid.add_theme_constant_override("h_separation",5)
			grid.add_theme_constant_override("v_separation",5)
			box.add_child(grid)
			for i in range(18):
				var slot := PanelContainer.new()
				slot.custom_minimum_size = Vector2(98,65)
				var slot_skin := skin(Color("1b2b40"))
				slot_skin.set_content_margin_all(5)
				slot.add_theme_stylebox_override("panel",slot_skin)
				grid.add_child(slot)
				if i<3:
					var item: Dictionary = game.sheet.ingredients[i]
					var stack := VBoxContainer.new()
					slot.add_child(stack)
					var icon := IngredientIcon.new()
					icon.kind = i
					icon.custom_minimum_size.y = 27
					stack.add_child(icon)
					var content := label(["SALADE","TOMATE","CHAMPI"][i]+" × "+str(game.inventory[item.id]),12,Color(item.color))
					content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					stack.add_child(content)
					slot.tooltip_text = item.name
				elif i==3 and game.holding>=0:
					slot.add_child(label("WRAP\n× 1",14,Color("efd37d")))
					slot.tooltip_text = game.recipe(game.holding).name
			box.add_child(label("RECETTES / choisir pour la cuisine",18,CYAN))
			for i in range(3):
				var index := i
				var recipe: Dictionary = game.recipe(i)
				var recipe_button := button(str(i+1)+" · "+recipe.name+"  /  "+str(int(recipe.price))+" crédits",func(): game.selected=index; hide_page())
				var names: Array[String] = []
				for id in recipe.ingredients:
					for ingredient in game.sheet.ingredients:
						if ingredient.id==id: names.append(ingredient.name)
				recipe_button.tooltip_text = " + ".join(names)
				box.add_child(recipe_button)
			if game.holding>=0:
				box.add_child(button("RANGER LE WRAP / récupérer les ingrédients",func(): game.return_wrap(); show_page("inventory")))
		"races":
			box.add_child(label("Sept races • Choix visuel, les recettes restent les mêmes",15,Color("9fb9cb")))
			for i in range(game.sheet.races.size()):
				var index := i
				var race: Dictionary = game.sheet.races[i]
				box.add_child(button(("● " if game.player_race==race.id else "○ ")+race.name,func(): game.player_race=game.sheet.races[index].id; game.save_settings(); show_page("races")))
		"options":
			var fullscreen := CheckButton.new()
			fullscreen.text = "Plein écran"
			fullscreen.button_pressed = game.fullscreen
			fullscreen.toggled.connect(func(value): game.set_fullscreen(value))
			box.add_child(fullscreen)
			var sound := CheckButton.new()
			sound.text = "Sons des actions"
			sound.button_pressed = game.sound_enabled
			sound.toggled.connect(func(value): game.sound_enabled=value; game.save_settings(); game.play_sound(550))
			box.add_child(sound)
			box.add_child(label("Luminosité du décor",17))
			var brightness := HSlider.new()
			brightness.min_value = 0.55
			brightness.max_value = 1.25
			brightness.step = 0.05
			brightness.value = game.brightness
			brightness.value_changed.connect(func(value): game.brightness=value; game.save_settings())
			box.add_child(brightness)
			box.add_child(label("Vitesse de déplacement",17))
			var speed := OptionButton.new()
			for words in ["Détente", "Normale", "Rapide"]: speed.add_item(words)
			speed.select(game.speed_setting)
			speed.item_selected.connect(func(index): game.speed_setting=index; game.save_settings())
			box.add_child(speed)
			box.add_child(label("Touches : Q/D ou flèches • E agir • I inventaire • Échap menu",15,Color("9fb9cb")))
			box.add_child(button("RETOUR AU MENU",func(): show_page("menu")))

func _process(_delta: float) -> void:
	credits.text = "◈ %d crédits" % game.coins
	task.text = "SERVICE : %d / 3" % mini(game.served,3)
	if game.served>=3: task.text = "SERVICE RÉUSSI ✓"
	status.text = game.message if game.message_time>0 else "E : agir près d'un poste. I : inventaire. Les clients prennent leur temps."
	for i in range(3):
		slots[i].text = "%d  %s\n%d CR" % [i+1,game.recipe(i).name,game.recipe(i).price]
		var names: Array[String] = []
		for id in game.recipe(i).ingredients:
			for ingredient in game.sheet.ingredients:
				if ingredient.id==id: names.append("%s (%d)" % [ingredient.name,game.inventory[id]])
		slots[i].tooltip_text = " + ".join(names)
		slots[i].add_theme_stylebox_override("normal",skin(Color("31506b") if game.selected==i else Color("142237"),CYAN if game.selected==i else Color("496881")))
