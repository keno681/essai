import json
from pathlib import Path

data = json.loads((Path(__file__).parents[1] / "data/design.json").read_text())
required = {
    "ingredients": {"id", "name", "color", "x", "regrow_seconds"},
    "recipes": {"id", "name", "ingredients", "price", "joke"},
    "customers": {"id", "name", "color", "line"},
    "stations": {"id", "name", "x", "action"},
    "systems": {"id"},
    "visuals": {"id", "asset"},
    "animations": {"id"},
    "races": {"id", "name", "color", "sprite_index", "source_x", "source_width"},
    "interface": {"id"},
    "rooms": {"id", "name", "width", "asset"},
    "beds": {"id", "x", "ingredient", "room", "regrow_seconds"},
    "wild_nodes": {"id", "x", "ingredient", "room", "regrow_seconds"},
    "doors": {"id", "room", "x", "target", "arrival_x"},
    "currency": {"id", "name", "plural", "logo"},
    "customer_variation": {"id", "size_min", "size_max", "head_min", "head_max", "hats", "glasses", "tentacle_counts", "tentacle_forms", "skin_colors", "clothing_colors", "pants_colors", "shoe_colors"},
    "progression": {"id", "name", "served", "bonus"},
    "ai_chat": {"id", "model", "endpoint", "max_output_tokens", "history_messages", "timeout_seconds", "enabled_by_default", "persist_key", "fallback"},
    "chat": {"id", "keywords", "reply"},
    "dialogues": {"id", "greeting", "thanks"},
}
errors = []
for table, columns in required.items():
    ids = set()
    for row in data[table]:
        for key in columns | set(row):
            if key not in row or row[key] is None or row[key] == "":
                errors.append(f"{table}/{row.get('id')}/{key}: vide")
        if row["id"] in ids:
            errors.append(f"{table}: identifiant dupliqué {row['id']}")
        ids.add(row["id"])
ingredients = {row["id"] for row in data["ingredients"]}
races = {row["id"] for row in data["races"]}
for customer in data["customers"]:
    if customer["race"] not in races:
        errors.append(f"{customer['id']}: race inconnue")
for visual in data["visuals"]:
    if not (Path(__file__).parents[1] / visual["asset"]).is_file():
        errors.append(f"{visual['id']}: illustration manquante")
rooms = {row["id"] for row in data["rooms"]}
for room in data["rooms"]:
    if not (Path(__file__).parents[1] / room["asset"]).is_file():
        errors.append(f"{room['id']}: décor manquant")
for node in data["beds"] + data["wild_nodes"]:
    if node["ingredient"] not in ingredients or node["room"] not in rooms:
        errors.append(f"{node['id']}: référence ingrédient/pièce non résolue")
for door in data["doors"]:
    if door["room"] not in rooms or door["target"] not in rooms:
        errors.append(f"{door['id']}: porte non résolue")
for station in data["stations"]:
    if station["room"] not in rooms:
        errors.append(f"{station['id']}: pièce non résolue")
for recipe in data["recipes"]:
    for ingredient in recipe["ingredients"]:
        if ingredient not in ingredients:
            errors.append(f"{recipe['id']}: ingrédient inconnu {ingredient}")
assert not errors, "\n".join(errors)
print("Préflight : cellules remplies, identifiants uniques, références résolues.")
