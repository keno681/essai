# Cosmo Wrap — Premier service

## Télécharger pour Windows

[Télécharger le jeu Windows 64 bits](https://github.com/keno681/essai/raw/refs/heads/master/downloads/CosmoWrap-Windows.zip)

Une fois le ZIP téléchargé, faire clic droit → **Extraire tout**, puis ouvrir
**CosmoWrap.exe** dans le dossier extrait. Garder `CosmoWrap.pck` à côté de
l'exécutable. Aucun moteur à installer séparément.

[Téléchargement léger de secours](https://github.com/keno681/essai/raw/refs/heads/master/downloads/CosmoWrap-Windows-Leger.zip)
contient `JOUER.cmd`, qui télécharge le moteur officiel au premier lancement
et vérifie son SHA-512 avant de le lancer. Cette alternative nécessite Internet.

L'archive Windows est contrôlée, mais le lancement sous Windows reste à tester.

Prototype original de jeu solo en 2D de côté, de gestion et d'humour.
Vous récoltez au jardin orbital, préparez trois recettes de wraps et servez
des clients extraterrestres patients. Trois commandes réussies terminent le
premier service ; vous pouvez continuer et ouvrir une terrasse pour 35 crédits.
La terrasse augmente chaque vente de 5 crédits. La progression du restaurant
est sauvegardée automatiquement ; l'inventaire est réinitialisé au lancement.

## Jouer

Ouvrir `project.godot` avec Godot 4.6.3 puis appuyer sur F6 ou F5, ou lancer :

```sh
godot --path .
```

Entrée commence la partie. Flèches ou Q/D (A/D aussi) déplacent le personnage ;
E récolte, cuisine ou sert selon votre position. Les touches 1, 2 et 3 choisissent
la recette. Espace saute, R range un wrap en restituant ses ingrédients,
Échap met en pause et N recommence la progression.

Le jardin est à gauche ; la cuisine, le comptoir et la terrasse sont à droite.
Les plantes repoussent en 8 à 12 secondes. Les clients ne s'impatientent jamais.

## Validation

```sh
python3 tests/preflight.py
godot --headless --path . --script tests/game_test.gd
godot --headless --path . --quit-after 120
```

Utiliser un `XDG_DATA_HOME` temporaire pour les tests sous Linux : les tests
écrivent une sauvegarde de restaurant. Les données de conception se trouvent
dans `data/design.json`. Vérifier leurs cellules et références avant chaque build.

## Périmètre et crédits

Le prototype utilise des dessins vectoriels et du code créés pour ce projet.
Il n'inclut ni fichiers, ni personnages, ni contenu de Starbound ou de Wrap House.
Il ne nécessite aucun de ces jeux et n'est donc pas destiné à Melty.
Il n'a pas encore de voyage entre planètes, de campagne, de son ou de multijoueur.
Le moteur est Godot (https://godotengine.org), sous licence MIT.
La licence de diffusion et les autorisations de remix du projet restent à choisir
pour accorder des droits de réutilisation. Le dépôt et les archives sont fournis
pour permettre le téléchargement du prototype ; aucune publication Melty
n'a été effectuée.
