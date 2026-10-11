# Cosmo Wrap Ball

Jeu solo de gestion en 2D : restaurant spatial, wraps et boissons à composer, clients extraterrestres, serre, exploration et wrapcoincoins. Ce dépôt contient les sources complètes et les images de la version aux graphismes harmonisés.

## Pack Windows — installation automatique du moteur

Télécharger [CosmoWrapBall-Sources.zip](https://github.com/keno681/essai/raw/refs/heads/master/downloads/CosmoWrapBall-Sources.zip). Le ZIP contient le jeu, les images et cinq lanceurs texte `.cmd`, **sans fichier `.exe`, `.dll` ou moteur inclus**.

1. Extraire le ZIP dans un nouveau dossier, sans reprendre les fichiers de l'ancien pack signalé.
2. Lancer **JOUER.cmd**. Au premier lancement, il télécharge Godot 4.6.3 Windows x64 depuis la publication officielle, vérifie le SHA512 de l'archive et le SHA256 de l'exécutable, puis démarre le jeu. Internet est nécessaire pour cette installation ; les lancements suivants restent hors ligne.

Le moteur est conservé dans `.godot-runtime` et son empreinte est vérifiée avant chaque lancement. En cas d'échec, le lanceur s'arrête et garde un diagnostic ; il ne retente pas automatiquement l'installation. Il ne modifie pas Defender, ne restaure aucune quarantaine et ne demande pas de droits administrateur. `OUVRIR-EDITEUR.cmd` ouvre les sources dans l'éditeur avec le même moteur vérifié. Aucune clé API n'est nécessaire. Les dossiers `game` et `launcher` doivent rester à côté du lanceur. La sauvegarde reste dans le même profil utilisateur que précédemment.

### Signalement antivirus toujours à identifier

L'ancien ZIP contenant `Godot.exe` a été retiré après un signalement Wacatac. Ne pas utiliser les liens vers ses anciens commits, restaurer le fichier signalé ou ajouter une exclusion antivirus. Le moteur anciennement inclus correspond à l'archive officielle vérifiée, mais cela ne permet pas de conclure à un faux positif. Le fichier précisément détecté n'a pas encore été identifié : [détails de vérification](SECURITE.md).

Ce nouveau conditionnement évite la redistribution de l'exécutable ; **il ne constitue pas une certification antivirus**. Si Defender signale un fichier du nouveau pack ou le moteur téléchargé, ne pas le lancer et relever le chemin de l'élément affecté.

## Commandes et interactions

- Q/D ou flèches : marcher ; espace : sauter ; E : interagir.
- I : inventaire ; T : discuter avec les clients ; Échap : menu.
- Cliquer sur une porte permet de rejoindre la pièce correspondante.
- Cliquer sur un bac ouvre un petit choix près du curseur : récolter, vider ou planter une variété découverte.
- Cliquer sur la cuisine ou le distributeur ouvre la préparation. Glisser les ingrédients de la table dans la galette ou le verre, puis fabriquer la commande. Ramener un ingrédient sur la table permet de le retirer.
- Cliquer sur le client lui remet la commande préparée ; le chat reste accessible avec T et le bouton du HUD. Trois clients attendent derrière lui, avec des apparences aléatoires. Ils avancent dans l’ordre après son départ ; la file est conservée dans les sauvegardes.
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

Pour reproduire le pack Windows sans embarquer de moteur :

```sh
python3 tools/package_windows.py
```

Le nouveau pack distribue uniquement les sources, les images, les sons et les lanceurs texte. Une empreinte SHA256 du ZIP est publiée à côté de celui-ci. Le lancement et les contrôles ont été vérifiés avec Godot sous Linux ; l'installation automatique et le démarrage sous Windows restent à vérifier sur un PC Windows.
