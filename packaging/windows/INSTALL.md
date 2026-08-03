# E-PILOTE CONGO — Déploiement Windows

Windows 10/11 est la **plateforme de déploiement** du produit. Linux ne sert
qu'au développement ; le paquet `.deb` décrit dans `packaging/INSTALL.md` n'a
pas vocation à être installé dans un établissement.

---

## 1. Ce qu'on distribue

Un **fichier unique** : `E-PILOTE-<version>-installateur.exe`.

Il est produit par l'intégration continue à chaque poussée
(`.github/workflows/windows.yml`), et récupérable dans les artefacts du build,
sous le nom `E-PILOTE-installateur-<sha>`.

> Le dossier `Release` brut — 108 Mo, vingt-six DLL — n'est **pas** un moyen de
> distribution. Il manque à l'agent le raccourci, la désinstallation, et la
> certitude d'avoir tout copié au bon endroit.

Prérequis du poste : **Windows 10 version 1809 (build 17763) ou ultérieur**,
64 bits. C'est le plancher de Flutter pour le bureau Windows, pas un choix.

---

## 2. Installation sur un poste

Double-cliquer sur l'installateur, puis suivre l'assistant — il est en
français, et ne pose que deux questions : le dossier d'installation et le
raccourci sur le Bureau.

### ⚠️ L'avertissement SmartScreen

Tant que **le certificat de signature de code n'est pas obtenu**, Windows
affichera au lancement :

> **Windows a protégé votre ordinateur**
> Microsoft Defender SmartScreen a empêché le démarrage d'une application non
> reconnue.

Il faut cliquer sur **« Informations complémentaires »** puis **« Exécuter
quand même »**. C'est acceptable pour une recette interne ; **ce ne l'est pas
pour un déploiement national** — un agent d'établissement à qui l'on demande
de passer outre un avertissement de sécurité, soit renonce, soit prend
l'habitude de le faire, ce qui est pire.

Obtenir le certificat est donc un préalable au déploiement, pas un
perfectionnement. Le nom d'éditeur qu'il portera devra être **identique** au
`CompanyName` inscrit dans le binaire (`E-PILOTE CONGO`, défini dans
`epilote/windows/runner/Runner.rc`) — un écart entre les deux ferait apparaître
« éditeur inconnu » malgré la signature.

L'installation se fait **pour tous les utilisateurs** du poste et demande donc
les droits d'administrateur. C'est délibéré : l'application est pensée pour le
poste partagé d'un établissement, où secrétariat, surveillance et direction se
succèdent sur la même machine.

---

## 3. Installation silencieuse (déploiement par lot)

Pour un service informatique déployant sur plusieurs postes :

```bat
E-PILOTE-3.1.7-installateur.exe /VERYSILENT /NORESTART /SUPPRESSMSGBOXES
```

Options utiles :

| Option | Effet |
|---|---|
| `/VERYSILENT` | Aucune fenêtre, aucune question |
| `/SILENT` | Barre de progression seule |
| `/NORESTART` | N'redémarre jamais le poste |
| `/DIR="C:\E-PILOTE"` | Impose le dossier d'installation |
| `/TASKS="desktopicon"` | Force le raccourci Bureau |
| `/LOG="C:\install.log"` | Journalise l'installation |

En mode silencieux, l'application **n'est pas lancée** à la fin.

---

## 4. Mise à jour

Réinstaller par-dessus, avec le nouvel installateur. L'`AppId` étant figé,
Windows reconnaît l'installation existante et la remplace — il n'y a pas deux
E-PILOTE sur le poste, et le raccourci reste le même.

> ⚠️ **Il n'existe pas encore de mise à jour automatique.** Sur mille écoles
> souvent hors ligne, la diffusion d'un correctif est aujourd'hui manuelle.
> C'est une lacune connue du déploiement, pas un oubli : voir la tâche
> « Fabriquer l'installeur Windows et la mise à jour ».

---

## 5. Désinstallation

Paramètres ▸ Applications ▸ Applications installées ▸ **E-PILOTE CONGO** ▸
Désinstaller.

**Ce qui est supprimé** : le programme et ses bibliothèques, dans
`C:\Program Files\E-PILOTE`.

**Ce qui est conservé** : la base locale PowerSync et le coffre de licence,
qui vivent dans le profil de l'utilisateur. C'est volontaire et c'est
important — une désinstallation ne doit jamais emporter du travail hors ligne
que la synchronisation n'a pas encore remonté.

---

## 6. Construire l'installateur à la main

Sur une machine Windows disposant de Flutter et d'Inno Setup 6 :

```bat
cd epilote
flutter build windows --release
cd ..
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DAppVersion=3.1.7 packaging\windows\epilote.iss
```

Le résultat sort dans `dist\`.

En temps normal, ce n'est pas nécessaire : l'intégration continue le fait à
chaque poussée, et c'est **elle** qui fait foi — la construction manuelle sur
un poste dépend de la version de Visual Studio qui s'y trouve.
