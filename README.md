# Cosmo Wrap Ball

Jeu solo de gestion en 2D : restaurant spatial, wraps et boissons à composer, clients extraterrestres, serre, exploration et wrapcoincoins. Ce dépôt contient les sources complètes et les images de la version aux graphismes harmonisés.

## Jouer sous Windows

Télécharger [CosmoWrapBall.zip](https://github.com/keno681/essai/raw/refs/heads/master/downloads/CosmoWrapBall.zip), choisir **Extraire tout**, puis lancer **JOUER.cmd** dans le dossier extrait `CosmoWrapBall`.

Le ZIP complet contient un seul exécutable : **Godot.exe**, nécessaire pour lancer le jeu depuis ses sources et appliquer les changements de la Pokéball. Conserver les dossiers `game` et `launcher` à côté de ce fichier. Le jeu fonctionne hors ligne, sans clé API ni abonnement.

Pour mettre à jour une installation existante, fermer le jeu puis copier les dossiers `game` et `launcher` du ZIP dans l'ancien dossier `CosmoWrapBall`, en acceptant le remplacement des fichiers. Les sauvegardes se trouvent dans le profil utilisateur Windows et restent au même emplacement.

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

Le pack contient les ressources nécessaires au jeu, sans anciens exports, vidéos de démonstration, captures obsolètes ni caches d'import. Le lancement et les contrôles ont été vérifiés avec Godot sous Linux ; le démarrage sous Windows reste à vérifier sur un PC Windows.
