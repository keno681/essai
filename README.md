# Cosmo Wrap Ball

Jeu solo de gestion en 2D : restaurant spatial, wraps et boissons à composer, clients extraterrestres, serre, exploration et wrapcoincoins. Ce dépôt contient les sources complètes et les images de la version aux graphismes harmonisés.

## Alerte Windows Defender — téléchargement suspendu

Un utilisateur a signalé une détection Wacatac dans le pack Windows. Le ZIP contenant l'exécutable a été retiré de la version courante du dépôt en attendant la vérification. Ne pas lancer, restaurer ou exclure de l'antivirus le fichier signalé. Les anciens liens vers un commit peuvent encore être accessibles : ne pas les utiliser.

Les sources et les images du jeu restent disponibles. Aucune conclusion sur un éventuel faux positif n'est établie à ce stade. Le fichier précisément détecté doit encore être identifié.

Pour un environnement de développement, obtenir Godot uniquement depuis son site officiel https://godotengine.org/download/windows/ et respecter les alertes de sécurité du système. Aucun moteur Windows n'est actuellement redistribué ici.

## Commandes et interactions

- Q/D ou flèches : marcher ; espace : sauter ; E : interagir.
- I : inventaire ; T : discuter avec les clients ; Échap : menu.
- Cliquer sur une porte permet de rejoindre la pièce correspondante.
- Cliquer sur un bac ouvre un petit choix près du curseur : récolter, vider ou planter une variété découverte.
- Cliquer sur la cuisine ou le distributeur ouvre la préparation. Glisser les ingrédients de la table dans la galette ou le verre, puis fabriquer la commande. Ramener un ingrédient sur la table permet de le retirer.
- Cliquer sur le client lui remet la commande préparée ; le chat reste accessible avec T et le bouton du HUD.
- Le canapé du bureau sert à sauvegarder et charger ; le PC permet de commander les ingrédients.

Les objets se mettent en surbrillance au passage du curseur. L'infobulle affiche leur nom. Le jeu démarre dans une fenêtre maximisée.

## Graphismes

Les ingrédients, plantes, accessoires, portes, boissons, distributeur, wraps, monnaie et console utilisent des images détaillées assorties au décor : métal patiné, bois, lumière chaude et reflets. Les plantes sont séparées des fonds du restaurant et de la serre : un bac vidé devient réellement vide, et une plante repousse progressivement. Les fonds, personnages et nouveaux éléments se trouvent dans `art/` ; `visual_library.gd` définit les régions des planches d'images.

## Console Pokéball

Cliquer sur la Pokéball dans le restaurant, coller un bloc fourni dans notre conversation, puis choisir **Envoyer et relancer le jeu**. Le bouton **Fermer** revient à la partie. La console applique les blocs de modification ; elle ne comprend pas elle-même les demandes en français.

Le lanceur sauvegarde la progression, ferme la partie, applique les changements, importe les ressources, vérifie les scripts et redémarre le jeu. Un changement invalide restaure les fichiers précédents. Les copies de sécurité sont conservées dans `game/.console-backups`.

```json
{"format":"cosmowrap-patch-v1","title":"Titre","files":[{"path":"ui.gd","old":"texte exact et unique","new":"texte de remplacement"}]}
```

Pour créer un fichier texte : `{"path":"nouveau.gd","create":"contenu complet"}`. Les chemins sont relatifs au dossier `game` du pack Windows. Les nouvelles images PNG nécessitent une mise à jour des ressources. Les blocs peuvent modifier du code exécuté sur le PC : examiner leur contenu avant de les appliquer.

## Développement et vérification

Godot **4.6.3**, rendu **Compatibility**. Ouvrir `project.godot` dans l'éditeur ou lancer `godot --path .`. Le pack Windows et son lanceur sont nécessaires pour essayer la relance automatique par la Pokéball.

```sh
python3 tests/preflight.py
godot --headless --audio-driver Dummy --path . --editor --quit
godot --headless --audio-driver Dummy --path . --script tests/game_test.gd
godot --headless --audio-driver Dummy --path . --script tests/interaction_test.gd
godot --headless --audio-driver Dummy --path . --script tests/offline_chat_test.gd
godot --headless --audio-driver Dummy --path . --script tests/console_test.gd
```

Le contrôle graphique nécessite un affichage : `godot --audio-driver Dummy --path . --script tests/visual_test.gd`. Il vérifie les bacs, les stocks, les recettes, la sauvegarde et le glisser-déposer, puis écrit des captures dans `user://captures`. Utiliser un profil de test séparé : ces tests modifient la progression et les réglages du profil courant.

Pour reproduire le pack Windows avec le moteur officiel et ses licences :

```sh
python3 tools/package_windows.py --runtime /chemin/Godot.exe --license-dir /chemin/licences
```

La génération du pack Windows est conservée comme outil de développement, mais sa redistribution est suspendue après le signalement antivirus. Le lancement et les contrôles ont été vérifiés avec Godot sous Linux ; le démarrage sous Windows reste à vérifier sur un PC Windows.
