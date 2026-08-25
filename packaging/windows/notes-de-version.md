Installateur Windows 10/11 (64 bits, build 17763 minimum).

Télécharger le fichier `.exe` ci-dessous et le double-cliquer.
Déploiement par lot : `/VERYSILENT /NORESTART`.

⚠️ **Cette version n'est pas signée.** Windows affichera un avertissement
SmartScreen au lancement : « Informations complémentaires » puis « Exécuter
quand même ». Acceptable pour une recette interne, à lever avant tout
déploiement en établissement.

**Empreinte SHA-256 de l'installateur**

    __EMPREINTE__

C'est elle que l'application vérifie avant d'installer une mise à jour. Elle
est aussi le seul moyen, sans signature, de prouver qu'un installateur reçu
par clé USB est bien celui qui a été publié :

    Get-FileHash fichier.exe -Algorithm SHA256

Le fichier `manifest.json` ci-dessous contient la ligne à publier dans la
table `app_releases` pour ouvrir la mise à jour au parc.

Procédure complète : `packaging/windows/INSTALL.md`
