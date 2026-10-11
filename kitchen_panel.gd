extends RefCounted
class Assembly extends Control:
	var colors: Array[Color]=[]
	func _draw() -> void:
		var c=Vector2(size.x*0.5,52)
		draw_circle(c,47,Color("24384a"))
		draw_colored_polygon(PackedVector2Array([c+Vector2(-40,-24),c+Vector2(40,-24),c+Vector2(26,36),c+Vector2(-26,36)]),Color("e4bd7f"))
		for i in range(colors.size()):
			var y=-21+i*7
			draw_line(c+Vector2(-29,y),c+Vector2(29,y),colors[i],7,true)
		draw_colored_polygon(PackedVector2Array([c+Vector2(-39,-15),c+Vector2(9,24),c+Vector2(-24,34)]),Color("f1d39a"))
		draw_colored_polygon(PackedVector2Array([c+Vector2(39,-15),c+Vector2(-9,24),c+Vector2(24,34)]),Color("d7ac70"))
		draw_line(c+Vector2(-24,34),c+Vector2(24,34),Color("ae7e48"),3,true)

static func build(ui: Node, box: VBoxContainer, kind: String) -> void:
	var game=ui.game
	var chosen: Array=ui.get_meta("wrap_composition",[]).duplicate()
	var hint=ui.label("Clique sur les ingrédients pour les ajouter ou les retirer.",15)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	if game.customer_state=="waiting": box.add_child(ui.label("Commande : "+game.recipe(game.order).name,16,Color("efd37d")))
	var assembly=Assembly.new()
	assembly.custom_minimum_size=Vector2(0,100)
	for id in chosen: assembly.colors.append(Color(game.ingredient(id).color))
	if kind=="wrap": box.add_child(assembly)
	else: assembly.free()
	var grid=GridContainer.new()
	grid.columns=2
	box.add_child(grid)
	for item in game.sheet.ingredients:
		var id: String=item.id
		var present=id in chosen
		var pick=ui.button(("− " if present else "+ ")+item.short_name+" · stock "+str(game.inventory[id]),func():
			var next: Array=ui.get_meta("wrap_composition",[]).duplicate()
			if id in next: next.erase(id)
			else: next.append(id)
			ui.set_meta("wrap_composition",next)
			ui.show_page("cookdrink" if kind=="drink" else "cookwrap"))
		pick.custom_minimum_size.x=285
		pick.disabled=game.inventory[id]<1 and not present
		grid.add_child(pick)
	var match_index=-1
	var target=chosen.duplicate()
	target.sort()
	for i in range(game.sheet.recipes.size()):
		var recipe: Dictionary=game.recipe(i)
		if recipe.get("kind","wrap")!=kind: continue
		var required: Array=recipe.ingredients.duplicate()
		required.sort()
		if target==required: match_index=i; break
	var result="Choisis une combinaison de la carte ci-dessous." if match_index<0 else game.recipe(match_index).name
	if match_index>=0 and not game.recipe_unlocked(match_index): result+=" · recette encore verrouillée"
	box.add_child(ui.label(result,18,ui.CYAN))
	var prepare=ui.button("FABRIQUER LA BOISSON" if kind=="drink" else "ROULER ET CUISINER LE WRAP",func():
		game.selected=match_index
		if game.cook(): ui.hide_page()
		else: ui.show_page("cookdrink" if kind=="drink" else "cookwrap"))
	prepare.disabled=match_index<0 or game.holding>=0
	if match_index>=0: prepare.disabled=prepare.disabled or not game.recipe_unlocked(match_index)
	box.add_child(prepare)
	if game.holding>=0:
		box.add_child(ui.label("Une commande est déjà prête : sers-la ou range-la.",15))
		box.add_child(ui.button("RANGER LA COMMANDE",func(): game.return_wrap(); ui.show_page("cookdrink" if kind=="drink" else "cookwrap")))
	box.add_child(ui.label("CARTE / combinaisons d’ingrédients",16,ui.CYAN))
	for i in range(game.sheet.recipes.size()):
		var recipe: Dictionary=game.recipe(i)
		if recipe.get("kind","wrap")!=kind: continue
		var names: Array[String]=[]
		for id in recipe.ingredients: names.append(game.ingredient(id).short_name)
		var line=ui.label(recipe.name+" : "+" + ".join(names)+(" · verrouillée" if not game.recipe_unlocked(i) else ""),14)
		line.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)
