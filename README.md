# Cosmo Wrap Ball

Jeu solo de gestion en 2D : restaurant spatial, wraps, boissons, clients extraterrestres, serre, exploration et wrapcoincoins.

## Windows

Télécharger [CosmoWrapBall.zip](https://github.com/keno681/essai/raw/refs/heads/master/downloads/CosmoWrapBall.zip), faire **Extraire tout**, puis ouvrir **JOUER.cmd**. Le moteur Godot est inclus ; conserver les dossiers `game` et `launcher` à côté de `Godot.exe`. Le jeu fonctionne sans connexion.

Déplacement : Q/D ou flèches ; espace : sauter ; E : interagir ; I : inventaire ; T : parler aux clients ; Échap : menu. Cliquer sur un objet permet de s'en approcher. Le canapé du bureau sert à sauvegarder et charger ; le PC commande les ingrédients.

## Console Pokéball

Cliquer sur la Pokéball dans le restaurant. La fenêtre en forme de Pokéball ouverte permet de coller les blocs de modification fournis dans notre conversation. Elle ne comprend pas elle-même les demandes en français : demander la modification ici, puis copier le bloc fourni.

**Vérifier le bloc** affiche les fichiers concernés sans les modifier. **Envoyer et relancer le jeu** sauvegarde la progression, ferme la partie, applique les changements, contrôle le code et redémarre le jeu avec le résultat dans la console. **Annuler la modification** restaure la dernière modification, puis relance.

Les anciennes connexions IA et l'atelier séparé sont supprimés. Aucune clé ni abonnement n'est nécessaire. Les sources restent dans `game`, donc les prochains changements ne nécessitent pas de télécharger à nouveau tout le jeu.

Les copies de sécurité sont dans `game/.console-backups`. Un bloc incorrect est refusé ; une erreur de code détectée rétablit les fichiers précédents. Un changement de script peut exécuter du code avec les droits du joueur : examiner les blocs avant de les envoyer. Les contrôles ne garantissent pas l'absence de bugs de gameplay.

### Format des modifications

```json
{"format":"cosmowrap-patch-v1","title":"Titre de la modification","files":[{"path":"ui.gd","old":"texte exact et unique existant","new":"texte de remplacement"}]}
```

Pour créer un fichier texte, utiliser `{"path":"nouveau.gd","create":"contenu complet"}`. Les chemins sont relatifs à `game`. Un simple message libre n'est pas un bloc de modification.

## Développement

Godot 4.6.3, rendu Compatibility. Ouvrir `project.godot` dans l'éditeur. Pour la console avec relance automatique, utiliser le lanceur du ZIP. Les anciennes sauvegardes de « Cosmo Wrap — Premier service » sont copiées au premier lancement si aucune nouvelle sauvegarde n'existe.

Vérifications : `python3 tests/preflight.py` ; `godot --headless --audio-driver Dummy --path . --script tests/console_test.gd`, ainsi que `game_test.gd`, `interaction_test.gd` et `offline_chat_test.gd` dans `tests`.
