# Signalement Windows Defender

Le téléchargement de l’ancien pack Windows contenant le moteur a été suspendu après un signalement Wacatac. Le fichier affecté exact n’a pas encore été identifié. Ne pas lancer ou restaurer le fichier signalé, ni ajouter une exclusion antivirus. Les liens vers les anciens commits peuvent encore fonctionner : ne pas utiliser ces archives.

## Vérification de provenance

Le ZIP distribué contenait un seul exécutable : `CosmoWrapBall/Godot.exe` (172 409 864 octets). Une copie indépendante de l’[archive officielle Godot 4.6.3 Windows x64](https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_win64.exe.zip) a été téléchargée. Son SHA512 correspond à la valeur des [sommes officielles](https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/SHA512-SUMS.txt). L’exécutable extrait et celui qui était inclus ont le même SHA256 :

```text
ef90e929ba1a6a4322860285d97f40f4aa349c90329a91b0e8b55b8df0f4cb00
```

SHA512 de l’archive officielle :

```text
d44ea7ef5bab754cacd49d581b6062836b2eea12a82e1d183aebfad9cd8c7db2bd82513337bd657d6d2d5c04d46239c0570b029faf1343e81e8a2fa7b85dd83b
```

Cette égalité établit la provenance du moteur ; elle ne prouve pas l’absence de malware dans tous les fichiers ni un faux positif de Defender. Les tests de fonctionnement du jeu ne sont pas des contrôles antivirus. La prochaine étape est de relever le chemin et le nom complet de la détection dans l’historique de protection Windows.

## Nouveau pack sans moteur embarqué

`downloads/CosmoWrapBall-Sources.zip` ne contient aucun `.exe`, `.dll`, `.msi` ou `.pck`. Le moteur doit être téléchargé séparément depuis le site officiel. Les trois lanceurs `.cmd` sont des fichiers texte lisibles ; ils recherchent un Godot standard Windows x64 placé par l’utilisateur à côté d’eux, puis le lancent avec les dossiers du jeu. Ils ne téléchargent aucun fichier, ne demandent pas de droits administrateur et ne modifient pas Defender.

Les contrôles du nouveau pack vérifient sa liste de fichiers, son intégrité et le fonctionnement du projet. Ils ne remplacent pas une analyse antivirus. Le signalement initial reste ouvert tant que le chemin de l’élément affecté n’a pas été communiqué.
