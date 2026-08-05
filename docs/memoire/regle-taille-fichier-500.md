---
name: regle-taille-fichier-500
description: "Règle globale : fichiers Dart ≤ 500 lignes, découper par responsabilité"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: fbfd7c02-473f-415b-b6e1-a21454a8de92
---

RÈGLE GLOBALE (demandée par l'utilisateur, 2026-06-06) : un fichier Dart ne doit pas dépasser **500 lignes** (alerte à 400). Au-delà → **découper par responsabilité** (widgets dans `widgets/`, providers dans `providers/`, modèles dans `models/`), jamais au milieu d'un widget.

**Why:** lisibilité, maintenabilité, revue de code ; plusieurs écrans hérités sont énormes (super_admin annonces ~1900, messagerie ~1150, notifications 887) → dette.

**How to apply:** code neuf toujours conforme ; gros fichiers existants refondus **quand on les touche**. Concrètement, la factorisation du module communication (`features/communication/`) doit DÉCOUPER les écrans déplacés, pas les copier tels quels. Documenté dans `CLAUDE.md` racine (section « Conventions de code »). Lié : [[catalogue-modules-v2]].