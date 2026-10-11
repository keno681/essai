extends Node
var game: Node
var plants: Dictionary={}
var defaults: Dictionary={}
const CROP=preload("res://art/kitchen_ingredients.svg")
const POT=preload("res://art/crop_planter.svg")
func _ready() -> void:
	game=get_parent()
	for item in game.sheet.ingredients:
		if item.starter: defaults[item.id]=item.id
	for bed in game.sheet.beds: defaults[bed.id]=bed.ingredient
	reset()
func reset() -> void: plants=defaults.duplicate()
func restore(saved: Variant) -> void:
	reset()
	if not saved is Dictionary: return
	for id in defaults:
		var crop=saved.get(id,defaults[id])
		if crop is String and (crop.is_empty() or (crop in game.discovered and not game.ingredient(crop).get("pantry",false))): plants[id]=crop
func timer(id: String) -> float:
	return float(game.cooldowns[id] if game.cooldowns.has(id) else game.node_cooldowns.get(id,0))
func set_timer(id: String, seconds: float) -> void:
	if game.cooldowns.has(id): game.cooldowns[id]=seconds
	else: game.node_cooldowns[id]=seconds
func name_of(id: String) -> String:
	return "Bac vide" if plants[id].is_empty() else "Bac · "+str(game.ingredient(plants[id]).name)
func open(id: String) -> void:
	if not plants.has(id): return
	game.ui.set_meta("active_planter",id)
	game.ui.show_page("planter")
func empty(id: String) -> void:
	if game.online and game.online.request("empty",{"id":id}): return
	plants[id]=""
	set_timer(id,0)
	game.save_progress()
	open(id)
func plant(id: String, crop: String) -> void:
	if game.online and game.online.request("plant",{"id":id,"crop":crop}): return
	if not plants[id].is_empty() or crop not in game.discovered or game.ingredient(crop).get("pantry",false): return
	plants[id]=crop
	set_timer(id,float(game.ingredient(crop).regrow_seconds))
	game.save_progress()
	open(id)
func harvest(id: String) -> void:
	if game.online and game.online.request("harvest",{"id":id}): return
	var crop: String=plants[id]
	if crop.is_empty() or timer(id)>0: return
	game.inventory[crop]+=1 if game.cooldowns.has(id) else 2
	set_timer(id,float(game.ingredient(crop).regrow_seconds))
	game.play_sound(620)
	game.say("Récolte : "+str(game.ingredient(crop).name))
	game.save_progress()
	open(id)
func build(box: VBoxContainer) -> void:
	var id: String=game.ui.get_meta("active_planter","")
	if not plants.has(id): return
	var ui=game.ui
	box.add_child(ui.label(name_of(id),22,ui.CYAN))
	if not plants[id].is_empty():
		box.add_child(ui.label("Prête à récolter" if timer(id)<=0 else "Croissance : %d secondes (ferme cette fenêtre pour laisser pousser)." % ceili(timer(id)),14))
		var harvest_button=ui.button("RÉCOLTER",func(): harvest(id))
		harvest_button.disabled=timer(id)>0
		box.add_child(harvest_button)
		box.add_child(ui.button("VIDER LE BAC",func(): empty(id)))
	else:
		box.add_child(ui.label("Choisis une plante découverte. Les semences sont gratuites.",15))
		for item in game.sheet.ingredients:
			if item.id not in game.discovered or item.get("pantry",false): continue
			var crop: String=item.id
			box.add_child(ui.button("PLANTER · "+item.name,func(): plant(id,crop)))
func paint() -> void:
	if game.room not in ["restaurant","garden"]: return
	var locations: Array=[]
	if game.room=="restaurant":
		for item in game.sheet.ingredients:
			if item.starter: locations.append({"id":item.id,"x":item.x})
	else: locations=game.sheet.beds
	for bed in locations:
		var id: String=bed.id
		if plants[id]==defaults[id]: continue
		var x=float(bed.x)-game.camera_x
		game.draw_texture_rect(POT,Rect2(x-58,325,116,220),false,Color(game.brightness,game.brightness,game.brightness))
		if plants[id].is_empty(): continue
		var index=0
		for i in range(game.sheet.ingredients.size()):
			if game.sheet.ingredients[i].id==plants[id]: index=i
		var texture=AtlasTexture.new()
		texture.atlas=CROP
		texture.region=Rect2(index*128,0,128,128)
		var growth=clampf(1-timer(id)/float(game.ingredient(plants[id]).regrow_seconds),0.2,1)
		var scale=62*growth
		game.draw_line(Vector2(x,486),Vector2(x,448),Color("739156"),3,true)
		game.draw_texture_rect(texture,Rect2(x-scale*0.5,477-scale,scale,scale),false,Color(game.brightness,game.brightness,game.brightness))
