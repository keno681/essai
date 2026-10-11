extends "res://planters.gd"

var popup: PopupPanel

func open(id: String) -> void:
	if game.online and game.online.executing_remote: return
	if not plants.has(id): return
	if is_instance_valid(popup):
		popup.hide()
		popup.queue_free()
	popup = PopupPanel.new()
	popup.transparent_bg = true
	game.ui.add_child(popup)
	var style := preload("res://visual_library.gd").panel_frame(Color(0.65,0.70,0.72),12)
	popup.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	popup.add_child(box)
	var title := Label.new()
	title.text = name_of(id)
	title.add_theme_font_size_override("font_size", 14)
	box.add_child(title)
	if str(plants[id]) != "":
		var seconds := ceili(timer(id))
		var take := small_button("Récolter" if seconds == 0 else "Pousse : %d s" % seconds, func(): harvest(id))
		take.disabled = seconds > 0
		box.add_child(take)
		box.add_child(small_button("Vider", func(): empty(id)))
	else:
		for item in game.sheet.ingredients:
			if item.id not in game.discovered or item.get("pantry",false): continue
			var crop: String = str(item.id)
			box.add_child(small_button(str(item.name), func(): plant(id, crop)))
	game.menu = true
	popup.popup_hide.connect(func(): game.menu = false)
	var cursor: Vector2 = game.get_viewport().get_mouse_position()
	var height: int = 100 if str(plants[id]) != "" else 48 + box.get_child_count() * 30
	var viewport_size: Vector2 = game.get_viewport_rect().size
	popup.popup(Rect2i(Vector2i(clampf(cursor.x + 12, 8, maxf(8, viewport_size.x - 228)), clampf(cursor.y + 8, 8, maxf(8, viewport_size.y - height - 8))), Vector2i(220, height)))

func small_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(196, 28)
	b.add_theme_font_size_override("font_size", 14)
	var art = preload("res://visual_library.gd")
	b.add_theme_stylebox_override("normal", art.frame(Color(0.65,0.68,0.70), 5))
	b.add_theme_stylebox_override("hover", art.frame(Color(1.0,0.92,0.78), 5))
	b.add_theme_stylebox_override("pressed", art.frame(Color(0.5,0.5,0.5), 5))
	b.add_theme_stylebox_override("disabled", art.frame(Color(0.35,0.35,0.35), 5))
	b.add_theme_color_override("font_color", Color("f1e4cb"))
	b.add_theme_color_override("font_disabled_color", Color("aaa398"))
	b.pressed.connect(action)
	return b

func paint() -> void:
	if game.room not in ["restaurant", "garden"]: return
	var locations: Array = []
	if game.room == "restaurant":
		for item in game.sheet.ingredients:
			if item.starter: locations.append(item)
	else: locations = game.sheet.beds
	for location in locations:
		var id: String = str(location.id)
		if not plants.has(id) or str(plants[id]).is_empty(): continue
		var index := 0
		for i in range(game.sheet.ingredients.size()):
			if str(game.sheet.ingredients[i].id) == str(plants[id]): index = i
		var item: Dictionary = game.ingredient(str(plants[id]))
		var progress: float = clampf(1.0 - timer(id) / float(item.regrow_seconds), 0.0, 1.0)
		var growth: float = lerpf(0.25, 1.0, progress)
		var x: float = float(location.x) - game.camera_x
		var anchor := 451.0 if game.room == "restaurant" else 469.0
		var heights := [86.0, 146.0, 106.0, 132.0, 132.0, 142.0]
		var width: float = (132.0 if game.room == "restaurant" else 138.0) * growth
		var height: float = heights[index] * growth
		var sway: float = sin(game.clock * 1.2 + float(location.x) * 0.02) * 1.3 * growth
		game.draw_texture_rect(preload("res://visual_library.gd").crop(index), Rect2(x - width * 0.5 + sway, anchor - height, width, height), false, Color(game.brightness, game.brightness, game.brightness))
