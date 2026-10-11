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
	func _get_drag_data(_at: Vector2):
		if type=="raw" and bench.game.inventory.get("raw_"+id,0)<1: return null
		var preview=TextureRect.new(); preview.texture=texture; preview.custom_minimum_size=Vector2(65,65)
		preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		set_drag_preview(preview)
		return {"bench":bench,"type":type,"id":id}
class Board extends Control:
	var bench: Node
	func _draw() -> void:
		draw_texture_rect(ART.interface(2),Rect2(Vector2.ZERO,size),false)
		if bench.crop.is_empty(): return
		var center=size*0.5
		var texture: Texture2D=bench.raw_texture(bench.crop)
		if not bench.processed: draw_texture_rect(texture,Rect2(center-Vector2(60,60),Vector2(120,120)),false)
		else:
			texture=ART.food(bench.index_of(bench.crop))
			for i in range(5):
				var at: Vector2=center+Vector2((i%3-1)*36,(floori(i/3.0)-0.5)*36)
				draw_texture_rect(texture,Rect2(at-Vector2(21,16),Vector2(42,32)),false)
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		if not data is Dictionary or data.get("bench")!=bench: return false
		if data.get("type")=="raw": return bench.crop.is_empty() and bench.game.inventory.get("raw_"+str(data.id),0)>0
		return data.get("type")=="tool" and not bench.crop.is_empty() and not bench.processed and str(data.id)==TOOLS.get(bench.crop,"")
	func _drop_data(_at: Vector2, data: Variant) -> void:
		if data.type=="raw": bench.crop=str(data.id); bench.processed=false
		else: bench.processed=true; bench.game.play_sound(440)
		bench.refresh(); queue_redraw()
	func _get_drag_data(_at: Vector2):
		if not bench.processed or bench.busy: return null
		var preview=TextureRect.new(); preview.texture=ART.food(bench.index_of(bench.crop)); preview.custom_minimum_size=Vector2(64,64)
		preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; set_drag_preview(preview)
		return {"bench":bench,"type":"processed","id":bench.crop}
class Bowl extends TextureRect:
	var bench: Node
	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.get("bench")==bench and data.get("type")=="processed" and bench.processed and not bench.busy and data.get("id")==bench.crop
	func _drop_data(_at: Vector2, _data: Variant) -> void:
		if bench.game.prepare_crop(bench.crop): bench.crop=""; bench.processed=false
		elif bench.game.online.pending: bench.busy=true
		bench.refresh(); bench.board.queue_redraw()
class Bench extends VBoxContainer:
	var compact=false
	var cells: Dictionary={}
	var ui: Node
	var game: Node
	var crop=""
	var processed=false
	var busy=false
	var board: Control
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
		var a=AtlasTexture.new(); a.atlas=preload("res://art/prep_tools.svg"); a.region=Rect2(index*160,0,160,160); return a
	func _ready() -> void:
		game=ui.game; add_theme_constant_override("separation",6 if compact else 10)
		var help=ui.label("Récolte → planche → ustensile → saladier",14)
		help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		add_child(help)
		var row=GridContainer.new(); row.columns=4 if compact else 8; row.add_theme_constant_override("h_separation",8); add_child(row)
		for item in game.sheet.ingredients:
			if item.get("pantry",false): continue
			var cell=VBoxContainer.new(); row.add_child(cell)
			var food=Item.new(); food.bench=self; food.id=item.id; food.type="raw"; food.texture=raw_texture(item.id)
			food.custom_minimum_size=Vector2(88,40) if compact else Vector2(85,72); food.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; food.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if item.id=="nebulasyrup": food.modulate=Color("cd95e8")
			food.tooltip_text=item.name+" · récolte brute"; cell.add_child(food)
			var count=ui.label("",12); cell.add_child(count); cells[item.id]={"label":count,"food":food}
		stock=ui.label("",13); stock.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(stock)
		var work=HBoxContainer.new(); add_child(work)
		board=Board.new(); board.bench=self; board.custom_minimum_size=Vector2(260,140) if compact else Vector2(565,240); work.add_child(board)
		var bowl=Bowl.new(); bowl.bench=self; bowl.texture=tool_icon(3); bowl.custom_minimum_size=Vector2(140,140) if compact else Vector2(220,220)
		bowl.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; bowl.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; bowl.tooltip_text="Saladier · ingrédients préparés"; work.add_child(bowl)
		var tools=HBoxContainer.new(); add_child(tools)
		var index=0
		for id in ["knife","press","sieve"]:
			var column=VBoxContainer.new(); tools.add_child(column)
			var tool=Item.new(); tool.bench=self; tool.id=id; tool.type="tool"; tool.texture=tool_icon(index); index+=1
			tool.custom_minimum_size=Vector2(115,40) if compact else Vector2(120,64); tool.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; tool.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tool.tooltip_text=NAMES[id]; column.add_child(tool); column.add_child(ui.label(NAMES[id],13))
		caption=ui.label("",16); add_child(caption)
		if not compact: add_child(ui.button("RETOUR À LA CUISINE",func(): ui.show_page(str(ui.get_meta("prep_return","cookwrap")))))
		refresh()
	func refresh() -> void:
		var counts: Array[String]=[]
		for item in game.sheet.ingredients:
			if not item.get("pantry",false) and item.id in game.discovered: counts.append("%s : %d bruts / %d prêts" % [item.short_name,game.inventory.get("raw_"+item.id,0),game.inventory[item.id]])
		stock.text="" if compact else " · ".join(counts)
		stock.visible=not compact
		for id in cells:
			var raw: int=int(game.inventory.get("raw_"+id,0))
			cells[id].label.text="%s\n%d bruts · %d prêts" % [game.ingredient(id).short_name,raw,game.inventory[id]]
			cells[id].food.modulate=Color(1,1,1,1 if raw>0 else 0.45) if id!="nebulasyrup" else Color(0.80,0.58,0.91,1 if raw>0 else 0.45)
		caption.text="Glisse une récolte brute sur la planche." if crop.is_empty() else "Glisse le résultat dans le saladier." if processed else "Utilise : "+NAMES[TOOLS.get(crop,"")]
		if busy: caption.text="Validation de la préparation…"
	func _process(_delta: float) -> void:
		if busy and not game.online.pending:
			busy=false
			crop=""; processed=false; board.queue_redraw()
		refresh()
