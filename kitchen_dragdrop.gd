extends RefCounted
const ART=preload("res://visual_library.gd")
static func icon(index: int) -> AtlasTexture:
	return ART.food(index)

class Food extends TextureRect:
	var view: Node
	var id: String
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
		if view.kind=="wrap": draw_texture_rect(preload("res://visual_library.gd").object(10),Rect2(c-Vector2(126,101),Vector2(252,202)),false)
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
	var ui: Node
	var game: Node
	var kind: String
	var chosen: Array=[]
	var positions: Dictionary={}
	var icons: Array=[]
	var stocks: Array=[]
	var plate: Control
	var caption: Label
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
		var list=HBoxContainer.new()
		list.add_theme_constant_override("separation",5)
		add_child(list)
		for item in game.sheet.ingredients:
			if item.id not in allowed: continue
			var label=ui.label(item.short_name+" × "+str(game.inventory[item.id]),13)
			label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			label.custom_minimum_size.y=26
			label.tooltip_text=item.name
			list.add_child(label)
			stocks.append(label)
		if game.customer_state=="waiting":
			var order: Dictionary=game.recipe(game.order)
			var needs: Array[String]=[]
			for id in order.ingredients: needs.append(game.ingredient(id).short_name)
			var request=ui.label("Commande : "+order.name+" · "+" + ".join(needs),15,Color("efd37d"))
			request.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			add_child(request)
		var table=Table.new()
		table.view=self
		table.custom_minimum_size=Vector2(860,260)
		add_child(table)
		plate=Wrap.new()
		plate.view=self
		plate.position=Vector2(290,18)
		plate.size=Vector2(280,224)
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
			food.position=Vector2(26+(slot%3)*81+(0 if slot<3 else 581),88)
			food.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			food.size=Vector2(76,76)
			food.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			food.texture=art(i)
			food.mouse_filter=Control.MOUSE_FILTER_STOP
			food.tooltip_text=item.name
			table.add_child(food)
			food.set_deferred("size",Vector2(76,76))
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
		add_child(prepare)
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
		caption.text="Glisse les ingrédients de la table dans le wrap." if kind=="wrap" else "Glisse les ingrédients dans le verre."
		if game.holding>=0: caption.text="Tu portes déjà une commande : sers-la ou jette-la avant de cuisiner."
		elif match_index>=0:
			caption.text=game.recipe(match_index).name
			if not game.recipe_unlocked(match_index): caption.text+=" · recette verrouillée"
		prepare.disabled=match_index<0 or game.holding>=0
		if match_index>=0: prepare.disabled=prepare.disabled or not game.recipe_unlocked(match_index)
		for i in range(icons.size()):
			var id: String=shown[i]
			icons[i].modulate=Color(1,1,1,0.25) if id in chosen or game.inventory[id]<1 else Color.WHITE
			stocks[i].text=game.ingredient(id).short_name+" × "+str(game.inventory[id])
		plate.queue_redraw()

static func build(ui: Node, box: VBoxContainer, kind: String) -> void:
	var kitchen=Kitchen.new()
	kitchen.ui=ui
	kitchen.kind=kind
	kitchen.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	box.add_child(kitchen)
