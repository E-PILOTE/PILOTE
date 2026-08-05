---
name: chaine-livraison-windows
description: "La chaîne de livraison Windows — CI GitHub Actions, installateur Inno Setup, et les trois pièges natifs découverts en la construisant"
metadata: 
  node_type: memory
  type: project
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-03T08:24:01.412Z
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
