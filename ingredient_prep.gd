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
	var touching=false
	var direction=Vector2.ZERO
	var swipe_from=Vector2.ZERO
	var swipe_to=Vector2.ZERO
	func center() -> Vector2: return Vector2(size.x*0.44,155)
	func rack(index: int) -> Rect2: return Rect2(18+index*128,14,110,54)
	func _draw() -> void:
		draw_texture_rect(ART.interface(2),Rect2(Vector2.ZERO,size),false)
		var font=ThemeDB.fallback_font
		draw_string(font,Vector2(20,42),"BOUGE LA SOURIS SUR L’ALIMENT !",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f9e5af"))
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
		if bench.flash>0: draw_arc(at,78,0,TAU,48,Color(0.4,1,0.7,bench.flash),3,true)
		if bench.flash>0:
			draw_line(swipe_from,swipe_to,Color(0.8,1,0.92,bench.flash),4,true)
		for piece in bench.pieces:
			draw_texture_rect(ART.food(bench.index_of(str(piece.id))),Rect2(piece.position,Vector2(24,20)),false,Color(1,1,1,piece.life))
		if bench.crop.is_empty() and bench.flash>0.55: draw_string(font,Vector2(290,174),"+1 PRÊT !",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("7affbc"))
		draw_string(font,Vector2(286,270),"BAC DES PRÊTS",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f7e3b5"))
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			cursor=event.position
			var start: Vector2=cursor-event.relative
			var contact: Vector2=Geometry2D.get_closest_point_to_segment(center(),start,cursor)
			if contact.distance_to(center())<65 and event.relative.length()>=12 and (not touching or event.relative.dot(direction)<0):
				swipe_from=start; swipe_to=cursor; bench.gesture(event.relative)
				direction=event.relative.normalized()
			touching=cursor.distance_to(center())<65
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
	var pieces: Array=[]
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
		bowl=Bowl.new(); bowl.mouse_filter=Control.MOUSE_FILTER_PASS; bowl.bench=self; bowl.texture=tool_icon(3); bowl.position=Vector2(286,176); bowl.size=Vector2(112,82)
		bowl.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; bowl.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; bowl.size=Vector2(112,82)
		bowl.tooltip_text="Glisse le résultat ici, ou clique pour le ranger"; board.add_child(bowl)
		caption=ui.label("",14); caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(caption)
		refresh()
	func place_crop(id: String) -> void:
		if busy or game.inventory.get("raw_"+id,0)<1: game.say("Pas de récolte brute disponible."); return
		if not crop.is_empty(): game.say("Range l’aliment actuel dans le bac avant d’en poser un autre."); return
		crop=id; progress=0; processed=false; flash=0.5; board.touching=false; board.direction=Vector2.ZERO; refresh()
	func use_tool(id: String) -> void:
		if id not in NAMES or busy: return
		selected_tool=id
		if not crop.is_empty() and id!=TOOLS.get(crop,""): game.say("Cet aliment demande : "+NAMES[TOOLS.get(crop,"")])
		refresh()
	func gesture(relative: Vector2) -> void:
		if crop.is_empty() or busy or processed or relative.length()<12: return
		progress=minf(1,progress+1.0/3.0)
		game.play_sound(450+int(progress*300)); flash=0.8
		for i in range(3): pieces.append({"id":crop,"position":board.center()+Vector2(i*12-18,-12),"velocity":Vector2(70+i*30,-65+i*25),"life":1.0})
		if progress>=0.99: processed=true; flash=1.0; commit_current()
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
		caption.text="Pose un aliment, puis fais 3 passages rapides de souris dessus."
		if not crop.is_empty(): caption.text="SWISH ! Passe et repasse sur l’aliment · %d/3" % roundi(progress*3)
		if processed: caption.text="Rangement automatique dans le bac…"
		if busy: caption.text="Rangement en cours…"
		board.queue_redraw()
	func _process(delta: float) -> void:
		flash=maxf(0,flash-delta*1.2)
		for piece in pieces:
			piece.position+=piece.velocity*delta
			piece.velocity.y+=120*delta
			piece.life-=delta*1.5
		pieces=pieces.filter(func(piece): return piece.life>0)
		if busy and not game.online.pending: busy=false; clear_crop(); flash=1.0
		refresh()
