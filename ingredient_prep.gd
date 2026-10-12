extends RefCounted
const ART=preload("res://visual_library.gd")
const TOOLS={"moonleaf":"knife","sunfruit":"knife","mushroom":"knife","firepepper":"knife","starlime":"press","nebulasyrup":"press","crystalrice":"sieve","lunartea":"sieve"}
const NAMES={"knife":"Couteau","press":"Presse-agrumes","sieve":"Passoire"}
static func tool_for(id: String) -> String: return TOOLS.get(id,"")
static func build(ui: Node, box: VBoxContainer) -> void:
	var bench=Bench.new(); bench.ui=ui; box.add_child(bench)
class Item extends TextureRect:
	var bench: Node
	var id: String
	var type: String
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not get_viewport().gui_is_dragging():
			if type=="raw": bench.place_crop(id)
			else: bench.use_tool(id)
			accept_event()
	func _get_drag_data(_at: Vector2):
		if type=="raw" and bench.game.inventory.get("raw_"+id,0)<1: return null
		var preview=TextureRect.new(); preview.texture=texture; preview.custom_minimum_size=Vector2(60,60)
		preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		set_drag_preview(preview)
		return {"bench":bench,"type":type,"id":id}
class Board extends Control:
	var bench: Node
	var cursor=Vector2.ZERO
	func center() -> Vector2: return Vector2(size.x*0.44,155)
	func rack(index: int) -> Rect2: return Rect2(18+index*128,14,110,54)
	func _draw() -> void:
		draw_texture_rect(ART.interface(2),Rect2(Vector2.ZERO,size),false)
		var font=ThemeDB.fallback_font
		for i in range(3):
			var rect=rack(i)
			var tool: String=["knife","press","sieve"][i]
			draw_style_box(bench.ui.skin(Color("21313a"),Color("6ce4bf") if bench.selected_tool==tool else Color("876845")),rect)
			draw_texture_rect(bench.tool_icon(i),Rect2(rect.position+Vector2(26,0),Vector2(58,40)),false)
			draw_string(font,rect.position+Vector2(8,48),NAMES[tool],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("f5e4c9"))
		var at=center()
		draw_arc(at,76,0,TAU,48,Color("9fc5b0"),1.5,true)
		if bench.crop.is_empty():
			draw_string(font,at+Vector2(-81,0),"POSE TON ALIMENT ICI",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f3ddae"))
		else:
			var texture: Texture2D=bench.raw_texture(bench.crop)
			if not bench.processed: draw_texture_rect(texture,Rect2(at-Vector2(54,54),Vector2(108,108)),false)
			else:
				for i in range(5): draw_texture_rect(ART.food(bench.index_of(bench.crop)),Rect2(at+Vector2((i%3-1)*30-18,(floori(i/3.0)-0.5)*32-15),Vector2(36,30)),false)
			var progress: float=bench.progress
			draw_rect(Rect2(24,247,230,9),Color("342c24"))
			draw_rect(Rect2(24,247,230*progress,9),Color("6de3b4"))
			if bench.selected_tool!="" and not bench.processed and cursor.distance_to(at)<110:
				var index: int=["knife","press","sieve"].find(bench.selected_tool)
				draw_texture_rect(bench.tool_icon(index),Rect2(cursor-Vector2(30,25),Vector2(65,65)),false)
		if bench.flash>0: draw_arc(at,78,0,TAU,48,Color(0.4,1,0.7,bench.flash),3,true)
		draw_string(font,Vector2(286,270),"BAC DES PRÊTS",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f7e3b5"))
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			for i in range(3):
				if rack(i).has_point(event.position): bench.use_tool(["knife","press","sieve"][i]); accept_event(); return
		if event is InputEventMouseMotion:
			cursor=event.position
			if event.button_mask&MOUSE_BUTTON_MASK_LEFT and cursor.distance_to(center())<85: bench.gesture(event.relative)
			queue_redraw()
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		if not data is Dictionary or data.get("bench")!=bench: return false
		if data.get("type")=="raw": return bench.crop.is_empty() and bench.game.inventory.get("raw_"+str(data.id),0)>0
		return data.get("type")=="tool" and str(data.get("id","")) in NAMES and not bench.busy
	func _drop_data(_at: Vector2, data: Variant) -> void:
		if data.type=="raw": bench.place_crop(str(data.id))
		else: bench.use_tool(str(data.id))
	func _get_drag_data(at: Vector2):
		if not bench.processed or bench.busy or at.distance_to(center())>80: return null
		var preview=TextureRect.new(); preview.texture=ART.food(bench.index_of(bench.crop)); preview.custom_minimum_size=Vector2(64,64)
		preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; set_drag_preview(preview)
		return {"bench":bench,"type":"processed","id":bench.crop}
class Bowl extends TextureRect:
	var bench: Node
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("bench")==bench and data.get("type")=="processed" and bench.processed and not bench.busy and data.get("id")==bench.crop
	func _drop_data(_at: Vector2, _data: Variant) -> void: bench.commit_current()
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not get_viewport().gui_is_dragging():
			bench.commit_current(); accept_event()
class Bench extends VBoxContainer:
	var compact=false
	var cells: Dictionary={}
	var ui: Node
	var game: Node
	var crop=""
	var processed=false
	var busy=false
	var selected_tool=""
	var progress=0.0
	var flash=0.0
	var board: Control
	var bowl: TextureRect
	var caption: Label
	var stock: Label
	func index_of(id: String) -> int:
		for i in range(game.sheet.ingredients.size()):
			if game.sheet.ingredients[i].id==id: return i
		return 0
	func raw_texture(id: String) -> Texture2D:
		if id=="sunfruit": return preload("res://art/prep_tomato.svg")
		if id=="lunartea": return ART.food(0)
		if id=="nebulasyrup": return ART.crop(1)
		return ART.food(index_of(id))
	func tool_icon(index: int) -> AtlasTexture:
		var atlas=AtlasTexture.new(); atlas.atlas=preload("res://art/prep_tools.svg"); atlas.region=Rect2(index*160,0,160,160); return atlas
	func _ready() -> void:
		game=ui.game; add_theme_constant_override("separation",6)
		var row=GridContainer.new(); row.columns=4; row.add_theme_constant_override("h_separation",8); add_child(row)
		for item in game.sheet.ingredients:
			if item.get("pantry",false): continue
			var cell=VBoxContainer.new(); row.add_child(cell)
			var food=Item.new(); food.bench=self; food.id=item.id; food.type="raw"; food.texture=raw_texture(item.id)
			food.custom_minimum_size=Vector2(88,28); food.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; food.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			food.tooltip_text=item.name+" · poser sur le plan de travail"; cell.add_child(food)
			var label=ui.label("",11); cell.add_child(label); cells[item.id]={"label":label,"food":food}
		stock=ui.label("",13); stock.hide(); add_child(stock)
		board=Board.new(); board.bench=self; board.custom_minimum_size=Vector2(410,282); add_child(board)
		bowl=Bowl.new(); bowl.bench=self; bowl.texture=tool_icon(3); bowl.position=Vector2(286,176); bowl.size=Vector2(112,82)
		bowl.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; bowl.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; bowl.size=Vector2(112,82)
		bowl.tooltip_text="Glisse le résultat ici, ou clique pour le ranger"; board.add_child(bowl)
		caption=ui.label("",14); caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(caption)
		refresh()
	func place_crop(id: String) -> void:
		if busy or game.inventory.get("raw_"+id,0)<1: game.say("Pas de récolte brute disponible."); return
		if not crop.is_empty(): game.say("Range l’aliment actuel dans le bac avant d’en poser un autre."); return
		crop=id; progress=0; processed=false; flash=0.5; refresh()
	func use_tool(id: String) -> void:
		if id not in NAMES or busy: return
		selected_tool=id
		if not crop.is_empty() and id!=TOOLS.get(crop,""): game.say("Cet aliment demande : "+NAMES[TOOLS.get(crop,"")])
		refresh()
	func gesture(relative: Vector2) -> void:
		if crop.is_empty() or busy or processed or selected_tool!=TOOLS.get(crop,""): return
		var distance: float=maxf(0,relative.y) if selected_tool=="knife" else absf(relative.x) if selected_tool=="press" else relative.length()
		var before=progress
		progress=minf(1,progress+minf(distance,40)/160.0)
		if floori(before*4)<floori(progress*4): game.play_sound(400+int(progress*200)); flash=0.7
		if progress>=1: processed=true; flash=1.0
		refresh()
	func commit_current() -> void:
		if not processed or busy or crop.is_empty(): return
		if game.prepare_crop(crop): clear_crop(); flash=1.0
		elif game.online.pending: busy=true
		refresh()
	func clear_crop() -> void: crop=""; processed=false; progress=0
	func refresh() -> void:
		for id in cells:
			var raw: int=int(game.inventory.get("raw_"+id,0))
			cells[id].label.text="%s · %d bruts" % [game.ingredient(id).short_name,raw]
			cells[id].food.modulate=Color(1,1,1,1 if raw>0 else 0.4)
		caption.text="1 · Pose un aliment. 2 · Prends un outil en haut de la table."
		if not crop.is_empty():
			caption.text="Maintiens le clic sur l’aliment : coupe vers le bas." if selected_tool=="knife" else "Maintiens le clic : presse de gauche à droite." if selected_tool=="press" else "Maintiens le clic : fais des mouvements circulaires pour rincer." if selected_tool=="sieve" else "Prends le bon outil en haut de la table."
			if selected_tool!="" and selected_tool!=TOOLS.get(crop,""): caption.text="Choisis : "+NAMES[TOOLS.get(crop,"")]
		if processed: caption.text="3 · Glisse l’aliment traité dans le bac à droite."
		if busy: caption.text="Rangement en cours…"
		board.queue_redraw()
	func _process(delta: float) -> void:
		flash=maxf(0,flash-delta*1.2)
		if busy and not game.online.pending: busy=false; clear_crop(); flash=1.0
		refresh()
