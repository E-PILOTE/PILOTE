---
name: chaine-livraison-windows
description: "La chaîne de livraison Windows — CI GitHub Actions, installateur Inno Setup, les trois pièges natifs, et pourquoi la publication ne passe plus par un artefact"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-25T10:00:00.000Z
---

# Chaîne de livraison Windows (créée le 2026-08-03)

**Constat de départ** : à deux mois du déploiement national, `epilote/windows/`
était le squelette brut de `flutter create`, inchangé depuis le 26 mai, `git log`
vide sur ce chemin. Aucun binaire Windows n'avait **jamais** été produit ni
lancé. Le seul script d'empaquetage visait Linux, qui n'est pas une cible.

## Ce qui existe maintenant

| Quoi | Où |
|---|---|
| CI (analyse+tests Linux · tests+build+installateur Windows) | `.github/workflows/windows.yml` |
| Identité du binaire (`E-PILOTE.exe`, éditeur, version, FR) | `epilote/windows/runner/Runner.rc` + `main.cpp` |
| Icône `.ico` multi-résolution (16→256) | régénérée par `packaging/render-icons.sh` |
| Installateur | `packaging/windows/epilote.iss` (Inno Setup) |
| Procédure de déploiement | `packaging/windows/INSTALL.md` |

Publication automatique sur une release GitHub à chaque étiquette `v*`.
Poids réel : **108 Mo** (212 Ko d'exe + 76,5 Mo de DLL + 32 Mo de ressources).

⚠️ **Inno Setup et PAS MSIX** : un MSIX refuse de s'installer sans certificat
de confiance. Tant que le certificat n'est pas obtenu, MSIX ne produit rien
d'installable. L'`AppId` du script est **figé** — le changer laisserait deux
E-PILOTE sur chaque poste du pays.

⚠️ `CompanyName` = `E-PILOTE CONGO` doit être **identique** au sujet du futur
certificat, sinon Windows affiche « éditeur inconnu » malgré la signature.

## Les trois pièges natifs, découverts par la CI

1. **`audioplayers` < 6.8.1 ne compile plus.** Son greffon Windows incluait
   `<experimental/coroutine>`, transformé en **erreur dure** par MSVC 14.51
   (Visual Studio 18, 2026). Corrigé en amont par `audioplayers_windows` 4.4.1.
   Exige en retour la politique CMake **CMP0091** → plancher `cmake_minimum_required(VERSION 3.15)`
   dans `windows/CMakeLists.txt`. Ne jamais redescendre.

2. **Windows interdit neuf caractères dans un nom de fichier** (Linux, un seul).
   → `lib/core/utils/safe_file_name.dart`, appliqué là où de la donnée saisie
   entre dans un nom d'export. Les autres exports passent par un `_slug`.

3. **`getApplicationDocumentsDirectory()` est un piège sous Windows** → voir
   [[base-hors-ligne-hors-documents]].

## ⚠️ Le quatrième piège : la livraison passait par le quota d'artefacts (2026-08-25)

**Une version entièrement verte est restée bloquée des heures.** Tests Linux et
Windows, compilation, démarrage réel du binaire, installateur, empreinte : tout
passait. Seul `actions/upload-artifact` échouait —
*« Artifact storage quota has been hit. Usage is recalculated every 6-12 hours. »*
Or l'artefact était le SEUL transport entre le travail Windows et le travail de
publication : plus d'artefact, plus de version.

**La cause : le pipeline remplissait son propre quota.** Chaque poussée sur
`feat/**` téléversait l'installateur (~34 Mo) **et** le dossier de compilation
entier (~46 Mo), gardés 30 jours. À 500 Mo, six commits saturaient. Et vider les
artefacts ne débloque pas : le quota ne se recalcule que toutes les 6 à 12 h.

**Le remède structurel** : les pièces jointes d'une **publication** ne consomment
pas ce quota. Le travail Windows dépose donc l'installateur directement sur la
publication, en **BROUILLON** (invisible au parc, pièces non téléchargeables) ;
le travail `publication`, qui garde `needs: [verification, windows]`, se contente
de le **lever**. La barrière des tests est intacte — seul le transport change.
Les deux artefacts deviennent `continue-on-error` : ils ne servent plus qu'au
diagnostic d'une branche de travail.

⚠️ Le dépôt du brouillon **refuse de remplacer les pièces d'une version déjà
PUBLIÉE** : cela changerait sous les pieds des écoles l'installateur qu'elles
téléchargent, et l'empreinte publiée dans `app_releases` ne correspondrait plus.

Les notes de version vivent désormais dans `packaging/windows/notes-de-version.md`
avec un jeton `__EMPREINTE__` — de la prose relue comme du texte, et plus aucun
échappement de guillemets à traverser YAML puis PowerShell.

💡 **Pour savoir si le quota est libéré : une sonde de vingt secondes** (un travail
Linux qui téléverse un octet) plutôt qu'une reconstruction Windows de 18 minutes.
Le jeton `gh` n'a pas la portée `user` : l'API de facturation ne répond pas.

## ⚠️⚠️ Le cinquième piège : un dépôt PRIVÉ ne distribue rien (2026-08-25)

**v3.3.0 a été publiée, son empreinte revérifiée à la main — et elle répondait
`404` à la première personne qui a cliqué « Mettre à jour ».**

Les pièces jointes d'une release **privée** exigent une authentification GitHub.
L'application télécharge par un `http.Request('GET', url)` **anonyme** : elle ne
pouvait rien recevoir. `PILOTE` est privé et le restera.

### 🩸 La leçon, plus large que ce bug

**Tout contrôle fait depuis un poste authentifié ment.** J'avais retéléchargé
l'installateur et recalculé son SHA-256 — le contrôle passait, parce que `gh`
portait mon jeton. Il fallait demander l'URL **sans identifiants** pour voir le
défaut, et rien dans la chaîne ne le faisait. Un utilisateur l'a trouvé en un
clic.

### La forme retenue

Dépôt **public** de distribution : **`E-PILOTE/telechargements`** — installateurs
et empreintes, **aucun code source**. La bande passante des releases GitHub est
gratuite et servie par un CDN.

⚠️ **Supabase Storage est exclu** : plan **gratuit** (1 Go de stockage, 5 Go de
trafic/mois). 35 Mo × 1000 écoles = 35 Go **par version** — saturé avant la
centième école, en emportant le trafic de l'application avec lui.

⚠️ **Exige le secret `PUBLIC_RELEASE_TOKEN`** (jeton à portée fine, `Contents:
read and write` sur le dépôt de distribution) : `github.token` ne sort **jamais**
du dépôt courant. Sans ce secret, l'étape `Brouillon de publication` lève, avec
le mode d'emploi dans le message.

### Le garde : « Recette — télécharger comme une école, sans identifiants »

Dernière étape de `publication`. `curl --netrc-file /dev/null`, sans le moindre
en-tête, puis SHA-256 des octets reçus comparé à celui du manifeste. **Vérifié
qu'il ÉCHOUE** quand on le pointe sur le dépôt privé — un garde qui ne se
déclenche jamais ne vaut rien.

Voir [[mise-a-jour-du-parc]].

## ⚠️⚠️ Le sixième piège : la CI ne tourne plus du tout (2026-08-31)

**Toutes les exécutions échouent en 3 à 5 secondes.** Ce n'est pas le code :

> *The job was not started because recent account payments have failed or your
> spending limit needs to be increased.*

`E-PILOTE/PILOTE` est **privé** : les minutes Actions sont facturées, et un
runner **Windows coûte le double**. Depuis le 2026-08-30 ~19h49, plus une seule
construction n'a démarré — et rien ne l'annonce : `gh run list` affiche
`failure`, comme un test cassé. Il faut ouvrir l'exécution pour voir que c'est
la facturation.

**Seul le titulaire du compte peut le débloquer** (Billing & plans). Aucun jeton
n'y change quoi que ce soit — et `gh` n'a pas la portée `user`, donc l'API de
facturation ne répond pas non plus.

### La conséquence, et le contournement retenu

`PUBLIC_RELEASE_TOKEN` n'existe toujours pas — mais il est devenu **secondaire** :
même posé, la CI ne démarrerait pas. La v3.4.1 a donc été **construite et publiée
à la main**, ce que la note ci-dessus déconseille (« la CI fait foi »). Compromis
assumé, pas un oubli : sans CI, il n'y a pas d'autre chemin.

⚠️ **Inno Setup est installé en profil UTILISATEUR** :
`%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe`. Chercher dans `Program Files`
conclut à tort qu'il est absent.

```bash
# 1. installateur — EN POWERSHELL, PAS EN GIT BASH (voir juste en dessous)
#    Set-Location C:\E-PILOTE
#    & "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" `
#        "/DAppVersion=3.4.2" `
#        "/DSourceDir=C:\E-PILOTE\epilote\build\windows\x64\runner\Release" `
#        "packaging\windows\epilote.iss"
#    -> dist/E-PILOTE-3.4.2-installateur.exe

# 2. notes + manifeste : EN PYTHON, PAS EN POWERSHELL (voir plus bas)

# 3. publication
gh release create v3.4.2 dist/E-PILOTE-3.4.2-installateur.exe dist/manifest.json \
   -R E-PILOTE/telechargements --draft --title "E-PILOTE CONGO v3.4.2" \
   --notes-file dist/notes.md
gh release edit v3.4.2 -R E-PILOTE/telechargements --draft=false --latest

# 4. LA RECETTE ANONYME — ne jamais sauter cette étape
curl -sL --netrc-file /dev/null -o /tmp/a.exe "<download_url>" && sha256sum /tmp/a.exe

# 5. ligne dans app_releases : c'est ELLE qui ouvre la mise à jour au parc
```

### ⚠️ Le piège qui a fait échouer l'empaquetage (2026-09-01)

**La commande `bash` ci-dessus, telle qu'elle était écrite ici, ne pouvait pas
fonctionner.** Git Bash (MSYS) convertit tout argument commençant par `/` en
chemin Windows : `/DAppVersion=3.4.2` devient `C:/Program Files/Git/DAppVersion=3.4.2`,
qu'ISCC lit comme un **second nom de script** :

    You may not specify more than one script filename.

Le message ne parle ni de conversion, ni de chemin — rien n'oriente vers la
cause, et le compilateur affiche d'abord sa bannière de copyright, ce qui donne
l'illusion qu'il a démarré. Les définitions passent donc **par PowerShell**, où
aucun argument n'est réécrit. (`MSYS_NO_PATHCONV=1` marcherait aussi, mais
autant n'avoir qu'une seule façon de faire.)

`gh` est authentifié en **E-PILOTE** avec `admin: true` sur `telechargements` :
la publication manuelle ne demande aucun nouveau jeton.

### ⚠️ `dist/*.exe` téléversait SIX installateurs (2026-09-01)

`dist/` n'est pas nettoyé entre deux versions : il porte tous les
installateurs depuis 3.1.7. Le glob de la commande documentée les aurait tous
attachés à la publication — dont `E-PILOTE-3.1.7-installateur.exe`, qu'une
école aurait pu télécharger depuis la page de la 3.4.2. **Nommer le fichier.**

### ✅ v3.4.2 (build 26) publiée à la main (2026-09-01)

Deuxième publication manuelle, la CI restant bloquée par la facturation.
Déroulé et mesures :

| étape | résultat |
|---|---|
| `flutter analyze` | 0 issue (451 s) |
| tests | 1 936 passés, 2 ignorés |
| binaire | `VersionInfo` = `3.4.2+26` — vérifié, le bump `pubspec` atteint bien le `.exe` |
| démarrage réel | vivant 30 s ; base ouverte ET écrite (l'extension SQLite native se charge) |
| installateur | 35 969 179 o, empreinte `c1f8baef…6476`, calculée en Python **et** par `Get-FileHash` |
| recette anonyme | HTTP 200, 35 969 179 o reçus, empreinte identique |
| `derniere_version()` | 3.4.2 / 26, vérifié **sous le rôle `authenticated`** |

⚠️ **Les quatre commits du 31/08 portaient tous `3.4.1+25`.** Reconstruire sans
bumper aurait produit deux binaires différents sous le même numéro : le parc
compare des entiers, il ne les aurait pas distingués — c'est l'accident de
`3.1.7+18` livré deux fois. **Bumper AVANT de construire**, pas après.

Les notes de version gagnent une section « ce qui change », concaténée après le
gabarit partagé avec la CI (`dist/nouveautes-<version>.md`) : le gabarit seul ne
dit rien à une école de ce qu'elle reçoit.

### ⚠️ Le piège qui a corrompu les notes du premier coup

`Get-Content -Raw` en **Windows PowerShell 5.1** lit un fichier UTF-8 comme de
l'**ANSI**. Combiné à `Set-Content -Encoding utf8`, le résultat est un **double
encodage** : « Procédure complète » devient « ProcÃ©dure complÃ¨te ». Douze
occurrences dans `dist/notes.md`, invisibles tant qu'on relit avec le même
PowerShell — qui affiche le mojibake **et** le reproduit.

La CI n'en souffrait pas : elle utilise `shell: pwsh` (PowerShell 7, UTF-8 par
défaut). **En local, générer notes et manifeste en Python.**

### v3.4.1 — ce qui a été vérifié avant d'ouvrir la mise à jour

| contrôle | résultat |
|---|---|
| 6 requêtes des écrans neufs contre PostgREST réel (clé anon) | **200** partout — imbrications et colonnes valides |
| téléchargement **sans identifiants** | HTTP **200**, 35 961 890 octets |
| empreinte reçue vs publiée | **identiques** (`ddaa73ae…`) |
| `derniere_version()` appelée en anonyme, comme un poste | rend bien **3.4.1 / build 25** |

⚠️ **Aucun œil humain n'a ouvert les écrans neufs.** 1 917 tests, 0 issue
`analyze`, compilation et installateur : tout passe, mais la recette visuelle
reste à faire.

## Ce qui reste

- **Certificat de signature** — 1 à 3 semaines de délai administratif, seul
  délai non maîtrisé. Sans lui, SmartScreen bloque chaque installation.
- **Mise à jour automatique** — inexistante. Mille postes souvent hors ligne :
  le premier correctif se diffuse aujourd'hui à la main.
- **Recette sur un vrai poste Windows** — la CI démarre le binaire et vérifie
  qu'il crée sa base, mais aucun œil humain n'a encore vu l'application tourner
  sous Windows.

**Why :** ce chantier n'était dans aucun plan ; il a fallu l'ouvrir en urgence
quand la date de déploiement est tombée. Les trois pièges ci-dessus étaient
tous invisibles depuis Linux.

**How to apply :** la CI fait foi, pas la construction locale — elle dépend de
la version de Visual Studio du poste. Toute dépendance native ajoutée doit être
vérifiée sur `windows-latest` avant d'être considérée comme acquise.

Liens : [[plateformes-cibles-windows-mac]] · [[base-hors-ligne-hors-documents]] ·
[[deploiement-national-octobre]] · [[desktop-packaging-deb]]
