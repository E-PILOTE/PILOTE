---
name: form-class-context-pattern
description: "Convention UI — sélection de classe dans les formulaires = contexte verrouillé (banner Cycle▸Niveau▸Classe) si ouvert depuis une classe, sinon menu structuré par niveau"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d4b7d011-2f3d-4ee1-8013-06ea3ffadd28
---

⚙️ **Sélection de classe dans les formulaires : « contexte verrouillé, pas redondance ».** Le user voulait « rajouter très souvent les sélections par cycle/niveau/classe pour la clarté ». J'ai tranché (il m'a dit de décider) avec la meilleure pratique ERP plutôt que d'ajouter une cascade partout :

- **Formulaire ouvert DEPUIS une classe** (la classe est déterminée par le contexte) → ne PAS redemander la classe (menu ou cascade = redondant + piège « créer pour la mauvaise classe »). L'AFFICHER en bandeau verrouillé avec le fil **Cycle ▸ Niveau ▸ Classe** via le widget partagé **`ClassContextBanner`** (`lib/core/widgets/class_context_banner.dart` : `className`, `cycleName`, `levelName`, `subtitle`, `icon` ; affiche le fil + puce 🔒 « Contexte »). Cycle name = `scopeCycleName(cycleCode)` (scope_drilldown_panel). Idem pour le trimestre si la page est scopée par trimestre.
- **Formulaire à choix LIBRE de classe** (ex. cahier de textes : un prof journalise pour n'importe quelle classe) → garder UN menu, mais **ordonné par `levelOrder` et préfixé du niveau** (« CP1 · CP1 A ») pour que la structure reste lisible. Pas de verrou.

**Why:** moins de clics, zéro ambiguïté, et on supprime les pièges (évaluation créée pour une autre classe que l'atelier ouvert → « disparaît »).

✅ 2026-06-29 (commit a43f82c) : `ClassContextBanner` créé + appliqué — **Nouvelle/Modifier évaluation** (notes_form : menu Classe + menu Trimestre SUPPRIMÉS, remplacés par le banner) et **Créneau EDT** (emploi_du_temps_form, déjà contextuel via `widget.classId`). **Cahier de textes** (choix libre) = menu Classe trié+préfixé niveau. Vérifié GUI réel (banner « Collège ▸ 6e ▸ 6ème A · Trimestre : 3e trimestre · 🔒 Contexte »).

À réutiliser pour tout nouveau formulaire portant une classe. Voir [[dialog-form-shrinkwrap]] et [[evaluation-notes-bulletins]].
