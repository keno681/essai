extends CanvasLayer
const ART=preload("res://visual_library.gd")

var game: Node2D
var header: PanelContainer
var hotbar: HBoxContainer
var guidance: Label
var status: Label
var credits: Label
var task: Label
var slots: Array[Button] = []
var overlay: Control
var window: PanelContainer
var page := "menu"
var race_buttons: Array[Button] = []

var CYAN = Color("edc478")
const TEXT = Color("dfecf5")

class DuckIcon extends Control:
	func _draw() -> void:
		draw_texture_rect(preload("res://visual_library.gd").interface(0),Rect2(Vector2.ZERO,size),false)

class ConsoleTrim extends Control:
	func _draw() -> void:
		for y in [14,634]:
			for x in [16,1184]:
				draw_circle(Vector2(x+7 if x==16 else x-7,y+7),3,Color("8197a3"))
				draw_line(Vector2(x+5 if x==16 else x-9,y+7),Vector2(x+9 if x==16 else x-5,y+7),Color("293a48"),1)
		for i in range(6):
			draw_line(Vector2(35+i*9,615),Vector2(40+i*9,605),Color("bd975b"),3,true)

class IngredientIcon extends Control:
	var kind := 0
	func _draw() -> void:
		draw_texture_rect(preload("res://visual_library.gd").food(kind),Rect2(Vector2.ZERO,size),false)

func skin(bg: Color, border: Color = Color("496881"), width: int = 2) -> StyleBox:
	if width == 0:
		var flat := StyleBoxFlat.new()
		flat.bg_color = bg
		flat.set_corner_radius_all(3)
		return flat
	var luminance := (bg.r+bg.g+bg.b)/3.0
	var tint := Color(0.55+luminance,0.60+luminance,0.65+luminance)
	if border == CYAN: tint = tint.lightened(0.08)
	return ART.frame(tint)

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
	node.focus_mode = Control.FOCUS_NONE
	node.custom_minimum_size = Vector2(0,42)
	node.add_theme_font_size_override("font_size",17)
	node.add_theme_color_override("font_color",TEXT)
	node.add_theme_color_override("font_disabled_color",Color("80929b"))
	node.add_theme_stylebox_override("disabled",skin(Color("1c2930"),Color("4c5e67")))
	node.add_theme_stylebox_override("normal",skin(Color("192a3d")))
	node.add_theme_stylebox_override("hover",skin(Color("29485e"),CYAN))
	node.add_theme_stylebox_override("pressed",skin(Color("375d70"),CYAN))
	node.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	var markings := SpaceButtonTrim.new()
	markings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	markings.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_child(markings)
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
	header.add_theme_stylebox_override("panel",ART.panel_frame(Color(0.7,0.75,0.8),18))
	root.add_child(header)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",16)
	header.add_child(row)
	row.add_child(label("COSMO WRAP BALL",18,CYAN))
	var vitals := VBoxContainer.new()
	vitals.custom_minimum_size.x = 150
	row.add_child(vitals)
	vitals.add_child(label("SYSTÈMES / ACTIFS",12,Color("88c9c5")))
	var health := ProgressBar.new()
	health.value = 100
	health.show_percentage = false
	health.custom_minimum_size.y = 8
	health.add_theme_stylebox_override("background",skin(Color("2a2130"),Color("2a2130"),0))
	health.add_theme_stylebox_override("fill",skin(Color("68aaa5"),Color("68aaa5"),0))
	vitals.add_child(health)
	var duck := DuckIcon.new()
	duck.custom_minimum_size = Vector2(34,32)
	row.add_child(duck)
	credits = label("",16,Color("efd37d"))
	credits.custom_minimum_size.x = 178
	row.add_child(credits)
	task = label("",15)
	task.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(task)
	row.add_child(button("CHAT [T]",func(): show_page("chat")))
	row.add_child(button("SAC [I]",func(): show_page("inventory")))
	row.add_child(button("MENU [Échap]",func(): show_page("menu")))
	var footer := PanelContainer.new()
	footer.position = Vector2(16,634)
	footer.size = Vector2(1168,70)
	var footer_skin:=ART.panel_frame(Color(0.65,0.70,0.75),12)
	footer_skin.set_content_margin_all(12)
	footer.add_theme_stylebox_override("panel",footer_skin)
	root.add_child(footer)
	var text_column := VBoxContainer.new()
	footer.add_child(text_column)
	guidance=label("",14,CYAN)
	text_column.add_child(guidance)
	status = label("",14,Color("efd37d"))
	text_column.add_child(status)
	text_column.add_child(label("Cliquez sur les lieux pour agir • Q/D ou flèches : marcher • E : agir • I : inventaire • T : discuter",13,Color("9fb9cb")))
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.01,0.02,0.05,0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	show_page("menu")
	var trim := ConsoleTrim.new()
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(trim)

func clear_window(title: String) -> VBoxContainer:
	for child in overlay.get_children():
		if child.has_meta("console_decor"): child.queue_free()
	if is_instance_valid(window):
		overlay.remove_child(window)
		window.queue_free()
	window = PanelContainer.new()
	window.position = Vector2(270,164)
	window.size = Vector2(660,0)
	window.add_theme_stylebox_override("panel",ART.panel_frame(Color(0.7,0.75,0.8),20))
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
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620,420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content

func hide_page() -> void:
	overlay.hide()
	game.menu = false
	game.save_settings()

func show_page(name: String) -> void:
	CYAN=Color(game.console_node.config.accent)
	page = name
	game.menu = true
	overlay.show()
	var box := clear_window({"planter":"BAC DE CULTURE","cookwrap":"COMPOSER TON WRAP","cookdrink":"PRÉPARER UNE BOISSON","chat":"CANAL CLIENT","progress":"ÉVOLUTION DU RESTAURANT","console":"CONSOLE POKÉBALL","menu":game.console_node.config.title+" / COMMANDE","inventory":"INVENTAIRE","options":"OPTIONS DE JEU","races":"CHOISIR UNE RACE","confirm":"NOUVEAU SERVICE","save":"CANAPÉ / SAUVEGARDE","shop":"PC / APPROVISIONNEMENT"}.get(name,"MENU"))
	if name=="inventory": window.position.y = 82
	elif name=="races": window.position.y = 100
	if name in ["cookwrap","cookdrink"]:
		window.position=Vector2(130,55)
		window.size=Vector2(940,0)
		box.get_parent().custom_minimum_size=Vector2(900,495)
	match name:
		"planter":
			game.planters.build(box)
		"cookwrap":
			preload("res://kitchen_dragdrop.gd").build(self,box,"wrap")
		"cookdrink":
			preload("res://kitchen_dragdrop.gd").build(self,box,"drink")
		"console":
			build_console(box)
		"chat":
			box.add_child(label("Conversation avec le client au comptoir",16,CYAN))
			box.add_child(label("Chat autonome · Hors ligne · Gratuit",15,CYAN))
			if game.chat_log.is_empty(): box.add_child(label("Écrivez bonjour, commande, planète…",16))
			for entry in game.chat_log:
				var text := label(entry,16)
				text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
				text.custom_minimum_size.x=600
				box.add_child(text)
			var chat_scroller := box.get_parent() as ScrollContainer
			chat_scroller.custom_minimum_size.y=225
			var latest := box.get_child(box.get_child_count()-1) as Control
			var composer := VBoxContainer.new()
			composer.add_theme_constant_override("separation",10)
			chat_scroller.get_parent().add_child(composer)
			var input := LineEdit.new()
			input.placeholder_text="Votre message au client…"
			input.max_length=int(game.sheet.local_chat[0].message_limit)
			input.custom_minimum_size=Vector2(600,42)
			composer.add_child(input)
			var send := func():
				if game.chat_with_customer(input.text):
					if game.customer_state=="leaving" and game.customer_emotion=="angry": hide_page()
					else: show_page("chat")
				else: input.placeholder_text="Le client doit attendre et être disponible."
			input.text_submitted.connect(func(_text): send.call())
			var send_button := button("TRANSMETTRE",send)
			composer.add_child(send_button)
			var suggestions := HBoxContainer.new()
			composer.add_child(suggestions)
			for phrase in ["Raconte une histoire","Raconte la suite","Tes traditions"]:
				var prompt: String = phrase
				var shortcut := button(phrase,func():
					if game.chat_with_customer(prompt): show_page("chat"))
				shortcut.custom_minimum_size.y=34
				shortcut.add_theme_font_size_override("font_size",13)
				shortcut.size_flags_horizontal=Control.SIZE_EXPAND_FILL
				suggestions.add_child(shortcut)
			composer.add_child(label("Dialogues contextuels locaux : aucune connexion ni clé nécessaire.",13))
			var focus_input := func():
				if is_instance_valid(input) and input.is_inside_tree():
					input.grab_focus()
					if is_instance_valid(latest): chat_scroller.ensure_control_visible(latest)
			focus_input.call_deferred()
		"progress":
			var rank: int = game.restaurant_level()
			box.add_child(label("RANG ACTUEL : "+game.sheet.progression[rank].name,20,CYAN))
			for index in range(game.sheet.progression.size()):
				var level: Dictionary = game.sheet.progression[index]
				box.add_child(label(("✓ " if rank>=index else "○ ")+level.name+" : %d clients · +%d WCC / vente" % [level.served,level.bonus],17))
			box.add_child(label("3 clients : thé lunaire · 8 clients : soda nébuleuse",16))
			box.add_child(label("Le soda nécessite aussi les ingrédients de la planète.",16))
		"save":
			box.add_child(label("Posez-vous un instant. Toute la partie sera conservée.",16,Color("a8bec5")))
			box.add_child(button("SAUVEGARDER SUR LE CANAPÉ",func(): game.save_at_sofa(); show_page("save")))
			var load_button := button("CHARGER LA SAUVEGARDE DU CANAPÉ",func():
				if game.load_at_sofa(): hide_page()
				else: show_page("save"))
			load_button.disabled = not FileAccess.file_exists("user://sofa-save.json")
			box.add_child(load_button)
			var notice := label(game.saving_notice,15)
			notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(notice)
			box.add_child(label("Inventaire, découvertes, livraisons, race et progression.",15,Color("9fb9cb")))
		"shop":
			box.add_child(label("Solde : %d wrapcoincoins" % game.coins,21,CYAN))
			box.add_child(label("Commandez par lots de 3. Fermez le PC : livraison en 4 s.",15,Color("a8bec5")))
			for item in game.sheet.ingredients:
				var id: String = item.id
				var price := int(item.buy_price)*3
				var item_button := button("3 × "+item.name+"  /  %d WCC" % price,func(): game.purchase(id); show_page("shop"))
				if not id in game.discovered:
					item_button.text = "À découvrir sur la planète : "+item.name
					item_button.disabled = true
				elif game.coins<price:
					item_button.disabled = true
					item_button.tooltip_text = "Solde insuffisant"
				box.add_child(item_button)
			box.add_child(label("Livraisons en attente : %d" % game.deliveries.size(),16))
		"menu":
			box.add_child(label("Snack orbital • Solo • Clients patients",16,Color("9fb9cb")))
			box.add_child(button("JOUER / REPRENDRE",hide_page))
			box.add_child(button("ÉVOLUTION DU RESTAURANT",func(): show_page("progress")))
			box.add_child(button("INVENTAIRE",func(): show_page("inventory")))
			box.add_child(button("PERSONNAGE ET RACES",func(): show_page("races")))
			box.add_child(button("CONSOLE POKÉBALL",func(): show_page("console")))
			box.add_child(button("OPTIONS",func(): show_page("options")))
			box.add_child(button("NOUVEAU SERVICE",func(): show_page("confirm")))
			box.add_child(button("QUITTER LE JEU",func(): game.save_progress(); get_tree().quit()))
			box.add_child(label("E devant une porte : bureau, serre ou planète.",14,Color("9fb9cb")))
		"confirm":
			box.add_child(label("Recommencer remet les wrapcoincoins et la terrasse à zéro.",17))
			box.add_child(button("RECOMMENCER",func(): game.new_service(); hide_page()))
			box.add_child(button("ANNULER",func(): show_page("menu")))
		"inventory":
			box.add_child(label("Ingrédients disponibles • Les wraps ne périment pas",15,Color("9fb9cb")))
			var grid := GridContainer.new()
			grid.columns = 6
			grid.add_theme_constant_override("h_separation",5)
			grid.add_theme_constant_override("v_separation",5)
			box.add_child(grid)
			for i in range(12):
				var slot := PanelContainer.new()
				slot.custom_minimum_size = Vector2(98,65)
				var slot_skin := skin(Color("1b2b40"))
				slot_skin.set_content_margin_all(5)
				slot.add_theme_stylebox_override("panel",slot_skin)
				grid.add_child(slot)
				if i<game.sheet.ingredients.size():
					var item: Dictionary = game.sheet.ingredients[i]
					var stack := VBoxContainer.new()
					slot.add_child(stack)
					var icon := IngredientIcon.new()
					icon.kind = i
					icon.custom_minimum_size.y = 27
					stack.add_child(icon)
					var content := label(item.short_name+" × "+str(game.inventory[item.id]),12,Color(item.color))
					content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					stack.add_child(content)
					slot.tooltip_text = item.name
				elif i==6 and game.holding>=0:
					slot.add_child(label("WRAP\n× 1",14,Color("efd37d")))
					slot.tooltip_text = game.recipe(game.holding).name
			box.add_child(label("RECETTES / choisir pour la cuisine",18,CYAN))
			for i in range(game.sheet.recipes.size()):
				var index := i
				var recipe: Dictionary = game.recipe(i)
				var recipe_button := button(str(i+1)+" · "+recipe.name+"  /  "+str(int(recipe.price))+" WCC",func(): game.selected=index; hide_page())
				recipe_button.disabled = not game.recipe_unlocked(i)
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
			var ambience := CheckButton.new()
			ambience.text="Musique d’ambiance"
			ambience.button_pressed=game.ambience_enabled
			ambience.toggled.connect(game.set_ambience)
			box.add_child(ambience)
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
			var voices := CheckButton.new()
			voices.text = "Voix des clients (voix Windows installées)"
			voices.button_pressed = game.voice_enabled
			voices.toggled.connect(func(value): game.voice_enabled=value; game.save_settings())
			box.add_child(voices)
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
	CYAN=Color(game.console_node.config.accent)
	header.add_theme_stylebox_override("panel",ART.panel_frame(Color(0.7,0.75,0.8),18))
	credits.text = "%d wrapcoincoins" % game.coins
	var rank: int = game.restaurant_level()
	var target: String = str(int(game.sheet.progression[rank+1].served)) if rank+1<game.sheet.progression.size() else "∞"
	task.text = "%s · %d / %s" % [game.sheet.progression[rank].name,game.served,target]
	guidance.text="PROCHAINE ÉTAPE · "+str(game.guide_step().text)
	status.text = game.message if game.message_time>0 else "E : agir près d'un poste. I : inventaire. Les clients prennent leur temps."
	for i in range(slots.size()):
		slots[i].text = "%d  %s\n%d WCC" % [i+1,game.recipe(i).name,game.recipe(i).price]
		slots[i].disabled = not game.recipe_unlocked(i)
		var names: Array[String] = []
		for id in game.recipe(i).ingredients:
			for ingredient in game.sheet.ingredients:
				if ingredient.id==id: names.append("%s (%d)" % [ingredient.name,game.inventory[id]])
		slots[i].tooltip_text = " + ".join(names)
		slots[i].add_theme_stylebox_override("normal",skin(Color("31506b") if game.selected==i else Color("142237"),Color("e9c875") if i==game.order and game.customer_state=="waiting" else (CYAN if game.selected==i else Color("496881"))))

class SpaceButtonTrim extends Control:
	func _draw() -> void:
		var tint := Color("70bbc9")
		draw_line(Vector2(12,4),Vector2(size.x-18,4),Color(tint.r,tint.g,tint.b,0.3),1,true)
		draw_line(Vector2(4,15),Vector2(4,size.y-10),tint,2,true)
		draw_line(Vector2(size.x-12,size.y-4),Vector2(size.x-4,size.y-12),tint,2,true)
		for index in range(3):
			draw_circle(Vector2(size.x-8-index*4,9),0.8,tint)

class OpenBall extends Control:
	func _draw() -> void:
		draw_texture_rect(preload("res://visual_library.gd").interface(3),Rect2(0,0,600,620),false)

func build_console(_box: VBoxContainer) -> void:
	overlay.remove_child(window)
	window.queue_free()
	window=PanelContainer.new()
	window.position=Vector2(408,343)
	window.size=Vector2(384,190)
	var inside := StyleBoxFlat.new()
	inside.bg_color=Color(0.06,0.08,0.09,0.88)
	inside.set_content_margin_all(8)
	inside.set_corner_radius_all(12)
	window.add_theme_stylebox_override("panel",inside)
	var ball:=OpenBall.new()
	ball.position=Vector2(300,69)
	ball.scale=Vector2.ONE
	ball.mouse_filter=Control.MOUSE_FILTER_IGNORE
	overlay.add_child(ball)
	ball.set_meta("console_decor",true)
	overlay.add_child(window)
	var box:=VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	window.add_child(box)
	var top:=HBoxContainer.new()
	box.add_child(top)
	var spacer:=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close_button=button("FERMER",hide_page)
	close_button.custom_minimum_size.y=28
	close_button.add_theme_font_size_override("font_size",13)
	top.add_child(close_button)
	var composer:=TextEdit.new()
	composer.custom_minimum_size=Vector2(0,88)
	composer.size_flags_vertical=Control.SIZE_EXPAND_FILL
	composer.text=game.console_node.draft
	var paper:=StyleBoxFlat.new()
	paper.bg_color=Color(0.02,0.03,0.035,0.85)
	paper.set_content_margin_all(8)
	paper.set_corner_radius_all(6)
	composer.add_theme_stylebox_override("normal",paper)
	composer.add_theme_color_override("font_color",Color("f3e6ce"))
	composer.add_theme_font_size_override("font_size",14)
	box.add_child(composer)
	var send_button=button("ENVOYER ET RELANCER LE JEU",func(): game.console_node.draft=composer.text; game.console_node.send_and_restart())
	send_button.custom_minimum_size.y=32
	send_button.add_theme_font_size_override("font_size",14)
	box.add_child(send_button)
	var problem:=AcceptDialog.new()
	problem.title="Modification impossible"
	overlay.add_child(problem)
	problem.set_meta("console_decor",true)
	var refresh:=func():
		if not game.console_node.status.begins_with("PRÊT"):
			problem.dialog_text=game.console_node.status
			problem.popup_centered(Vector2i(540,220))
	game.console_node.changed.connect(refresh)
	composer.tree_exiting.connect(func():
		if game.console_node.changed.is_connected(refresh): game.console_node.changed.disconnect(refresh))
	if game.console_node.reopen and not game.console_node.status.ends_with("Jeu relancé."):
		refresh.call_deferred()
