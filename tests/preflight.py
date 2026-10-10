import json
from pathlib import Path

data = json.loads((Path(__file__).parents[1] / "data/design.json").read_text())
required = {
    "ingredients": {"id", "name", "color", "x", "regrow_seconds"},
    "recipes": {"id", "name", "ingredients", "price", "joke"},
    "customers": {"id", "name", "color", "line"},
    "stations": {"id", "name", "x", "action"},
    "systems": {"id"},
    "visuals": {"id", "asset", "width", "height"},
    "animations": {"id"},
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
for visual in data["visuals"]:
    if not (Path(__file__).parents[1] / visual["asset"]).is_file():
        errors.append(f"{visual['id']}: illustration manquante")
for recipe in data["recipes"]:
    for ingredient in recipe["ingredients"]:
        if ingredient not in ingredients:
            errors.append(f"{recipe['id']}: ingrédient inconnu {ingredient}")
assert not errors, "\n".join(errors)
print("Préflight : cellules remplies, identifiants uniques, références résolues.")
