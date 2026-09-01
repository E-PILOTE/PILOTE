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

> **Où en est le certificat ?** Voir `docs/CERTIFICAT_SIGNATURE.md`.
> ⚠️ Un certificat émis aujourd'hui n'est plus exportable en `.pfx` (exigence
> matérielle du CA/Browser Forum depuis juin 2023), et **EV** est nécessaire
> pour que l'avertissement disparaisse *immédiatement* — un **OV** laisse
> Windows construire sa réputation, donc l'avertissement persiste pendant les
> premières vagues de déploiement.

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
E-PILOTE-<version>-installateur.exe /VERYSILENT /NORESTART /SUPPRESSMSGBOXES
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

### La mise à jour automatique existe (corrigé le 2026-08-29)

Ce paragraphe annonçait le contraire. **C'était faux**, et c'était le document
que lit celui qui déploie.

Le poste interroge la RPC `derniere_version` **une fois par session**, compare
le `build_number` publié dans `app_releases` à celui du binaire, et affiche une
bannière discrète. L'agent accepte, l'application **télécharge**, **vérifie
l'empreinte SHA-256 avant tout lancement**, puis lance l'installateur — ce qui
ferme l'application, d'où l'avertissement préalable.

Hors ligne, la requête échoue en silence et rien ne s'affiche : c'est voulu.

⚠️ **Ce qui n'est PAS automatique, et qu'il ne faut pas confondre :**

| | |
|---|---|
| détection, téléchargement, vérification | automatiques |
| déclenchement de l'installation | **l'agent doit accepter** |
| publication d'une version au parc | **manuelle** — tag `v*`, puis une ligne dans `app_releases` |

Une version construite et même publiée sur GitHub **n'atteint aucune école**
tant que la ligne `app_releases` n'est pas écrite : c'est elle, et elle seule,
que le poste interroge.

⚠️ **`is_mandatory` / `min_build` ne bloquent pas l'application.** Ils rendent
la bannière rouge et non refermable. Un poste peut donc continuer à travailler
sur une version ancienne indéfiniment — c'est délibéré (un secrétariat en
pleine rentrée doit pouvoir finir sa saisie), mais cela veut dire qu'aucune
migration ne peut *supposer* que le parc a suivi.

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
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DAppVersion=<version> packaging\windows\epilote.iss
```

Le résultat sort dans `dist\`. La `<version>` est celle de `epilote/pubspec.yaml`,
**sans** le `+build` — Inno Setup refuse le `+`. C'est ce que fait la CI
(`.github/workflows/windows.yml`), et il n'y a pas d'autre source : `Runner.rc`
tire lui aussi son `FILEVERSION` de `pubspec.yaml`.

> Installé par winget, Inno Setup atterrit dans
> `%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe` et non sous `Program Files`.

> ⚠️ **Les notes de version, à la main, sous Windows PowerShell 5.1.** La CI
> tourne en `pwsh` 7, où `Get-Content` lit l'UTF-8 par défaut. `powershell.exe`
> (5.1) lit en ANSI : substituer l'empreinte dans `notes-de-version.md` puis
> réécrire en UTF-8 double-encode tous les accents (« Télécharger » →
> « TÃ©lÃ©charger »), et la publication part avec des notes illisibles. Passer
> par `[IO.File]::ReadAllText(chemin, [Text.Encoding]::UTF8)` plutôt que
> `Get-Content -Raw`. Rencontré le 2026-08-29.

⚠️ **Ne jamais reconstruire deux binaires différents sous le même `+build`.**
Le canal de mise à jour compare `build_number`, un entier, et lui seul : deux
livraisons partageant le même numéro sont indistinguables pour le parc, et la
seconde correction reste invisible sur les mille postes.

En temps normal, ce n'est pas nécessaire : l'intégration continue le fait à
chaque poussée, et c'est **elle** qui fait foi — la construction manuelle sur
un poste dépend de la version de Visual Studio qui s'y trouve.
