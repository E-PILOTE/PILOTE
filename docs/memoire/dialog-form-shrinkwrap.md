---
name: dialog-form-shrinkwrap
description: "Convention UI — les dialogues-formulaires doivent s'ajuster à leur contenu (shrinkWrap), pas remplir toute la hauteur"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d4b7d011-2f3d-4ee1-8013-06ea3ffadd28
---

⚙️ **Un dialogue-formulaire doit s'AJUSTER à son contenu, jamais s'étirer sur toute la hauteur de l'écran.**

Le motif fautif (récurrent dans le projet) : `Dialog` → `Column(mainAxisSize: MainAxisSize.min)` → `Flexible(child: ListView(... children: [...]))` **sans `shrinkWrap: true`**. La `ListView` est gourmande et remplit toute la hauteur disponible → modal pleine page avec un grand vide sous les champs.

**Correctif** : ajouter `shrinkWrap: true` à la `ListView` (elle prend la hauteur de son contenu et ne défile QUE si ça dépasse l'écran). Alternative équivalente : `Flexible(child: SingleChildScrollView(child: Column(mainAxisSize: min, ...)))` — déjà utilisé par `_ProjectFormDialog` (admin_regional_view).

**Ne PAS toucher** les `ListView`/`Expanded` qui doivent légitimement remplir (fils de discussion messagerie/tickets, panneaux latéraux) — là, le remplissage est voulu.

✅ 2026-06-29 (commit ac7b7ac) : corrigé sur 9 dialogues — Nouvelle évaluation (notes_form), EDT (emploi_du_temps_form/extraform, edt_calendar_tab, edt_availability_tab), Cahier de textes (form + parts), Annuaire (annuaire_form), Documents (documents_detail). Signalé par le user (« le modal ne devrait pas prendre toute la longueur de la page »). Appliquer systématiquement à tout nouveau dialogue-formulaire. Voir [[flutter-tech-notes]].
