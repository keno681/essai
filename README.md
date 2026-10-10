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

## Mise à jour graphique

### Exploration, bureau et wrapcoincoins

L'interface utilise une console industrielle à bordures métalliques et accents
dorés, inspirée des interfaces de stratégie spatiale de StarCraft. La monnaie
est le **wrapcoincoin**, représenté par un petit canard dans le HUD.

Le snack garde ses trois plantes. La porte **SERRE** à gauche mène à six bacs
supplémentaires. À droite de la serre, la porte **PLANÈTE** ouvre une vallée
de 360 mètres à explorer. Récolter ses plantes avec E découvre le citron
astral, le piment comète et le riz de cristal. Ces découvertes débloquent
deux recettes, accessibles avec les touches 4 et 5, et les commandes au PC.

La porte **BUREAU** du snack, entre le jardin et la cuisine, mène à une pièce
séparée. Près du canapé, appuyer sur E pour **sauvegarder** ou **charger**.
La sauvegarde du canapé conserve l'inventaire, les découvertes, les livraisons,
les wrapcoincoins, le personnage et la progression. Elle reste distincte de
la reprise automatique à la fermeture du jeu. Près du PC, E ouvre le catalogue :
commander un lot de trois ingrédients coûte des wrapcoincoins et déclenche
une livraison après quatre secondes de jeu, une fois le PC fermé.

Les clients ont des répliques à l'arrivée et après leur commande, affichées
progressivement. Sous Windows, Godot utilise la synthèse vocale installée :
voix française si disponible, sinon une autre voix du système. Sans voix
installée, les sous-titres restent disponibles. **Options → Voix des clients**
active ou désactive les voix. Leur sortie audio Windows reste à confirmer ;
les dialogues et sous-titres ont été vérifiés sous Linux.

![Bureau, canapé et PC](art/office-gameplay.png)

![Six bacs supplémentaires](art/garden-gameplay.png)

![Exploration de la planète](art/planet-gameplay.png)

### HUD, inventaire et races

Interface de console spatiale : barre de raccourcis,
menu cliquable avec reprise, inventaire, personnage, options, nouveau service
avec confirmation et quitter. `I` ouvre l'inventaire avec quantités, icônes et
sélection des recettes ; `Échap` ouvre le menu. Les infobulles des recettes
montrent leurs ingrédients. Le menu et l'inventaire mettent la partie en pause.

Les options règlent le plein écran, les sons d'action, la luminosité du décor
et trois vitesses de déplacement. Elles sont conservées entre les lancements.

Sept races redessinées en HD sont proposées : Humain, Avien, Apex, Floran,
Hylotl, Glitch et Novakid. Choisir sa race dans **Menu → Personnage et races**.
Il s'agit d'illustrations générées pour ce fan-prototype et non des sprites
officiels extraits de Starbound. Les clients utilisent aussi ces races.
Ils entrent depuis la droite, marchent jusqu'au comptoir, attendent, puis
repartent avec leur wrap. Le client suivant arrive après leur sortie.

![Inventaire en fonctionnement](art/inventory.png)

![Options en fonctionnement](art/options.png)

[Vidéo de l'arrivée et du départ des clients](art/clients-demo.mp4)

Décor original illustré de snack orbital : broche à kebab, cuisine inox,
comptoir éclairé, serre et terrasse. Le cuisinier et les clients sont dessinés
en 2D avec membres articulés, marche, respiration et gestes d'interaction.
Le cuisinier tient réellement son wrap à la main. Le décor a été généré pour
ce projet ; aucun visuel de Wrap House Simulator ou Fallout Shelter n'est inclus.

![Capture du jeu en fonctionnement](art/gameplay.png)
Vous récoltez au jardin orbital et sur la planète, préparez cinq recettes de wraps et servez
des clients extraterrestres patients. Trois commandes réussies terminent le
premier service ; vous pouvez continuer et ouvrir une terrasse pour 35 wrapcoincoins.
La terrasse augmente chaque vente de 5 wrapcoincoins. La reprise automatique
et la sauvegarde du canapé conservent maintenant aussi l'inventaire.

## Jouer

Ouvrir `project.godot` avec Godot 4.6.3 puis appuyer sur F6 ou F5, ou lancer :

```sh
godot --path .
```

Entrée commence la partie. Flèches ou Q/D (A/D aussi) déplacent le personnage ;
E récolte, cuisine, sert, passe une porte ou utilise le canapé/PC selon votre position.
Les touches 1 à 5 choisissent
la recette. Espace saute, R range un wrap en restituant ses ingrédients,
I ouvre l'inventaire, Échap ouvre le menu et N demande confirmation avant
de recommencer la progression.

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

Le prototype utilise un décor généré, des dessins vectoriels et du code créés pour ce projet.
Il n'inclut aucun fichier extrait de Starbound ou de Wrap House.
Les races de Starbound sont représentées par des illustrations redessinées.
Il ne nécessite aucun de ces jeux et n'est donc pas destiné à Melty.
Il n'a pas encore de voyage entre plusieurs planètes, de campagne, de musique ou de multijoueur.
Le moteur est Godot (https://godotengine.org), sous licence MIT.
La licence de diffusion et les autorisations de remix du projet restent à choisir
pour accorder des droits de réutilisation. Le dépôt et les archives sont fournis
pour permettre le téléchargement du prototype ; aucune publication Melty
n'a été effectuée.

## Clients variés (v5)

Chaque visite tire une race et une commande parmi les recettes débloquées, sans répéter immédiatement la race précédente. Taille (90 à 113 %), proportions de tête, couleurs, vêtements, pantalon, chaussures, lunettes et chapeaux sont aléatoires. Fez, fedora, casquette, casque, bonnet ou tête nue ; tentacules facultatifs ondulants, bouclés ou en zigzag. Les accessoires accompagnent les animations et les apparences du client actuel et du prochain client sont sauvegardées. Les dessins de base restent ceux des sept races redessinées.

## Restaurant spatial (v6)

Accessoires avec textures ombrées de tissu, métal et verre, et boutons de HUD à contours lumineux. Une Poké Ball décorative est cachée dans le restaurant sans collision ni interaction.

La réputation progresse aux seuils 3, 8 et 15 clients servis, avec des bonus permanents de vente de 1, 3 puis 5 WCC. Le menu « Évolution du restaurant » affiche les étapes. Le thé lunaire (touche 6) se débloque à 3 clients ; le soda nébuleuse (7) à 8 clients après découverte de ses ingrédients. Sélectionner une boisson puis appuyer sur E devant la machine, à droite de la cuisine ; servir au comptoir comme les wraps.

T ou le bouton CHAT ouvre une conversation avec le client présent. Bonjour, commande, planète et merci reçoivent des réponses prédéfinies ; les autres messages reçoivent une réponse générique. Ce chat local fonctionne sans serveur ni IA en ligne. Son historique et la progression sont sauvegardés.

## Conversations IA optionnelles (v7)

Dans Menu → Options → IA / conversations clients, saisir une clé API OpenAI personnelle, activer les réponses IA et appliquer. La clé reste uniquement en mémoire pour la session : elle ne figure ni dans les archives, ni dans les sauvegardes, ni dans les options enregistrées. On peut effacer la clé et revenir au mode local à tout moment. Créer une clé sur https://platform.openai.com/api-keys ; la facturation API est séparée de l’abonnement ChatGPT. Ne jamais communiquer la clé dans le chat ou la committer.

T ouvre le chat lorsqu’un client attend. Le jeu appelle directement https://api.openai.com/v1/responses avec `gpt-4.1-mini`. Les messages du joueur et les huit derniers messages de la conversation du client courant sont transmis, avec sa race, sa personnalité, sa commande et le rang du restaurant. Les instructions demandent une réponse française de 40 mots maximum ; le budget technique est de 160 tokens de sortie. Une requête à la fois, sans relance automatique, avec un délai de 20 secondes. Les réponses ne modifient pas l’état du jeu. Le paramètre `store` est désactivé ; cela ne supprime pas nécessairement les journaux de service du fournisseur.

Sans clé, après un refus d’authentification, un quota dépassé ou une panne réseau, le jeu utilise ses dialogues prédéfinis et indique le mode local. Les requêtes en cours sont annulées lors d’un changement de client, de pièce, de chargement ou de nouveau service. L’historique IA courant est réinitialisé ; le journal visible reste dans la sauvegarde.

Validation supplémentaire : `python3 tests/ai_chat_test.py` démarre un faux serveur Responses sur localhost et teste le véritable transport HTTP du jeu, la réponse, les erreurs 401/429, une réponse malformée, le timeout, l’annulation et la non-persistance de la clé. Aucun appel OpenAI payant n’est exécuté par ces tests. Une clé et un accès réseau réels restent nécessaires pour vérifier le fournisseur en production.
