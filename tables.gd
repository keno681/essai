extends Node
const COUNT := 8
var game: Node
var people: Array[Dictionary]=[]
var selected := 0
func _ready() -> void: game=get_parent()
func reset() -> void: people.clear(); selected=0
func spot(number: int) -> Vector2:
	return Vector2(205+((number-1)%4)*245,355 if number<=4 else 550)
func person(number: int) -> Dictionary:
	for entry in people:
		if int(entry.table)==number: return entry
	return {}
func free_tables() -> Array[int]:
	var result: Array[int]=[]
	for number in range(1,COUNT+1):
		if person(number).is_empty(): result.append(number)
	return result
func welcome(number: int) -> bool:
	if game.online and game.online.request("welcome",{"table":number}): return false
	if game.customer_state!="waiting": game.say("Attends que le client arrive à l’accueil."); return false
	if number not in free_tables(): game.say("Cette table est déjà occupée."); return false
	people.append({"table":number,"customer":game.actor_customer,"appearance":game.appearance.duplicate(true),"recipe":game.order,"state":"to_room","emotion":"calm","x":game.customer_x,"remaining":0.0,"phase":0.0,"quote":""})
	game.say("Commande prise : table %d · %s." % [number,game.recipe(game.order).name])
	game.choose_customer()
	game.next_order()
	game.actor_customer=game.customer
	game.appearance=game.queued_appearance.duplicate(true)
	game.customer_x=game.customer_queue.enter_service()
	game.customer_state="arriving"
	game.customer_emotion="calm"
	game.reset_customer_conversation()
	game.save_progress()
	return true
func serve_table(number: int) -> bool:
	if game.online and game.online.request("serve_table",{"table":number}): return false
	var entry=person(number)
	if entry.is_empty() or entry.state!="waiting": game.say("Cette table n’attend pas de commande à servir."); return false
	if game.holding<0: game.say("Table %d : %s." % [number,game.recipe(int(entry.recipe)).name]); return false
	var correct: bool=game.holding==int(entry.recipe)
	game.holding=-1
	if correct:
		var level: int=game.restaurant_level()
		game.coins+=int(game.recipe(int(entry.recipe)).price)+(5 if game.upgraded else 0)+int(game.sheet.progression[level].bonus)
		game.served+=1
		game.completed=game.served>=3
		entry.state="eating"
		entry.emotion="happy"
		entry.remaining=6.0
		entry.quote="Merci, c’est exactement ma commande !"
		game.play_sound(740)
		game.say("Table %d servie ! Le client déguste sa commande." % number)
	else:
		entry.state="leaving"
		entry.emotion="angry"
		entry.quote="Ce n’est pas ma commande ! Je pars, et je ne paie rien !"
		game.play_sound(180)
		game.say("Table %d : mauvaise commande, le client part furieux sans payer !" % number)
	if selected==number: selected=0
	game.save_progress()
	return true
func select_table(number: int) -> void:
	var entry=person(number)
	if entry.is_empty() or entry.state in ["eating","leaving"]: return
	selected=number
	game.selected=int(entry.recipe)
	var kind: String=game.recipe(int(entry.recipe)).get("kind","wrap")
	var station:=745.0 if kind=="drink" else 650.0
	if game.room=="restaurant" and absf(game.player.x-station)<100:
		game.ui.show_page("cookdrink" if kind=="drink" else "cookwrap")
	else:
		game.ui.hide_page()
		if game.room!="restaurant": game.travel("restaurant",1120)
		game.move_goal=station
		game.click_target={"action":"interact"}
func visit(number: int) -> void:
	if person(number).is_empty(): game.say("Table %d libre." % number); return
	if game.holding>=0: serve_table(number)
	else:
		selected=number
		game.ui.show_page("table")
func status(entry: Dictionary) -> String:
	return {"to_room":"S’installe","walking":"S’installe","waiting":"À préparer","eating":"Déguste","leaving":"Part furieux" if entry.get("emotion")=="angry" else "S’en va"}.get(str(entry.get("state","")),"")
func build_orders(box: VBoxContainer) -> void:
	box.add_child(game.ui.label("%d / 8 tables occupées · Choisis une commande à préparer." % people.size(),16))
	if people.is_empty(): box.add_child(game.ui.label("Accueille un client au restaurant et choisis sa table.",16))
	for number in range(1,COUNT+1):
		var entry=person(number)
		if entry.is_empty(): continue
		var title: String="TABLE %d · %s · %s" % [number,game.recipe(int(entry.recipe)).name,status(entry)]
		var row=HBoxContainer.new()
		box.add_child(row)
		var item_button=game.ui.button(title,func(): select_table(number))
		item_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		item_button.disabled=entry.state in ["eating","leaving"]
		row.add_child(item_button)
		row.add_child(game.ui.button("Y ALLER",func():
			game.ui.hide_page()
			game.travel("dining",1100)
			game.move_goal=spot(number).x
			game.click_target={"action":"table_visit","table":number}))
		var parts: Array[String]=[]
		for id in game.recipe(int(entry.recipe)).ingredients: parts.append(game.ingredient(id).name)
		box.add_child(game.ui.label(" + ".join(parts),13))
func build_reception(box: VBoxContainer) -> void:
	if game.customer_state!="waiting": box.add_child(game.ui.label("Le prochain client arrive…",18)); return
	box.add_child(game.ui.label(game.sheet.customers[game.actor_customer].name+" · "+game.recipe(game.order).name,18))
	box.add_child(game.ui.label("Choisis une table libre pour prendre sa commande.",15))
	var grid=GridContainer.new(); grid.columns=4; box.add_child(grid)
	for number in range(1,COUNT+1):
		var item_button=game.ui.button("TABLE %d" % number,func():
			if welcome(number): game.ui.hide_page())
		item_button.disabled=number not in free_tables()
		grid.add_child(item_button)
	if free_tables().is_empty(): box.add_child(game.ui.label("Salle complète : sers les tables avant d’accueillir un autre client.",15))
func build_table(box: VBoxContainer) -> void:
	var entry=person(selected)
	if entry.is_empty(): box.add_child(game.ui.label("Cette table est libre.",18)); return
	box.add_child(game.ui.label("TABLE %d · %s" % [selected,game.sheet.customers[int(entry.customer)].name],20))
	box.add_child(game.ui.label(game.recipe(int(entry.recipe)).name+" · "+status(entry),17))
	var number:=selected
	box.add_child(game.ui.button("PRÉPARER CETTE COMMANDE",func(): select_table(number)))
	if not str(entry.quote).is_empty(): box.add_child(game.ui.label(str(entry.quote),14))
func _process(delta: float) -> void:
	if game.online and game.online.active and (not game.online.hosting or not game.online.updates.state.is_empty()): return
	if game.menu and not (game.online and game.online.active): return
	var departed: Array=[]
	for entry in people:
		entry.phase+=delta*8
		var target=spot(int(entry.table))
		match entry.state:
			"to_room":
				entry.x=move_toward(float(entry.x),1190,120*delta)
				if float(entry.x)>=1190: entry.state="walking"; entry.x=1140.0
			"walking":
				entry.x=move_toward(float(entry.x),target.x,160*delta)
				if is_equal_approx(float(entry.x),target.x): entry.state="waiting"
			"eating":
				entry.remaining=maxf(0,float(entry.remaining)-delta)
				if float(entry.remaining)<=0: entry.state="leaving"
			"leaving":
				entry.x=move_toward(float(entry.x),1210,(250 if entry.emotion=="angry" else 140)*delta)
				if float(entry.x)>=1210: departed.append(entry)
	for entry in departed: people.erase(entry)
	if not departed.is_empty(): game.save_progress()
func targets() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	for number in range(1,COUNT+1):
		var at=spot(number)
		result.append({"id":"table_"+str(number),"table":number,"x":at.x,"label":"TABLE %d" % number,"rect":Rect2(at.x-100,at.y-118,200,158),"action":"table_visit"})
	return result
func draw_arrivals() -> void:
	for entry in people:
		if entry.state=="to_room": game.alien(Vector2(float(entry.x),520),Color.WHITE,false,{"customer":entry.customer,"appearance":entry.appearance,"moving":true,"phase":entry.phase,"facing":1.0})
func draw_dining() -> void:
	var art=preload("res://visual_library.gd")
	game.draw_texture_rect_region(game.room_textures.restaurant,Rect2(0,0,1200,365),Rect2(0,0,1200,365))
	game.draw_texture_rect_region(art.interface(2),Rect2(0,365,1200,267),Rect2(110,170,370,240),Color(0.62,0.65,0.69))
	game.label_at("SALLE ORBITALE · 8 TABLES",Vector2(340,158),25,Color("efd37d"))
	for number in range(1,COUNT+1):
		var at=spot(number)
		var entry=person(number)
		game.draw_texture_rect(art.interface(1),Rect2(at.x-37,at.y-108,74,92),false,Color("82644f"))
		if not entry.is_empty() and entry.state not in ["to_room","walking","leaving"]:
			game.alien(at+Vector2(0,12),Color.WHITE,false,{"customer":entry.customer,"appearance":entry.appearance,"moving":false,"phase":entry.phase,"seated":true})
		game.draw_texture_rect(preload("res://art/dining_table.svg"),Rect2(at.x-103,at.y-45,206,113),false)
		game.label_at("%d" % number,at+Vector2(-6,-3),16,Color("efd37d"))
		if not entry.is_empty():
			game.label_at(status(entry),at+Vector2(-60,48),12,Color("f18b78") if entry.emotion=="angry" else Color("e2dbca"))
			if entry.state=="eating": game.draw_texture_rect(art.object(11 if game.recipe(int(entry.recipe)).get("kind","wrap")=="drink" else 15),Rect2(at.x+32,at.y-69,34,45),false)
	for entry in people:
		if entry.state in ["walking","leaving"]:
			var at=spot(int(entry.table))
			game.alien(Vector2(float(entry.x),at.y+15),Color.WHITE,false,{"customer":entry.customer,"appearance":entry.appearance,"moving":true,"phase":entry.phase,"facing":1.0 if entry.state=="leaving" else -1.0})
			if entry.emotion=="angry": game.label_at("!",Vector2(float(entry.x),at.y-110),24,Color("f18b78"))
	game.alien(game.player,Color("bca2e9"),true)
	game.draw_door_art()
	game.draw_interaction_markers()
func snapshot() -> Array: return people.duplicate(true)
func restore(saved: Variant) -> void:
	people.clear()
	if not saved is Array: return
	for value in saved:
		if not value is Dictionary: continue
		var number:=int(value.get("table",0)); var recipe_index:=int(value.get("recipe",-1))
		if number<1 or number>COUNT or not person(number).is_empty() or recipe_index<0 or recipe_index>=game.sheet.recipes.size() or game.recipe(recipe_index).get("custom",false): continue
		var stage:=str(value.get("state","waiting"))
		if stage not in ["to_room","walking","waiting","eating","leaving"]: stage="waiting"
		var customer_index:=clampi(int(value.get("customer",0)),0,game.sheet.customers.size()-1)
		people.append({"table":number,"customer":customer_index,"appearance":game.restore_appearance(value.get("appearance",{})),"recipe":recipe_index,"state":stage,"emotion":"angry" if value.get("emotion")=="angry" else "happy" if stage=="eating" else "calm","x":clampf(float(value.get("x",spot(number).x)),0,1210),"remaining":clampf(float(value.get("remaining",0)),0,6),"phase":float(value.get("phase",0)),"quote":str(value.get("quote","")).left(180)})
