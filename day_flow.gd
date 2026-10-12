extends RefCounted
var game: Node
var number:=1
var admitted:=0
var resolved:=0
var happy:=0
var tutorial:=true
var intro_seen:=false
var summary_shown:=false
func limit() -> int: return 5 if number==1 else mini(12,6+number)
func reset() -> void:
	number=1; admitted=0; resolved=0; happy=0; tutorial=true; intro_seen=false; summary_shown=false
func snapshot() -> Dictionary:
	return {"number":number,"admitted":admitted,"resolved":resolved,"happy":happy,"tutorial":tutorial,"intro_seen":intro_seen}
func restore(data: Variant) -> void:
	if not data is Dictionary:
		number=2 if game.served>0 else 1; admitted=mini(limit(),game.tables.people.size()); resolved=0; happy=0; tutorial=game.served==0; intro_seen=game.served>0; summary_shown=false; return
	number=maxi(1,int(data.get("number",1)))
	admitted=clampi(int(data.get("admitted",0)),0,limit())
	resolved=clampi(int(data.get("resolved",0)),0,admitted)
	happy=clampi(int(data.get("happy",0)),0,resolved)
	tutorial=bool(data.get("tutorial",number==1)); intro_seen=bool(data.get("intro_seen",false)); summary_shown=false
func accept() -> bool:
	if admitted>=limit(): game.say("Les %d clients du jour ont déjà été accueillis." % limit()); return false
	admitted+=1
	return true
func finish(correct: bool) -> void:
	resolved=mini(admitted,resolved+1)
	if correct: happy=mini(resolved,happy+1)
func next_day() -> bool:
	if game.online and game.online.request("next_day"): return false
	if resolved<limit() or not game.tables.people.is_empty(): game.say("Termine le service et attends le départ des clients."); return false
	number+=1; admitted=0; resolved=0; happy=0; tutorial=false; summary_shown=false
	game.customer_queue.reset(); game.choose_customer(); game.next_order()
	game.actor_customer=game.customer; game.appearance=game.queued_appearance.duplicate(true)
	game.customer_x=game.customer_queue.enter_service(); game.customer_state="arriving"; game.customer_emotion="calm"
	game.reset_customer_conversation(); game.ui.hide_page(); game.save_progress()
	game.say("Jour %d · %d clients attendus !" % [number,limit()]); return true
func tick() -> void:
	if game.online and game.online.active and (not game.online.hosting or not game.online.updates.state.is_empty()): return
	if admitted>=limit(): game.customer_queue.people.clear(); game.customer_queue.reserved.clear()
	if resolved>=limit() and game.tables.people.is_empty() and not summary_shown and not game.menu:
		summary_shown=true; game.ui.show_page("day_end")
func guide() -> Dictionary:
	if not tutorial or number!=1 or happy>0: return {}
	if game.tables.people.is_empty(): return {"text":"TUTORIEL 1/5 · Clique sur le client à l’accueil et choisis une table libre.","target":"client" if game.customer_state=="waiting" else ""}
	var entry: Dictionary={}
	for item in game.tables.people:
		if item.state not in ["eating","leaving"]: entry=item; break
	if entry.is_empty(): return {}
	if game.holding>=0: return {"text":"TUTORIEL 5/5 · Clique sur la porte SALLE, puis sur la table %d pour servir." % entry.table,"target":"snack_dining" if game.room=="restaurant" else ""}
	for dish in game.counter_items:
		if int(dish.table)==int(entry.table): return {"text":"TUTORIEL 5/5 · Clique sur le comptoir et récupère la commande de la table %d." % entry.table,"target":"counter"}
	for id in game.recipe(int(entry.recipe)).ingredients:
		if game.inventory[id]>0: continue
		if game.inventory.get("raw_"+id,0)>0: return {"text":"TUTORIEL 3/5 · Cuisine : clique %s, puis fais trois gestes sur la planche. Le glisser-déposer reste possible." % game.ingredient(id).short_name,"target":"kitchen"}
		for bed in game.planters.plants:
			if game.planters.plants[bed]==id: return {"text":"TUTORIEL 2/5 · Clique sur le bac de %s pour récolter 3 ingrédients bruts." % game.ingredient(id).short_name,"target":bed}
		return {"text":"TUTORIEL 2/5 · Bac vide : plante une graine, puis récolte. Le PC du bureau vend les graines.","target":"snack_office"}
	return {"text":"TUTORIEL 4/5 · Clique sur le ticket de la table %d ; clique ou glisse les ingrédients prêts dans le wrap, puis ROULER ou PRÉPARER ET POSER." % entry.table,"target":"kitchen"}
func build_tutorial(box: VBoxContainer) -> void:
	box.add_child(game.ui.label("JOUR 1 · CINQ CLIENTS · À TON RYTHME",20,game.ui.CYAN))
	for text in ["1. Accueil : clique sur un client, puis sur une table libre. Le ticket de sa commande apparaît en cuisine.","2. Récolte : clique sur une plante mûre. Tu obtiens 3 ingrédients bruts ; le bac devient vide. Une graine permet de replanter.","3. Préparation à gauche : clique un aliment, puis trois fois sur la planche pour le couper, presser ou nettoyer. Il rejoint le stock prêt. Le glisser-déposer fonctionne aussi.","4. Cuisine à droite : ticket de table → ingrédients préparés dans le wrap → ROULER. PRÉPARER ET POSER permet de stocker au comptoir.","5. Service : prends une préparation au comptoir si nécessaire, entre dans la SALLE et clique sur la bonne table. Une mauvaise commande fâche le client.","Les clients sont patients. Le guide en bas indique la prochaine étape. I : inventaire ; O : commandes ; Échap : menu. Poubelle : jeter ; canapé du bureau : sauvegarder."]:
		var label=game.ui.label(text,16); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; box.add_child(label)
	var start=game.ui.button("COMMENCER / ACTIVER LE GUIDE",func(): intro_seen=true; tutorial=true; game.save_progress(); game.ui.hide_page())
	box.add_child(start); box.move_child(start,1)
	var skip=game.ui.button("JOUER SANS LE GUIDE",func(): intro_seen=true; tutorial=false; game.save_progress(); game.ui.hide_page())
	box.add_child(skip); box.move_child(skip,2)
func build_end(box: VBoxContainer) -> void:
	box.add_child(game.ui.label("JOUR %d TERMINÉ" % number,24,game.ui.CYAN))
	box.add_child(game.ui.label("%d clients traités · %d satisfaits · %d wrapcoincoins" % [resolved,happy,game.coins],17))
	box.add_child(game.ui.label("Les stocks, les graines, l’argent et les améliorations sont conservés.",16))
	box.add_child(game.ui.button("COMMENCER LE JOUR %d" % (number+1),func(): next_day()))
