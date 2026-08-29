---
name: photo-webcam-cadre-identite
description: "📷 Prise de photo à la webcam (2026-08-29) — ⚠️ RECADRER AVANT `compressAvatar`, sinon ~130 dpi au lieu de ~232 sur la carte ; `camera_windows` n'est PAS endossé par `camera`, il se déclare à part ; Linux n'a aucune implémentation"
metadata:
  node_type: memory
  type: project
---

# Prendre la photo à la webcam (2026-08-29)

La fiche n'acceptait qu'un **fichier**. L'élève est pourtant devant le bureau le
jour de l'inscription, et sa photo est « à apporter » — elle n'arrive jamais.
C'est la vraie cause des cartes qui sortent avec « PHOTO MANQUANTE » : pas un
défaut de la carte, un défaut du **moment** où on demande la photo.

Webcam ou fichier sur les trois fiches de personne : élève (`eleves_edit`),
guichet d'inscription (`inscriptions_edit`), agent (`agent_fiche_dialog`).

## ⚠️ Le recadrage doit précéder la compression

`compressAvatar` réduit à **256 px de plus long côté**. Tout ce qui reste hors
du cadre à ce moment-là a consommé une part de ces 256 px pour rien.

| chemin | résultat sur 22 mm de papier |
|---|---|
| capture 1280×720 → compressAvatar → 256×144 → PDF `cover` | 113 px → **~130 dpi** |
| capture 1280×720 → cadre 11:14 → 566×720 → compressAvatar → 201×256 | **~232 dpi** |

Même photo, même poids, presque le double de définition. À 130 dpi un visage
imprimé sur 22 mm est une tache ; à 232 dpi il identifie quelqu'un — le seul
travail que cette carte ait à faire.

`kPhotoIdentiteLargeurMm` / `kPhotoIdentiteHauteurMm` vivent dans
`core/utils/cadre_identite.dart` et servent **aux deux** : au recadrage et au
dessin de la carte (`carte_scolaire_dessin.dart`). Deux rapports qui divergent
rogneraient la photo deux fois, une fois de trop.

**L'aperçu porte le cadre**, assombri au dehors : l'opérateur voit ce qu'il
garde pendant qu'il cadre, au lieu de le découvrir sur la planche imprimée.

## ⚠️ Pièges du greffon

- **`camera_windows` n'est PAS endossé par `camera`.** Déclarer `camera` seul
  résout `camera_android`/`avfoundation`/`web` — et **rien sur Windows** :
  l'appel échoue au lancement, pas à la compilation. Les deux lignes sont
  nécessaires dans `pubspec.yaml`.
- **Linux n'a aucune implémentation.** `webcamPossible` fait disparaître le
  choix plutôt que d'ouvrir une erreur — un bouton qui échoue apprend à
  l'utilisateur à ne plus cliquer. Le poste de développement est un Linux ; les
  postes d'école sont sous Windows.
- **`enableAudio: false`** — sans cela Windows réclame aussi le micro, une
  autorisation de plus à refuser pour une photo qui n'a pas de son.
- La chaîne compile : `camera_windows_plugin.dll` est produit et
  `flutter build windows` sort à 0. Ce n'était pas acquis — le dépôt porte déjà
  un plancher de version imposé par MSVC 14.51 (`audioplayers ^6.8.1`).
- **Vérifié en LANÇANT le binaire** : l'application s'ouvre, s'authentifie et
  applique ses checkpoints PowerSync. C'est la seule chose que `flutter analyze`
  ne peut pas dire, et un greffon qui plante à l'enregistrement empêche
  l'application d'ouvrir **entièrement**.

## ⚠️ Demande une NOUVELLE construction

`camera` n'est pas dans le build **3.3.1** déjà produit. Voir
[[deploiement-national-octobre]].

Liens : [[carte-scolaire-module]] · [[deploiement-national-octobre]]
