<div align="center">

# COSMO WRAP BALL

### Un petit restaurant. Une grande galaxie. Des clients affamés.

Prépare tes wraps, invente tes boissons et fais grandir ton restaurant spatial.<br>
Seul ou avec un ami, sers des extraterrestres qui ont du caractère.

**GESTION 2D** · **SOLO & COOP À 2** · **WINDOWS** · **SANS CLÉ API**

[**⬇ Télécharger le jeu pour Windows**](https://github.com/keno681/essai/raw/refs/heads/master/downloads/CosmoWrapBall-Sources.zip) &nbsp; · &nbsp; [**📖 Guide du jeu**](GUIDE.md) &nbsp; · &nbsp; [**🛠 Signaler un problème**](https://github.com/keno681/essai/issues)

<img src="art/restaurant.png" alt="Illustration du restaurant spatial Cosmo Wrap Ball : cuisine chaleureuse, plantes et planète derrière les fenêtres" width="100%">

*Bienvenue dans ta cantine au milieu des étoiles.*

</div>

---

## À la carte

| 🌯 Cuisiner | 🥤 Préparer des boissons | 👽 Accueillir les clients |
| :--- | :--- | :--- |
| Glisse les ingrédients dans ta galette, compose une recette et sers ta commande. Les ingrédients déposés sont définitifs ; la poubelle permet de recommencer. | Eau minérale, thé lunaire, baies nébuleuses et citron astral : chaque boisson a ses ingrédients. | Accueille chaque client, choisis une table et gère jusqu’à 8 commandes grâce au carnet TABLES [O]. |
| **🌱 Cultiver** | **🪐 Explorer** | **🦆 Développer le restaurant** |
| Achète tes graines au PC : une graine donne 3 ingrédients, puis le bac devient vide. | Pars sur la planète pour trouver de nouveaux ingrédients et débloquer des recettes. | Gagne des wrapcoincoins, commande tes graines au PC et sauvegarde depuis le canapé. |

Une mauvaise commande servie à une table fait partir le client furieux, sans payer. Une bonne commande est dégustée, puis la table se libère. Tu peux gérer plusieurs clients et choisir l’ordre du service ; chaque chef porte une préparation à la fois.

## Un service à plusieurs tables

1. Clique sur le client à l’accueil et choisis une table libre.
2. Ouvre **TABLES [O]**, puis choisis la commande à préparer : ses ingrédients restent affichés en cuisine.
3. Fabrique le wrap ou la boisson, entre dans la **SALLE**, puis clique sur la bonne table pour servir.

Les clients rejoignent leur table, dégustent et repartent. Les commandes et l’occupation des tables sont sauvegardées et partagées en coop.

## Un univers à découvrir

Les décors mêlent bois, métal, lumière chaude et vues sur l’espace. Ces images présentent les décors du jeu ; l’interface et les personnages s’ajoutent pendant la partie.

| La serre | La planète |
| :---: | :---: |
| ![Décor de la serre spatiale](art/greenhouse.png) | ![Décor de la planète à explorer](art/planet.png) |

## Prêt pour ton premier service ?

1. [**Télécharge le ZIP Windows**](https://github.com/keno681/essai/raw/refs/heads/master/downloads/CosmoWrapBall-Sources.zip).
2. Fais clic droit sur le ZIP → **Extraire tout**.
3. Ouvre **JOUER.cmd** dans le dossier extrait.

Au premier lancement, le lanceur télécharge **Godot 4.6.3** depuis sa publication officielle et vérifie ses empreintes. Internet est nécessaire pour cette installation. Ensuite, tu peux jouer en solo hors ligne, sans compte ni clé API.

Le ZIP contient les sources et les ressources, sans moteur exécutable embarqué. Les dossiers **game** et **launcher** doivent rester à côté de **JOUER.cmd**. [Installation et informations de sécurité →](GUIDE.md#pack-windows--installation-automatique-du-moteur)

## Deux chefs, un même restaurant

Dans le menu, ouvre **COOP EN LIGNE · 2 JOUEURS** : l’un héberge, l’autre rejoint avec son adresse IP et le mot de passe du salon.

Vous partagez les stocks, les clients, les plantations, les découvertes et les wrapcoincoins. Chacun contrôle son personnage et peut cuisiner, servir ou explorer. Vous pouvez même vous passer une commande lorsque vous êtes proches.

**À la maison :** utilise l’IP locale du PC hôte. **Depuis deux logements :** la connexion directe utilise le port **UDP 16383** et demande une configuration réseau adaptée. [Configurer la coop →](GUIDE.md#coop-privée-à-deux)

## La Pokéball, pour faire évoluer ton jeu

Clique sur la Pokéball, colle un bloc de modification fourni dans notre conversation, puis choisis **Envoyer et relancer le jeu**.

En coop, les blocs envoyés par l’hôte peuvent être appliqués sur les deux PC, puis les jeux se relancent et se reconnectent. Le système vérifie les modifications et conserve des copies de sécurité. Il applique les blocs de code ; il ne comprend pas directement les demandes en français.

| Mise à jour pour les anciennes installations | Bloc à copier |
| :--- | :--- |
| Installer la synchronisation, hors coop, sur **les deux PC** | [Synchronisation Coop](https://raw.githubusercontent.com/keno681/essai/master/downloads/Synchronisation-Coop-Pokeball.json) |
| Séparer les ingrédients des wraps et des boissons, après installation de la synchronisation | [Ingrédients Boissons](https://raw.githubusercontent.com/keno681/essai/master/downloads/Ingredients-Boissons-Pokeball.json) |
| Planter avec des graines, récolter 3 ingrédients et acheter uniquement des semences au PC | [Système de graines](https://raw.githubusercontent.com/keno681/essai/master/downloads/Graines-Pokeball.json) |
| Salle de 8 tables et carnet de commandes ; appliquer hors coop sur les deux PC | [Tables et commandes](https://raw.githubusercontent.com/keno681/essai/master/downloads/Tables-Commandes-Pokeball.json) |

**Le ZIP actuel inclut déjà ces mises à jour.** La synchronisation porte sur les fichiers texte et SVG ; les PNG et les sons nécessitent un transfert séparé. [Fonctionnement et limites →](GUIDE.md#console-pokéball)

<details>
<summary><strong>🎮 Les commandes en un coup d’œil</strong></summary>

| Commande | Action |
| :--- | :--- |
| **Q / D** ou **← / →** | Marcher |
| **Espace** | Sauter |
| **E** | Interagir |
| **I** | Inventaire |
| **T** | Discuter avec les clients |
| **Échap** | Menu |
| **Souris** | Choisir une porte, un bac ou une station ; glisser les ingrédients |

Les objets se mettent en surbrillance au survol et affichent leur nom.

</details>

<details>
<summary><strong>🛠 Sources, développement et vérifications</strong></summary>

Le dépôt contient les scripts Godot, les décors, les ressources et les tests. Pour travailler sur le jeu, ouvre **project.godot** avec **Godot 4.6.3**, en rendu **Compatibility**. Le lanceur du pack Windows permet la relance automatique par la Pokéball.

Les tests de gameplay et de coop ont été exécutés sous Linux, y compris la transmission des modifications, la relance et le retour arrière après échec. La relance coordonnée reste à essayer sur deux PC Windows.

[Instructions de développement →](GUIDE.md#développement-et-vérification) · [Empreinte du ZIP →](downloads/CosmoWrapBall-Sources.sha256) · [Vérification du moteur →](SECURITE.md)

</details>

---

<div align="center">

**COSMO WRAP BALL**<br>
*Des wraps, des étoiles et quelques clients difficiles.*

[Le jeu](https://github.com/keno681/essai/raw/refs/heads/master/downloads/CosmoWrapBall-Sources.zip) · [Le guide](GUIDE.md) · [Les sources](https://github.com/keno681/essai)

</div>

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
