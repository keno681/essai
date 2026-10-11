extends Node
const VERSION := "cosmo-coop-3"
const PORT := 16383
var game: Node
var peer: ENetMultiplayerPeer
var hosting := false
var active := false
var authenticated := false
var partner_id := 0
var partner: Dictionary = {}
var password := ""
var status := "Hors ligne"
var pending_seconds := 0.0
var address := ""
var timer := 0.0
var timeout := 0.0
var executing_remote := false
var solo_save: Dictionary = {}
var sequence := 0
var last_command := 0
var pending := false
var updates: Node
var partner_position := Vector2.ZERO
var partner_room := ""

func _ready() -> void:
	game = get_parent()
	password = Crypto.new().generate_random_bytes(4).hex_encode()
	updates=load("res://coop_updates.gd").new()
	add_child(updates)

func local_addresses() -> String:
	var addresses: Array[String]=[]
	for ip in IP.get_local_addresses():
		if ":" not in ip and not ip.begins_with("127.") and not ip.begins_with("169.254."): addresses.append(ip)
	return ", ".join(addresses)

func host() -> void:
	if active: return
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT,1)
	if error != OK:
		status = "Impossible d'ouvrir le port UDP %d : erreur %d" % [PORT,error]
		peer = null
		return
	hosting = true
	active = true
	authenticated = false
	timer = 0
	peer.peer_connected.connect(func(id): partner_id=id; timeout=0)
	peer.peer_disconnected.connect(func(_id): remove_partner())
	status = "Salon ouvert · UDP %d · Mot de passe : %s" % [PORT,password]
	game.ui.hide_page()

func join(ip: String, secret: String) -> void:
	if active: return
	address = ip.strip_edges()
	if address.is_empty() or secret.strip_edges().is_empty():
		status = "Saisis l'adresse IP et le mot de passe de l'hôte."
		return
	solo_save = game.snapshot().duplicate(true)
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address,PORT)
	if error != OK:
		peer=null
		status="Connexion impossible : erreur %d" % error
		return
	hosting=false
	active=true
	authenticated=false
	partner_id=1
	password=secret.strip_edges()
	timeout=0
	timer=0
	sequence=0
	pending=false
	status="Connexion en cours…"
	peer.peer_connected.connect(func(_id): send({"kind":"hello","version":VERSION,"design":FileAccess.get_file_as_string("res://data/design.json").sha256_text(),"password":password,"resume":updates.resume_hello()}))

func send(packet: Dictionary, target: int = 0) -> void:
	if not peer or peer.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return
	peer.set_target_peer(target if target!=0 else partner_id)
	peer.transfer_mode=MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var sent := peer.put_packet(JSON.stringify(packet).to_utf8_buffer())
	if sent!=OK:
		status="Transmission réseau impossible : erreur %d" % sent
		game.say(status)

func local_player() -> Dictionary:
	return {"x":game.player.x,"y":game.player.y,"room":game.room,"race":game.player_race,"moving":game.walking,"phase":game.walk_cycle,"facing":game.facing,"holding":game.holding}

func sanitize_player(data: Variant) -> Dictionary:
	if not data is Dictionary: return {}
	for key in ["x","y","phase","facing"]:
		if not (data.get(key,0) is int or data.get(key,0) is float): return {}
		if not is_finite(float(data.get(key,0))): return {}
	var room_name := str(data.get("room","restaurant"))
	if room_name not in ["restaurant","office","garden","planet"]: return {}
	var race := "human"
	for row in game.sheet.races:
		if row.id == str(data.get("race","human")): race=row.id
	return {"x":clampf(float(data.get("x",565)),40,3560 if room_name=="planet" else 1160),"y":clampf(float(data.get("y",505)),250,505),"room":room_name,"race":race,"moving":bool(data.get("moving",false)),"phase":fmod(float(data.get("phase",0)),TAU),"facing":1.0 if float(data.get("facing",1))>=0 else -1.0,"holding":-1}

func _process(delta: float) -> void:
	if not active or not peer: return
	peer.poll()
	if not active or not peer: return
	timeout+=delta
	if pending:
		pending_seconds+=delta
		if pending_seconds>10:
			leave("Action sans réponse. Coop fermée ; retour à ta partie solo.")
			return
	if not hosting and peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED:
		leave("Connexion fermée. Retour à ta partie solo.")
		return
	if not authenticated and timeout>(60 if updates.state=="resuming" else 15):
		if hosting:
			if partner_id!=0: peer.disconnect_peer(partner_id,true); remove_partner()
		else: leave("Connexion expirée : vérifie IP, mot de passe et port UDP 16383.")
		return
	var count := 0
	while peer and peer.get_available_packet_count()>0 and count<32:
		count+=1
		var sender := peer.get_packet_peer()
		var bytes := peer.get_packet()
		if bytes.size()>3000000: continue
		var data=JSON.parse_string(bytes.get_string_from_utf8())
		if data is Dictionary: receive(data,sender)
	if not active: return
	timer+=delta
	if timer>=0.1:
		timer=0
		if authenticated:
			if hosting and updates.state.is_empty(): send_world()
			else: send({"kind":"player","player":local_player()})
	if partner.has("x") and partner.has("room"):
		var target := Vector2(float(partner.x),float(partner.y))
		if partner_room!=str(partner.room): partner_position=target; partner_room=str(partner.room)
		else: partner_position=partner_position.lerp(target,1.0-exp(-14.0*delta))
	game.queue_redraw()

func receive(data: Dictionary, sender: int) -> void:
	if sender!=partner_id: return
	var kind := str(data.get("kind",""))
	if kind.begins_with("update_"):
		updates.receive(data,sender)
		return
	if hosting:
		if kind=="hello":
			if str(data.get("version",""))!=VERSION or (not updates.matching_resume(data) and str(data.get("design",""))!=FileAccess.get_file_as_string("res://data/design.json").sha256_text()) or str(data.get("password",""))!=password:
				send({"kind":"denied","message":"Mot de passe incorrect ou versions différentes."})
				return
			if not updates.on_connected(data): return
			authenticated=true
			if updates.state.is_empty() and not partner.has("holding"): partner={}
			last_command=0
			status="Coop connectée · 2 joueurs"
			send_world()
		elif authenticated and kind=="player":
			var checked := sanitize_player(data.get("player"))
			if not checked.is_empty():
				checked.holding=int(partner.get("holding",-1))
				partner=checked
		elif authenticated and kind=="action": handle_action(data)
	else:
		if kind=="denied": leave(str(data.get("message","Connexion refusée")))
		elif kind=="world" and data.get("world") is Dictionary:
			if not authenticated:
				authenticated=true
				game.holding=-1
				game.ui.hide_page()
			status="Coop connectée · Restaurant de l'hôte"
			apply_world(data.world)
			partner=sanitize_player(data.get("player"))
			if not partner.is_empty(): partner.holding=int(data.player.get("holding",-1))
			game.holding=int(data.get("holding",-1))
		elif authenticated and kind=="result":
			pending=false
			game.say(str(data.get("message","")))
			if bool(data.get("ok",false)):
				if str(data.get("action",""))=="cook":
					var crafted_kind: String=game.recipe(int(data.get("args",{}).get("recipe",0))).get("kind","wrap")
					game.ui.set_meta("composition_"+crafted_kind,[])
					game.ui.hide_page()
				elif str(data.get("action",""))=="discard_preparation":
					var discard_kind: String=str(data.get("args",{}).get("kind","wrap"))
					game.ui.set_meta("composition_"+discard_kind,[])
					game.ui.show_page("cookdrink" if discard_kind=="drink" else "cookwrap")
				elif str(data.get("action",""))=="discard_order": game.ui.show_page("cookdrink" if game.ui.page=="cookdrink" else "cookwrap")
				elif str(data.get("action",""))=="chat":
					if game.customer_state=="leaving": game.ui.hide_page()
					else: game.ui.show_page("chat")
				elif str(data.get("action","")) in ["harvest","empty","plant"]: game.planters.open(str(data.get("args",{}).get("id","")))

func send_world() -> void:
	var world: Dictionary=game.snapshot()
	for key in ["player_x","player_race","room","holding"]: world.erase(key)
	world["speech"]=game.speech
	world["speech_time"]=game.speech_time
	world["speech_elapsed"]=game.speech_elapsed
	send({"kind":"world","world":world,"player":local_player(),"holding":int(partner.get("holding",-1))})

func apply_world(world: Dictionary) -> void:
	for key in ["coins","served","upgraded","inventory","discovered","order","customer","actor_customer","customer_state","customer_x","customer_emotion","appearance","queued_appearance","cooldowns","node_cooldowns","deliveries","chat_log","chat_memory","speech","speech_time","speech_elapsed"]:
		if world.has(key): game.set(key,world[key])
	game.completed=game.served>=3
	game.planters.restore(world.get("plantings",{}))
	game.customer_queue.restore(world.get("waiting_queue",{}))

func request(action: String, args: Dictionary = {}) -> bool:
	if not active: return false
	if not updates.state.is_empty():
		game.say("Mise à jour commune en cours…")
		return true
	if hosting: return false
	if not authenticated:
		game.say("Attends la connexion au restaurant.")
		return true
	if pending:
		game.say("Une action est déjà en cours…")
		return true
	sequence+=1
	pending=true
	pending_seconds=0
	send({"kind":"action","sequence":sequence,"action":action,"args":args,"player":local_player()})
	game.say("Action envoyée à l'hôte…")
	return true

func near_station(id: String) -> bool:
	if game.room=="restaurant":
		for item in game.sheet.ingredients:
			if item.starter and item.id==id: return absf(game.player.x-float(item.x))<90
	elif game.room=="garden":
		for bed in game.sheet.beds:
			if bed.id==id: return absf(game.player.x-float(bed.x))<90
	return false

func handle_action(data: Dictionary) -> void:
	if not updates.state.is_empty():
		send({"kind":"result","ok":false,"message":"Mise à jour commune en cours."})
		return
	if not (data.get("sequence") is int or data.get("sequence") is float): return
	if not is_finite(float(data.sequence)): return
	var number := int(data.get("sequence",0))
	if number<=last_command: return
	last_command=number
	var actor := sanitize_player(data.get("player"))
	if actor.is_empty() or not data.get("args",{}) is Dictionary:
		send({"kind":"result","ok":false,"message":"Action invalide"})
		return
	var arguments: Dictionary=data.get("args",{})
	if str(data.get("action",""))=="cook" and not (arguments.get("recipe") is int or arguments.get("recipe") is float):
		send({"kind":"result","ok":false,"message":"Recette invalide"})
		return
	actor.holding=int(partner.get("holding",-1))
	partner=actor
	var own := local_player()
	var own_selected: int=game.selected
	var own_notice: String=game.message
	var own_menu: bool=game.menu
	game.player=Vector2(actor.x,actor.y)
	game.room=actor.room
	game.player_race=actor.race
	game.holding=int(actor.holding)
	executing_remote=true
	var args: Dictionary=data.get("args",{})
	var action := str(data.get("action",""))
	var ok := false
	game.message="Action impossible ici."
	match action:
		"cook":
			var index := int(args.get("recipe",-1))
			if game.room=="restaurant" and index>=0 and index<game.sheet.recipes.size():
				var station := 745.0 if game.recipe(index).get("kind","wrap")=="drink" else 650.0
				if absf(game.player.x-station)<100:
					game.selected=index
					ok=game.cook()
		"discard_preparation":
			var kind: String=str(args.get("kind",""))
			var station := 745.0 if kind=="drink" else 650.0
			if game.room=="restaurant" and absf(game.player.x-station)<100 and args.get("ingredients") is Array: ok=game.discard_preparation(kind,args.ingredients)
		"discard_order": ok=game.discard_order()
		"serve":
			if game.room=="restaurant" and absf(game.player.x-game.customer_x)<110: ok=game.serve()
		"return": game.return_wrap(); ok=true
		"handoff":
			if game.holding>=0 and int(own.holding)<0 and actor.room==own.room and absf(float(actor.x)-float(own.x))<130:
				own.holding=game.holding
				game.holding=-1
				game.message="Commande donnée au coéquipier."
				ok=true
		"purchase":
			if game.room=="office" and absf(game.player.x-830)<120: ok=game.purchase(str(args.get("id","")))
		"wild":
			if game.room=="planet":
				for node in game.sheet.wild_nodes:
					if node.id==str(args.get("id","")) and absf(game.player.x-float(node.x))<90: ok=game.harvest_node(node)
		"harvest","empty","plant":
			var id := str(args.get("id",""))
			if game.planters.plants.has(id) and near_station(id):
				if action=="harvest" and not str(game.planters.plants[id]).is_empty() and game.planters.timer(id)<=0: game.planters.harvest(id); ok=true
				elif action=="empty": game.planters.empty(id); ok=true
				elif action=="plant" and str(game.planters.plants[id]).is_empty() and str(args.get("crop","")) in game.discovered and not game.ingredient(str(args.get("crop",""))).get("pantry",false): game.planters.plant(id,str(args.crop)); ok=true
		"upgrade":
			if game.room=="restaurant" and absf(game.player.x-1090)<100 and not game.upgraded and game.coins>=35:
				game.coins-=35
				game.upgraded=true
				game.message="Terrasse ouverte !"
				ok=true
		"chat":
			if game.room=="restaurant": ok=game.chat_with_customer(str(args.get("text","")))
	partner.holding=game.holding
	var message: String=game.message if not ok else (game.message if game.message!="Action impossible ici." else "Action effectuée.")
	game.player=Vector2(own.x,own.y)
	game.room=own.room
	game.player_race=own.race
	game.holding=int(own.holding)
	game.selected=own_selected
	game.message=own_notice
	game.menu=own_menu
	executing_remote=false
	game.save_progress()
	send_world()
	send({"kind":"result","ok":ok,"action":action,"args":args,"message":message})

func handoff() -> void:
	if not active or not authenticated:
		game.say("Ton coéquipier doit être connecté.")
		return
	if request("handoff"): return
	if game.holding>=0 and int(partner.get("holding",-1))<0 and partner.get("room","")==game.room and absf(float(partner.get("x",0))-game.player.x)<130:
		partner.holding=game.holding
		game.holding=-1
		game.say("Commande donnée au coéquipier.")
		game.save_progress()
		send_world()
	else: game.say("Approche-toi du coéquipier ; il doit avoir les mains libres.")

func remove_partner() -> void:
	if not updates.state.is_empty():
		partner_id=0
		authenticated=false
		timeout=0
		return
	var carried := int(partner.get("holding",-1))
	if hosting and carried>=0 and carried<game.sheet.recipes.size():
		for id in game.recipe(carried).ingredients: game.inventory[id]+=1
	partner.clear()
	partner_room=""
	partner_id=0
	authenticated=false
	timeout=0
	status="Salon ouvert · Ami déconnecté · Mot de passe : "+password
	if hosting: game.save_progress()

func leave(message: String = "Retour au mode solo") -> void:
	updates.state=""
	DirAccess.remove_absolute(updates.path())
	if hosting: remove_partner()
	if peer: peer.close()
	peer=null
	active=false
	authenticated=false
	pending=false
	partner.clear()
	partner_room=""
	if not hosting and not solo_save.is_empty(): game.apply_snapshot(solo_save)
	solo_save.clear()
	hosting=false
	status=message

func draw_partner() -> void:
	if not active or not authenticated or not partner.has("room") or not partner.has("x") or partner.room!=game.room: return
	game.alien(partner_position-Vector2(game.camera_x,0),Color.WHITE,true,partner)
	game.label_at("COÉQUIPIER",partner_position-Vector2(game.camera_x+36,132),12,Color("8fe2ff"))
