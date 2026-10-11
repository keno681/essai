extends RefCounted
var game: Node
var people: Array[Dictionary] = []
var reserved: Dictionary = {}
const GAP := 70.0
const COUNT := 3

func setup(owner: Node) -> void:
	game = owner
	reset()

func make_person() -> Dictionary:
	var candidates: Array[int] = []
	var previous: int = int(people.back().customer) if not people.is_empty() else game.actor_customer
	for index in range(game.sheet.customers.size()):
		if index != previous: candidates.append(index)
	if candidates.is_empty(): candidates.append(0)
	var id: int = candidates[game.customer_rng.randi_range(0,candidates.size()-1)]
	return {"customer":id,"appearance":game.roll_appearance(),"x":maxf(float(game.sheet.systems[2].spawn_x),float(people.back().x)+GAP) if not people.is_empty() else float(game.sheet.systems[2].spawn_x),"phase":game.customer_rng.randf_range(0,TAU),"moving":true}

func reset() -> void:
	people.clear()
	reserved.clear()
	while people.size() < COUNT: people.append(make_person())

func take_next() -> void:
	if people.is_empty(): people.append(make_person())
	reserved = people.pop_front()
	game.customer = int(reserved.customer)
	game.queued_appearance = reserved.appearance.duplicate(true)
	while people.size() < COUNT: people.append(make_person())

func enter_service() -> float:
	var start: float = float(reserved.get("x",game.sheet.systems[2].spawn_x))
	reserved.clear()
	return start

func update(delta: float) -> void:
	var flow: Dictionary = game.sheet.systems[2]
	var ahead: float = maxf(float(flow.waiting_x),game.customer_x) if game.customer_state != "leaving" else float(flow.waiting_x)
	if not reserved.is_empty(): ahead = float(reserved.x)
	for person in people:
		var target: float = maxf(float(flow.waiting_x)+GAP,ahead+GAP)
		var before: float = float(person.x)
		person.x = move_toward(before,target,float(flow.speed)*delta)
		person.moving = not is_equal_approx(before,float(person.x))
		if person.moving: person.phase += delta*float(game.animation("walk").frequency)
		ahead = float(person.x)

func draw_people() -> void:
	for index in range(people.size()-1,-1,-1):
		var person: Dictionary = people[index]
		game.alien(Vector2(float(person.x),505),Color.WHITE,false,person)
	if not reserved.is_empty():
		var person := reserved.duplicate(true)
		person.moving = false
		game.alien(Vector2(float(person.x),505),Color.WHITE,false,person)

func snapshot() -> Dictionary:
	return {"people":people.duplicate(true),"reserved":reserved.duplicate(true)}

func restore_person(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("customer") is float and not value.get("customer") is int: return {}
	return {"customer":posmod(int(value.customer),game.sheet.customers.size()),"appearance":game.restore_appearance(value.get("appearance",{})),"x":clampf(float(value.get("x",1250)),1016,1600),"phase":float(value.get("phase",0)),"moving":false}

func restore(saved: Variant) -> void:
	reset()
	if saved is Dictionary and saved.get("people") is Array:
		people.clear()
		for entry in saved.people:
			var person := restore_person(entry)
			if not person.is_empty() and people.size() < COUNT: people.append(person)
		reserved = restore_person(saved.get("reserved",{}))
		while people.size() < COUNT: people.append(make_person())
	if game.customer_state == "leaving" and reserved.is_empty():
		reserved = {"customer":game.customer,"appearance":game.queued_appearance.duplicate(true),"x":1016.0,"phase":0.0,"moving":false}
