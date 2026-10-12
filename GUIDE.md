# Cosmo Wrap Ball · Guide du jeu

Jeu de gestion en 2D, en solo ou en coop privée à deux : restaurant spatial, wraps et boissons à composer, clients extraterrestres, serre, exploration et wrapcoincoins. Ce dépôt contient les sources complètes et les images de la version aux graphismes harmonisés.

## Pack Windows — installation automatique du moteur

Télécharger [CosmoWrapBall-Sources.zip](https://github.com/keno681/essai/raw/refs/heads/master/downloads/CosmoWrapBall-Sources.zip). Le ZIP contient le jeu, les images et cinq lanceurs texte `.cmd`, **sans fichier `.exe`, `.dll` ou moteur inclus**.

1. Extraire le ZIP dans un nouveau dossier, sans reprendre les fichiers de l'ancien pack signalé.
2. Lancer **JOUER.cmd**. Au premier lancement, il télécharge Godot 4.6.3 Windows x64 depuis la publication officielle, vérifie le SHA512 de l'archive et le SHA256 de l'exécutable, puis démarre le jeu. Internet est nécessaire pour cette installation ; les lancements suivants ne nécessitent pas de téléchargement. Le mode solo reste hors ligne.

Le moteur est conservé dans `.godot-runtime` et son empreinte est vérifiée avant chaque lancement. En cas d'échec, le lanceur s'arrête et garde un diagnostic ; il ne retente pas automatiquement l'installation. Il ne modifie pas Defender, ne restaure aucune quarantaine et ne demande pas de droits administrateur. `OUVRIR-EDITEUR.cmd` ouvre les sources dans l'éditeur avec le même moteur vérifié. Aucune clé API n'est nécessaire. Les dossiers `game` et `launcher` doivent rester à côté du lanceur. La sauvegarde reste dans le même profil utilisateur que précédemment.

### Signalement antivirus toujours à identifier

L'ancien ZIP contenant `Godot.exe` a été retiré après un signalement Wacatac. Ne pas utiliser les liens vers ses anciens commits, restaurer le fichier signalé ou ajouter une exclusion antivirus. Le moteur anciennement inclus correspond à l'archive officielle vérifiée, mais cela ne permet pas de conclure à un faux positif. Le fichier précisément détecté n'a pas encore été identifié : [détails de vérification](SECURITE.md).

Ce nouveau conditionnement évite la redistribution de l'exécutable ; **il ne constitue pas une certification antivirus**. Si Defender signale un fichier du nouveau pack ou le moteur téléchargé, ne pas le lancer et relever le chemin de l'élément affecté.

## Commandes et interactions

- Q/D ou flèches : marcher ; espace : sauter ; E : interagir.
- I : inventaire ; T : discuter avec les clients ; O : carnet des commandes ; Échap : menu.
- Cliquer sur une porte permet de rejoindre la pièce correspondante.
- Cliquer sur un bac ouvre un petit choix près du curseur : récolter, vider ou planter une variété découverte.
- Cliquer sur la cuisine ou le distributeur ouvre la préparation. Glisser les ingrédients de la table dans la galette ou le verre, puis fabriquer la commande. Un ingrédient déposé ne peut plus être retiré. JETER LA PRÉPARATION supprime toute la composition et consomme ses ingrédients. JETER LA COMMANDE PORTÉE (ou R) détruit la commande fabriquée sans remboursement. Une composition hors menu produit une commande improvisée, que les clients ne demandent jamais. Les recettes nommées restent soumises à leur progression.
- Cliquer sur le client à l’accueil ouvre le choix des 8 tables. Choisir une table libre prend sa commande ; il rejoint sa place et le prochain client avance. TABLES [O] affiche les commandes et leurs ingrédients. Cliquer sur une commande conduit au bon poste de cuisine ; Y ALLER conduit à la table. Passer par la porte SALLE et cliquer sur la table remet la préparation portée. Chaque chef porte une commande à la fois. Le client déguste pendant 6 secondes, puis repart et libère la table. Les arrivées, repas, départs et commandes sont sauvegardés et partagés en coop. Le chat de l’accueil reste accessible avec T.
- Le canapé du bureau sert à sauvegarder et charger ; le PC permet de commander uniquement des graines, par lots de 3. Une graine produit 3 ingrédients en une récolte, puis le bac devient vide. Vider un plant avant sa récolte ne rend pas la graine. Trois graines de chaque variété de départ sont offertes ; les plants déjà présents restent utilisables. Les semences sont conservées dans les sauvegardes et partagées en coop.

Les objets se mettent en surbrillance au passage du curseur. L'infobulle affiche leur nom. Le jeu démarre dans une fenêtre maximisée.

## Coop privée à deux

Dans le menu, choisir **COOP EN LIGNE · 2 JOUEURS**. L'hôte clique sur **HÉBERGER UN RESTAURANT**. Dans le menu de coop, il retrouve ses adresses IP locales et le mot de passe du salon. L'invité saisit l'IP de l'hôte et ce mot de passe, puis clique sur **REJOINDRE MON AMI**. Les deux joueurs doivent avoir cette mise à jour et les mêmes données du jeu. Aucun compte ni clé API n'est utilisé.

Sur le même réseau domestique, utiliser l'IP locale de l'hôte. Pour jouer depuis deux logements : utiliser son IP publique et rediriger le port **UDP 16383** de sa box vers le PC qui héberge. Autoriser l'application Godot dans le pare-feu pour le réseau concerné. Le jeu ne configure pas automatiquement la box ou le pare-feu. Si l'opérateur impose un CGNAT, il faut une IP publique accessible ou un VPN privé adapté ; une simple redirection de port peut ne pas suffire. Ne pas désactiver l'antivirus.

Le restaurant de l'hôte partage les stocks, les wrapcoincoins, les clients et leur file, les plantations, les découvertes et les livraisons. Chaque joueur contrôle son personnage, change de pièce librement et porte sa propre commande. Le bouton **DONNER MA COMMANDE AU COÉQUIPIER**, dans le menu de coop, transmet une commande si les deux chefs sont proches, dans la même pièce, et que le destinataire a les mains libres. Les menus ne mettent pas la simulation commune en pause.

L'hôte valide les achats, récoltes, recettes et ventes : deux joueurs ne peuvent pas récolter deux fois la même plante prête ou dépenser les mêmes stocks. Il conserve la progression du restaurant. L'invité retrouve sa partie solo en quittant la session ; sa sauvegarde personnelle n'est pas remplacée. Les ingrédients de sa commande portée sont rendus aux stocks de l'hôte lors d'une déconnexion normale. Une sauvegarde conserve aussi cette commande pour restituer ses ingrédients si elle est rechargée sans l'invité. Une coupure brutale du PC peut perdre les changements qui n'ont pas été sauvegardés.

Quitter la coop avant de charger une ancienne partie ou de recommencer un service. La fermeture du salon renvoie l'invité au mode solo. Cette version utilise une connexion directe : elle ne propose pas de serveur public, de matchmaking ou de connexion automatique par code.

Pour installer la synchronisation sur une version précédente compatible avec le port 16383, quitter la coop puis appliquer [Synchronisation-Coop-Pokeball.json](downloads/Synchronisation-Coop-Pokeball.json) sur **les deux PC**. Rejoindre ensuite le même salon. L'hôte peut appliquer [Ingredients-Boissons-Pokeball.json](downloads/Ingredients-Boissons-Pokeball.json) une seule fois : le partenaire reçoit le même bloc, les deux jeux se relancent et se reconnectent automatiquement. Le ZIP actuel inclut déjà les deux mises à jour.

Les modifications envoyées par la Pokéball de l'hôte se synchronisent si l'option correspondante est cochée dans le menu coop. Les fichiers concernés doivent être identiques avant la modification. Chaque PC vérifie le bloc dans une copie temporaire avant application. La progression et les commandes portées sont conservées ; si une application échoue, les deux PC tentent de restaurer la version précédente. Les modifications externes aux fichiers ne sont pas surveillées. Seuls les fichiers texte et SVG passent par ce système : les PNG et les sons demandent une distribution séparée. Les scripts de coordination (`coop_updates.gd`, `online_coop.gd`, `console.gd`, `patch_engine.gd`) doivent être mis à jour hors coop, sur les deux PC.

Les boissons utilisent de l’eau minérale, des feuilles de thé lunaire, des baies nébuleuses et du citron astral. Le distributeur fournit l’eau ; les autres ingrédients se cultivent à partir de graines. Le thé utilise eau et feuilles ; le soda utilise eau, baies et citron. Les tables de préparation affichent uniquement les ingrédients de leur catégorie. Les anciennes livraisons de variétés cultivables deviennent des livraisons de graines.

Les tests automatisés sous Linux utilisent deux vrais lanceurs et vérifient la transmission du bloc, la relance, la reconnexion, les stocks, les commandes portées et le retour arrière après un échec. Cette relance coordonnée reste à essayer sur deux PC Windows.

Une mauvaise commande peut être remise au client : wrap ou boisson incorrect, il part furieux sans payer. La commande est consommée, et le client suivant arrive après son départ.

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
godot --headless --audio-driver Dummy --path . --script tests/customer_queue_test.gd
godot --headless --audio-driver Dummy --path . --script tests/online_coop_test.gd
godot --headless --audio-driver Dummy --path . --script tests/drink_ingredients_test.gd
godot --headless --audio-driver Dummy --path . --script tests/seeds_test.gd
godot --headless --audio-driver Dummy --path . --script tests/tables_test.gd
godot --headless --audio-driver Dummy --path . --script tests/tables_online_test.gd
python3 tests/run_coop_sync.py
```

Le contrôle graphique nécessite un affichage : `godot --audio-driver Dummy --path . --script tests/visual_test.gd`. Il vérifie les bacs, les stocks, les recettes, la sauvegarde et le glisser-déposer, puis écrit des captures dans `user://captures`. Utiliser un profil de test séparé : ces tests modifient la progression et les réglages du profil courant.

Pour reproduire le pack Windows sans embarquer de moteur :

```sh
python3 tools/package_windows.py
```

Le nouveau pack distribue uniquement les sources, les images, les sons et les lanceurs texte. Une empreinte SHA256 du ZIP est publiée à côté de celui-ci. Le lancement et les contrôles ont été vérifiés avec Godot sous Linux ; l'installation automatique et le démarrage sous Windows restent à vérifier sur un PC Windows.

La mise à jour [Cuisine-Definitive-Pokeball.json](downloads/Cuisine-Definitive-Pokeball.json) modifie aussi le protocole de coop : quitter le salon et l’appliquer séparément sur les deux PC. Les recettes improvisées ont des identifiants déterministes communs aux deux joueurs.

La mise à jour [Tables-Commandes-Pokeball.json](downloads/Tables-Commandes-Pokeball.json) doit être appliquée hors coop, séparément sur les deux PC, car elle ajoute une salle et des actions réseau. Les anciennes sauvegardes démarrent avec une salle vide. Le carnet accepte plusieurs commandes, dont des boissons ; l’accueil attend lorsqu’il n’y a plus de place.

### Tickets de cuisine et comptoir

Les post-it de la cuisine indiquent le numéro de table, la recette, les ingrédients et l’état. Clique sur un ticket, compose le wrap ou la boisson, puis choisis **PRÉPARER ET POSER AU COMPTOIR** pour libérer tes mains et passer à la commande suivante. Le comptoir garde jusqu’à 12 préparations étiquetées. Clique dessus pour récupérer une commande, puis sur sa table dans la salle pour la servir. Tu distribues les préparations une à une. Le stock du comptoir est sauvegardé et partagé en coop.

Cette mise à jour passe au protocole coop 5 : applique `Tickets-Comptoir-Pokeball.json` hors ligne sur les deux PC avant de rejoindre le même salon.

Les bacs se récoltent directement au clic : une plante mûre donne 3 ingrédients et laisse un bac vide. Une plante en croissance affiche le temps restant ; clique sur un bac vide pour choisir une graine. Aucun menu Vider/Récolter ne s’ouvre.

### Table de travail : récoltes brutes et ingrédients préparés

La récolte fournit désormais des ingrédients bruts : 3 par plante cultivée, 2 par récolte sauvage. La cuisine et le poste de boissons ouvrent une seule fenêtre : **traitement des récoltes à gauche**, **composition à droite**. Glisse un ingrédient sur la planche, puis le bon ustensile dessus, puis le résultat dans le saladier. Chaque geste est instantané : aucun compte à rebours. Une unité brute devient une unité préparée, utilisable dans les recettes.

- Couteau : salade, tomate, champignon et piment.
- Presse-agrumes : citron et baies pour les boissons.
- Passoire : riz et feuilles de thé à nettoyer.

L’eau est prête à l’emploi. Les stocks déjà possédés dans les anciennes sauvegardes restent préparés ; les nouvelles récoltes sont brutes. Les stocks sont sauvegardés et partagés en coop, avec protection contre les traitements simultanés du dernier ingrédient. Les gestes en cours ne consomment rien tant que le résultat n’est pas déposé dans le saladier.

Applique `Table-Travail-Pokeball.json` hors ligne sur les deux PC : cette version utilise le protocole coop 6.

Une poubelle métallique est placée à gauche du comptoir dans le restaurant. Clique dessus : ton personnage s’approche et jette directement la commande portée, wrap ou boisson, sans menu et sans remboursement. E à proximité fonctionne aussi. Pour installer `Poubelle-Pokeball.json`, applique le correctif hors ligne sur les deux PC : le retour réseau est ajusté pour ne pas rouvrir la cuisine après avoir jeté une commande.

Les huit récoltes restent visibles à gauche, même avec zéro ingrédient préparé ou avant leur découverte. Chaque case indique le stock brut et le stock prêt. Les quantités et les ingrédients utilisables dans la composition se mettent à jour immédiatement après le dépôt dans le saladier, sans fermer la fenêtre.

### Jour 1 et tutoriel débutant

Une nouvelle partie commence au **jour 1 avec exactement cinq clients**, qui commandent des wraps à base des plantes de départ. Au premier clic sur JOUER, le guide explique l’accueil, les tables, la récolte, les graines, le traitement, la cuisine, le comptoir, le service et la sauvegarde. La prochaine étape de la première commande s’affiche en bas. Le menu permet de relire le tutoriel ou de désactiver le guide.

Le HUD indique le jour et le nombre de clients traités. Après les cinq accueils, les arrivées s’arrêtent ; une mauvaise commande ou un client renvoyé compte aussi parmi les cinq voyageurs. Le bilan s’ouvre lorsque toutes les commandes sont traitées et les clients partis. Le bouton JOUR SUIVANT conserve stocks, graines, argent et améliorations. Le jour 2 accueille huit clients ; les jours suivants augmentent progressivement jusqu’à douze.

Jour, compteurs et guide sont sauvegardés et synchronisés en coop. Les anciennes parties déjà avancées sont conservées et passent au jour 2 ; **NOUVEAU SERVICE** démarre une nouvelle partie au jour 1. Applique `Jour-1-Tutoriel-Pokeball.json` hors ligne sur les deux PC avant de reconnecter : protocole coop 7.

### Cuisine plus ludique

Pose une récolte brute sur la table, sélectionne le bon outil, puis clique une fois sur l’aliment pour le transformer. Le résultat rejoint le stock préparé et devient utilisable dans la composition. Clique ou glisse ensuite les ingrédients prêts dans le wrap ou le verre. Les ingrédients de la commande sont encadrés, le compteur indique la progression et les ingrédients ajoutés sont marqués en vert. Aucun délai artificiel, aucune clé API ; stocks et protection contre les traitements concurrents restent partagés en coop.

Le plan de préparation montre BRUT/RÉCOLTÉ à gauche et PRÉPARÉ/RECETTE à droite. La tomate récoltée est entière ; celle du wrap est en rondelles. La salade préparée est coupée et le citron pressé devient du jus. Le couteau, le presse-agrumes ou la passoire doit être sélectionné avant de cliquer sur l’aliment. Les mouvements de souris seuls ne transforment rien.
