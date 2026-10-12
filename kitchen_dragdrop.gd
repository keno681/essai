extends RefCounted
const ART=preload("res://visual_library.gd")
static func icon(index: int) -> AtlasTexture:
	return ART.food(index)

class Food extends TextureRect:
	var view: Node
	var id: String
	func _draw() -> void:
		var entry: Dictionary=view.game.tables.person(view.game.tables.selected)
		if not entry.is_empty() and id in view.game.recipe(int(entry.recipe)).ingredients:
			draw_rect(Rect2(Vector2(2,2),size-Vector2(4,4)),Color("69e7bc") if id in view.chosen else Color("f1c96a"),false,2)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not get_viewport().gui_is_dragging():
			if view.game.holding<0 and view.game.inventory.get(id,0)>0 and id not in view.chosen:
				view.chosen.append(id); view.positions[id]=view.plate.size*0.5+Vector2((view.chosen.size()%3-1)*35,(floori(view.chosen.size()/3.0)-0.5)*26)
				view.game.play_sound(520); view.refresh()
			accept_event()
	func _get_drag_data(_at: Vector2):
		if view.game.holding>=0 or view.game.inventory[id]<1 or id in view.chosen: return null
		var preview=TextureRect.new()
		preview.texture=texture
		preview.custom_minimum_size=Vector2(64,64)
		preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		set_drag_preview(preview)
		return {"ingredient":id,"kitchen":view,"from_wrap":false}

class Table extends Control:
	var view: Node
	var wood: GradientTexture2D
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_STOP
		var gradient=Gradient.new()
		gradient.colors=PackedColorArray([Color("61412f"),Color("aa7d54"),Color("775033")])
		gradient.offsets=PackedFloat32Array([0,0.45,1])
		wood=GradientTexture2D.new()
		wood.gradient=gradient
		wood.fill_from=Vector2(0,0)
		wood.fill_to=Vector2(0,1)
	func _draw() -> void:
		draw_texture_rect(preload("res://visual_library.gd").interface(2), Rect2(Vector2.ZERO, size), false)

class Wrap extends Control:
	var view: Node
	func inside(at: Vector2) -> bool:
		return ((at-size*0.5)/Vector2(120,94)).length()<1.0
	func _draw() -> void:
		var c=size*0.5
		if view.kind=="wrap":
			var dimensions=Vector2(minf(size.x-8,252),minf(size.y-8,202))
			draw_texture_rect(preload("res://visual_library.gd").object(10),Rect2(c-dimensions*0.5,dimensions),false)
		else:
			draw_texture_rect(preload("res://visual_library.gd").object(11), Rect2(c-Vector2(72,98),Vector2(144,196)), false)
		for id in view.chosen:
			var at: Vector2=view.positions.get(id,c)
			draw_texture_rect(view.art(view.index_of(id)),Rect2(at-Vector2(27,27),Vector2(54,54)),false)
	func _can_drop_data(at: Vector2, data: Variant) -> bool:
		return inside(at) and data is Dictionary and data.get("kitchen")==view and data.get("ingredient","") in view.allowed and data.get("ingredient","") not in view.chosen and not data.get("from_wrap",false) and view.game.holding<0 and view.game.inventory.get(data.get("ingredient",""),0)>0
	func _drop_data(at: Vector2, data: Variant) -> void:
		var id: String=data.ingredient
		if id not in view.chosen: view.chosen.append(id)
		view.positions[id]=at
		view.refresh()
	func _get_drag_data(_at: Vector2): return null

class Kitchen extends VBoxContainer:
	var compact=false
	var last_inventory: Dictionary={}
	var ui: Node
	var game: Node
	var kind: String
	var chosen: Array=[]
	var positions: Dictionary={}
	var icons: Array=[]
	var stocks: Array=[]
	var plate: Control
	var caption: Label
	var store: Button
	var prepare: Button
	var match_index=-1
	var textures: Array=[]
	var allowed: Array[String]=[]
	var shown: Array[String]=[]
	func art(index: int) -> Texture2D: return textures[index]
	func index_of(id: String) -> int:
		for i in range(game.sheet.ingredients.size()):
			if game.sheet.ingredients[i].id==id: return i
		return 0
	func _ready() -> void:
		game=ui.game
		for recipe in game.sheet.recipes:
			if recipe.get("kind","wrap")==kind:
				for id in recipe.ingredients:
					if id not in allowed: allowed.append(id)
		chosen=ui.get_meta("composition_"+kind,[]).filter(func(id): return id in allowed)
		add_theme_constant_override("separation",8)
		for i in range(game.sheet.ingredients.size()): textures.append(preload("res://visual_library.gd").food(i))
		var list=GridContainer.new()
		list.columns=3 if compact else 6
		list.add_theme_constant_override("separation",5)
		add_child(list)
		for item in game.sheet.ingredients:
			if item.id not in allowed: continue
			var label=ui.label(item.short_name+" × "+str(game.inventory[item.id]),13)
			label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			label.custom_minimum_size.y=26
			label.tooltip_text=item.name+" préparé · bruts : "+str(game.inventory.get("raw_"+item.id,0))
			list.add_child(label)
			stocks.append(label)
		var tickets=HBoxContainer.new()
		var scroll=ScrollContainer.new()
		scroll.custom_minimum_size.y=76 if compact else 94
		scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll); scroll.add_child(tickets)
		for ticket in game.tables.people:
			if ticket.state in ["eating","leaving"]: continue
			var number: int=int(ticket.table)
			var details: Array[String]=[]
			for id in game.recipe(int(ticket.recipe)).ingredients: details.append(game.ingredient(id).short_name)
			var paper=Button.new()
			paper.text="TABLE %d · %s\n%s\n%s" % [number,game.recipe(int(ticket.recipe)).name," + ".join(details),game.tables.status(ticket)]
			paper.custom_minimum_size=Vector2(270,60 if compact else 76)
			paper.clip_text=true
			paper.tooltip_text=paper.text
			paper.add_theme_font_size_override("font_size",13)
			paper.add_theme_color_override("font_color",Color("382a16"))
			var skin=StyleBoxFlat.new(); skin.bg_color=Color("f2da8d"); skin.border_color=Color("ba8c39"); skin.set_border_width_all(2); skin.set_content_margin_all(8)
			paper.add_theme_stylebox_override("normal",skin)
			paper.add_theme_stylebox_override("pressed",skin)
			paper.add_theme_color_override("font_hover_color",Color("382a16"))
			paper.add_theme_color_override("font_pressed_color",Color("382a16"))
			var hover=skin.duplicate(); hover.bg_color=Color("fff0bd"); paper.add_theme_stylebox_override("hover",hover)
			paper.pressed.connect(func(): game.tables.select_table(number))
			tickets.add_child(paper)
		var entry=game.tables.person(game.tables.selected)
		if not entry.is_empty():
			var order: Dictionary=game.recipe(int(entry.recipe))
			var needs: Array[String]=[]
			for id in order.ingredients: needs.append(game.ingredient(id).short_name)
			var request=ui.label("TABLE %d · %s · %s" % [entry.table,order.name," + ".join(needs)],15,Color("efd37d"))
			request.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			add_child(request)
		var table=Table.new()
		table.view=self
		table.custom_minimum_size=Vector2(410,240) if compact else Vector2(860,260)
		add_child(table)
		plate=Wrap.new()
		plate.view=self
		plate.position=Vector2(95,90) if compact else Vector2(290,18)
		plate.size=Vector2(220,140) if compact else Vector2(280,224)
		plate.mouse_filter=Control.MOUSE_FILTER_STOP
		table.add_child(plate)
		for i in range(game.sheet.ingredients.size()):
			var item: Dictionary=game.sheet.ingredients[i]
			if item.id not in allowed: continue
			var slot := shown.size()
			shown.append(item.id)
			var food=Food.new()
			food.view=self
			food.id=item.id
			food.position=Vector2(30+(slot%3)*126,8+floori(slot/3.0)*50) if compact else Vector2(26+(slot%3)*81+(0 if slot<3 else 581),88)
			food.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			food.size=Vector2(56,48) if compact else Vector2(76,76)
			food.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			food.texture=art(i)
			food.mouse_filter=Control.MOUSE_FILTER_STOP
			food.tooltip_text=item.name
			table.add_child(food)
			food.set_deferred("size",Vector2(56,48) if compact else Vector2(76,76))
			icons.append(food)
		for i in range(chosen.size()): positions[chosen[i]]=Vector2(110+i*20,105)
		caption=ui.label("",16,ui.CYAN)
		caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		add_child(caption)
		prepare=ui.button("FABRIQUER LA BOISSON" if kind=="drink" else "ROULER ET CUISINER LE WRAP",func():
			if match_index<0: return
			game.selected=match_index
			if game.cook(): clear_preparation(); ui.hide_page()
			else: caption.text=game.message)
		var actions=HBoxContainer.new()
		add_child(actions)
		move_child(actions,table.get_index())
		if compact: prepare.text="FABRIQUER" if kind=="drink" else "ROULER"
		prepare.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		prepare.add_theme_font_size_override("font_size",14)
		actions.add_child(prepare)
		store=ui.button("PRÉPARER ET POSER AU COMPTOIR",func():
			if match_index<0: return
			game.selected=match_index
			if game.cook_store(game.tables.selected): clear_preparation(); ui.show_page("cookdrink" if kind=="drink" else "cookwrap")
			else: caption.text=game.message)
		if compact: store.text="PRÉPARER ET POSER"
		store.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		store.add_theme_font_size_override("font_size",14)
		actions.add_child(store)
		var help=ui.label("Dépose dans le verre. Les ingrédients déposés ne peuvent plus être retirés." if kind=="drink" else "Dépose dans la galette. Les ingrédients déposés ne peuvent plus être retirés.",14)
		help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		add_child(help)
		add_child(ui.button("JETER LA PRÉPARATION",func():
			if chosen.is_empty(): return
			if game.discard_preparation(kind,chosen.duplicate()): clear_preparation(); refresh()
			else: caption.text=game.message))
		if game.holding>=0: add_child(ui.button("JETER LA COMMANDE PORTÉE",func():
			if game.discard_order(): refresh()))
		refresh()
	func _process(_delta: float) -> void:
		if last_inventory!=game.inventory:
			last_inventory=game.inventory.duplicate()
			refresh()
	func remove_ingredient(_id: String) -> void:
		# Deposited ingredients are permanent until the entire preparation is discarded.
		pass
	func clear_preparation() -> void:
		chosen.clear()
		positions.clear()
		ui.set_meta("composition_"+kind,[])
	func refresh() -> void:
		ui.set_meta("composition_"+kind,chosen.duplicate())
		var target=chosen.duplicate()
		target.sort()
		match_index=-1
		for i in range(game.sheet.recipes.size()):
			var recipe: Dictionary=game.recipe(i)
			if recipe.get("kind","wrap")!=kind: continue
			var required: Array=recipe.ingredients.duplicate()
			required.sort()
			if required==target: match_index=i; break
		caption.text="Clique ou glisse les ingrédients prêts dans le wrap." if kind=="wrap" else "Clique ou glisse les ingrédients prêts dans le verre."
		if game.holding>=0: caption.text="Tu portes déjà une commande : sers-la ou jette-la avant de cuisiner."
		elif match_index>=0:
			caption.text=game.recipe(match_index).name
			if not game.recipe_unlocked(match_index): caption.text+=" · recette verrouillée"
		prepare.disabled=match_index<0 or game.holding>=0
		if match_index>=0: prepare.disabled=prepare.disabled or not game.recipe_unlocked(match_index)
		store.disabled=prepare.disabled or game.tables.selected<=0 or game.counter_items.size()>=12
		for i in range(icons.size()):
			var id: String=shown[i]
			icons[i].modulate=Color(1,1,1,0.25) if id in chosen or game.inventory[id]<1 else Color.WHITE
			icons[i].queue_redraw()
			stocks[i].text=game.ingredient(id).short_name+" × "+str(game.inventory[id])
		var order_entry: Dictionary=game.tables.person(game.tables.selected)
		if not order_entry.is_empty():
			var needed: Array=game.recipe(int(order_entry.recipe)).ingredients
			var done=0
			for id in needed:
				if id in chosen: done+=1
			caption.text="TABLE %d · %d/%d ingrédients · %s" % [order_entry.table,done,needed.size(),"PRÊT À ROULER !" if done==needed.size() and chosen.size()==needed.size() else "compose la commande"]
		plate.queue_redraw()

static func build(ui: Node, box: VBoxContainer, kind: String) -> void:
	var row=HBoxContainer.new(); row.add_theme_constant_override("separation",18); box.add_child(row)
	var left=VBoxContainer.new(); row.add_child(left)
	left.add_child(ui.label("TRAITER LES RÉCOLTES",17,ui.CYAN))
	var prep_scroll=ScrollContainer.new(); prep_scroll.custom_minimum_size=Vector2(425,460)
	prep_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; left.add_child(prep_scroll)
	var bench=preload("res://ingredient_prep.gd").Bench.new(); bench.ui=ui; bench.compact=true; prep_scroll.add_child(bench)
	var right=VBoxContainer.new(); row.add_child(right)
	right.add_child(ui.label("COMPOSER LA BOISSON" if kind=="drink" else "COMPOSER LE WRAP",17,ui.CYAN))
	var cook_scroll=ScrollContainer.new(); cook_scroll.custom_minimum_size=Vector2(435,460)
	cook_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; right.add_child(cook_scroll)
	var kitchen=Kitchen.new(); kitchen.ui=ui; kitchen.kind=kind; kitchen.compact=true
	kitchen.size_flags_horizontal=Control.SIZE_EXPAND_FILL; cook_scroll.add_child(kitchen)
