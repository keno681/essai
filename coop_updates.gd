extends Node
const RESUME_FILE := "/.console-runtime/coop-resume.json"
const CORE := ["coop_updates.gd","online_coop.gd","console.gd","patch_engine.gd"]
var net: Node
var game: Node
var enabled := true
var state := ""
var token := ""
var patch := ""
var transaction: Dictionary = {}
var record: Dictionary = {}
var elapsed := 0.0
var restarting := false
var peer_frozen := false
var worker: Thread
var ready_before: Dictionary={}

func _ready() -> void:
	net=get_parent()
	game=net.game
	if game.console_node.managed: resume.call_deferred()

func path() -> String: return game.console_node.root_path+RESUME_FILE

func local_hashes(expected: Dictionary) -> Dictionary:
	var result := {}
	for name in expected:
		var file: String = game.console_node.engine.path_for(name)
		result[name]=FileAccess.get_file_as_string(file).sha256_text() if FileAccess.file_exists(file) else "ABSENT"
	return result

func hashes(files: Dictionary) -> Dictionary:
	var result := {}
	for name in files: result[name]=files[name].sha256_text() if files[name] is String else "ABSENT"
	return result

func fail(message: String) -> void:
	state=""
	elapsed=0
	transaction.clear()
	game.console_node.progressing=false
	game.console_node.status=message
	game.console_node.changed.emit()
	game.say(message)
	peer_frozen=false

func begin(words: String) -> void:
	if not state.is_empty(): return
	if not net.hosting or not net.authenticated:
		fail("L'hôte doit être connecté à son coéquipier pour une modification commune.")
		return
	if not enabled or not game.console_node.managed:
		fail("Active les mises à jour communes et lance le jeu avec JOUER.cmd.")
		return
	if not state.is_empty(): return
	transaction=game.console_node.engine.prepare(words)
	if transaction.is_empty(): fail(game.console_node.engine.error); return
	for name in transaction.after:
		if name in CORE:
			fail("Les scripts de synchronisation se mettent à jour hors coop, sur les deux PC : "+name)
			return
	state="validation"
	game.console_node.progressing=true
	patch=words
	token=Crypto.new().generate_random_bytes(12).hex_encode()
	elapsed=0
	game.console_node.status="Vérification locale avant envoi au coéquipier…"
	game.console_node.changed.emit()
	ready_before={}
	for name in transaction.before: ready_before[name]=transaction.before[name].text.sha256_text() if transaction.before[name].exists else "ABSENT"
	worker=Thread.new()
	worker.start(func(): return game.console_node.engine.preflight(transaction,OS.get_executable_path()))

func receive(data: Dictionary, sender: int) -> void:
	if sender!=net.partner_id: return
	var kind := str(data.get("kind",""))
	if not net.authenticated and not (state=="resuming" and kind in ["update_done","update_rollback"] and str(data.get("token",""))==token): return
	if kind=="update_prepare" and not net.hosting:
		if not enabled or not game.console_node.managed or not state.is_empty():
			net.send({"kind":"update_ready","token":data.get("token",""),"ok":false,"message":"Le coéquipier doit activer la synchronisation et utiliser JOUER.cmd."})
			return
		var words := str(data.get("patch",""))
		transaction=game.console_node.engine.prepare(words)
		var reason: String = game.console_node.engine.error
		var ok := not transaction.is_empty()
		if ok:
			for name in transaction.after:
				if name in CORE: ok=false; reason="Modification du moteur de synchronisation refusée."; break
		if ok and (not data.get("before") is Dictionary or local_hashes(data.before)!=data.before): ok=false; reason="Les fichiers des deux jeux sont différents. Mise à jour annulée."
		if not ok:
			fail(reason)
			net.send({"kind":"update_ready","token":data.get("token",""),"ok":false,"message":reason})
			return
		state="validation"
		game.console_node.progressing=true
		token=str(data.token)
		patch=words
		elapsed=0
		game.say("Mise à jour reçue de l’hôte : vérification du jeu…")
		worker=Thread.new()
		worker.start(func(): return game.console_node.engine.preflight(transaction,OS.get_executable_path()))

	elif kind=="update_ready" and net.hosting and state=="await_ready" and str(data.get("token",""))==token:
		if not bool(data.get("ok",false)): fail(str(data.get("message","Mise à jour refusée par le coéquipier."))); return
		var session := {"world":game.snapshot(),"holding":game.holding,"partner_holding":int(net.partner.get("holding",-1))}
		session.world.coop_carried=-1
		if not write_record("apply",session): abort_remote("Impossible de préparer la relance de l'hôte."); return
		state="await_stored"
		elapsed=0
		net.send({"kind":"update_commit","token":token,"session":session})
	elif kind=="update_commit" and not net.hosting and state=="await_commit" and str(data.get("token",""))==token:
		if not write_record("apply",data.get("session",{})):
			net.send({"kind":"update_stored","token":token,"ok":false}); fail("Préparation de relance impossible."); return
		state="await_restart"
		elapsed=0
		net.send({"kind":"update_stored","token":token,"ok":true})
	elif kind=="update_stored" and net.hosting and state=="await_stored" and str(data.get("token",""))==token:
		if not bool(data.get("ok",false)): abort_remote("Le coéquipier ne peut pas préparer sa relance."); return
		state="await_go"
		net.send({"kind":"update_restart","token":token})
	elif kind=="update_restart" and not net.hosting and state=="await_restart" and str(data.get("token",""))==token:
		state="restarting"
		net.send({"kind":"update_go","token":token})
		restart.call_deferred(patch)
	elif kind=="update_go" and net.hosting and state=="await_go" and str(data.get("token",""))==token:
		state="restarting"
		restart.call_deferred(patch)
	elif kind=="update_abort":
		DirAccess.remove_absolute(path())
		fail(str(data.get("message","Mise à jour annulée.")))
	elif kind=="update_done" and not net.hosting:
		finish(str(data.get("message","Mise à jour commune appliquée.")))
	elif kind=="update_rollback" and not net.hosting and state=="resuming":
		rollback()

func abort_remote(message: String) -> void:
	net.send({"kind":"update_abort","message":message})
	DirAccess.remove_absolute(path())
	fail(message)

func write_record(phase: String, session: Dictionary) -> bool:
	var world: Dictionary=session.get("world",game.snapshot()).duplicate(true)
	world.coop_carried=-1
	var own: Dictionary=net.local_player()
	world.room=own.room
	world.player_x=own.x
	world.player_race=own.race
	world.holding=int(session.get("holding",game.holding)) if net.hosting else int(session.get("partner_holding",game.holding))
	record={"token":token,"phase":phase,"hosting":net.hosting,"address":net.address,"password":net.password,"world":world,"solo":net.solo_save.duplicate(true),"partner_holding":int(session.get("partner_holding",net.partner.get("holding",-1))),"before":transaction.before.duplicate(true),"expected":hashes(transaction.after)}
	DirAccess.make_dir_recursive_absolute(path().get_base_dir())
	var file=FileAccess.open(path()+".tmp",FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(record))
	file.close()
	return DirAccess.rename_absolute(path()+".tmp",path())==OK

func restart(words: String) -> void:
	restarting=true
	# Keep ENet polling long enough to flush and acknowledge the final restart packet.
	await get_tree().create_timer(1.0).timeout
	if not game.console_node.queue_restart({"action":"apply","patch":words}):
		restarting=false
		abort_remote(game.console_node.status)

func resume() -> void:
	if not FileAccess.file_exists(path()): return
	var saved=JSON.parse_string(FileAccess.get_file_as_string(path()))
	if not saved is Dictionary or not saved.get("world") is Dictionary or not saved.get("expected") is Dictionary:
		DirAccess.remove_absolute(path()); return
	record=saved
	token=str(record.get("token",""))
	state="resuming"
	elapsed=0
	game.apply_snapshot(record.world)
	net.password=str(record.get("password",""))
	if bool(record.get("hosting",false)):
		net.host()
		if net.active: net.partner={"holding":int(record.get("partner_holding",-1))}
	else:
		net.join(str(record.get("address","")),str(record.get("password","")))
		net.solo_save=record.get("solo",{}).duplicate(true)
	if not net.active: fail("Relance terminée, mais reconnexion impossible. Ouvre le menu coop.")

func resume_hello() -> Dictionary:
	return {"token":token,"expected":record.get("expected",{}),"ok":local_hashes(record.get("expected",{}))==record.get("expected",{}),"phase":record.get("phase","")}

func matching_resume(data: Dictionary) -> bool:
	return state=="resuming" and data.get("resume") is Dictionary and str(data.resume.get("token",""))==token

func on_connected(data: Dictionary) -> bool:
	if state!="resuming": return true
	if not matching_resume(data):
		net.send({"kind":"denied","message":"La mise à jour doit être terminée par le même coéquipier."})
		return false
	var ok: bool = bool(data.resume.get("ok",false)) and local_hashes(record.expected)==record.expected and data.resume.get("expected",{})==record.expected
	if ok:
		net.partner={"holding":int(record.get("partner_holding",-1))}
		var message := "Mise à jour commune appliquée. Coop reconnectée." if record.get("phase")=="apply" else "Mise à jour annulée sur les deux PC. Coop reconnectée."
		net.send({"kind":"update_done","token":token,"message":message})
		finish(message)
		return true
	if record.get("phase")=="rollback":
		net.send({"kind":"denied","message":"Restauration incomplète. Vérifie les erreurs de la console sur les deux PC."})
		fail("Restauration incomplète ; connexion suspendue. Vérifie la console.")
		return false
	net.send({"kind":"update_rollback","token":token})
	rollback.call_deferred()
	return false

func rollback() -> void:
	var operations := []
	for name in record.get("before",{}):
		var prior: Dictionary=record.before[name]
		var file: String = game.console_node.engine.path_for(name)
		var exists := FileAccess.file_exists(file)
		var current := FileAccess.get_file_as_string(file) if exists else ""
		if prior.exists:
			if not exists or current!=str(prior.text): operations.append({"path":name,"write":str(prior.text)})
		elif exists: operations.append({"path":name,"delete":true})
	if operations.is_empty():
		var text := FileAccess.get_file_as_string(game.console_node.root_path+"/project.godot")
		operations.append({"path":"project.godot","old":text,"new":text})
	var rollback_patch := JSON.stringify({"format":"cosmowrap-patch-v1","title":"Annulation de la mise à jour commune","files":operations})
	var expected := {}
	for name in record.before: expected[name]=str(record.before[name].text).sha256_text() if record.before[name].exists else "ABSENT"
	record.phase="rollback"
	record.expected=expected
	var file=FileAccess.open(path(),FileAccess.WRITE)
	if not file: fail("Impossible d'enregistrer la restauration ; fichiers conservés."); return
	file.store_string(JSON.stringify(record)); file.close()
	state="restarting"
	restart.call_deferred(rollback_patch)

func finish(message: String) -> void:
	DirAccess.remove_absolute(path())
	record.clear()
	state=""
	peer_frozen=false
	game.console_node.progressing=false
	game.console_node.status="PRÊT · "+message
	game.say(message)

func _process(delta: float) -> void:
	if worker and not worker.is_alive():
		var ok: bool=worker.wait_to_finish()
		worker=null
		if state!="validation": return
		if not net.active or not net.authenticated or not enabled: fail("Validation terminée, mais la coop ou la synchronisation est désactivée."); return
		if not ok:
			var reason: String=game.console_node.engine.error
			if not net.hosting: net.send({"kind":"update_ready","token":token,"ok":false,"message":reason})
			fail(reason)
			return
		elapsed=0
		if net.hosting:
			state="await_ready"
			net.send({"kind":"update_prepare","token":token,"patch":patch,"before":ready_before})
			game.console_node.status="Vérification de la mise à jour sur le PC du coéquipier…"
			game.console_node.changed.emit()
		else:
			state="await_commit"
			game.say("Mise à jour vérifiée. Redémarrage commun imminent…")
			net.send({"kind":"update_ready","token":token,"ok":true})
	if state.is_empty() or state in ["validation","restarting"]: return
	elapsed+=delta
	if state=="resuming":
		if elapsed>65:
			DirAccess.remove_absolute(path())
			net.leave("Reconnexion expirée après la mise à jour. Relance le salon manuellement.")
			fail(net.status)
	elif elapsed>40: abort_remote("Le coéquipier ne répond pas. Aucun redémarrage effectué.")

func _exit_tree() -> void:
	if worker: worker.wait_to_finish()
