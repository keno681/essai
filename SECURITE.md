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

`downloads/CosmoWrapBall-Sources.zip` ne contient aucun `.exe`, `.dll`, `.msi` ou `.pck`. Les cinq lanceurs `.cmd` sont lisibles. Au premier lancement, `INSTALLER-GODOT.cmd` télécharge la version officielle fixe ci-dessus par HTTPS, vérifie son SHA512, extrait l'archive avec `Expand-Archive`, puis vérifie le SHA256 du moteur. Seul le moteur standard est conservé dans `.godot-runtime`. Chaque lancement vérifie de nouveau son empreinte avant de l'exécuter.

Ces scripts ne demandent pas de droits administrateur, ne modifient ni Defender ni la politique d'exécution PowerShell et ne restaurent aucun fichier en quarantaine. Un échec crée `installation-bloquee.txt` et arrête les installations suivantes pour permettre le diagnostic. Ils ne contournent pas un blocage antivirus. Les empreintes confirment uniquement la provenance et l'intégrité, pas l'absence de malware. L'installation Windows n'a pas été exécutée depuis cet environnement Linux.

Les contrôles du nouveau pack vérifient sa liste de fichiers, son intégrité et le fonctionnement du projet. Ils ne remplacent pas une analyse antivirus. Le signalement initial reste ouvert tant que le chemin de l’élément affecté n’a pas été communiqué.
