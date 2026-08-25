---
name: scolarite-transferts-documents-annuaire
description: Pages Transferts/Documents/Annuaire livrées + panneau drill-down partagé ScopeDrilldownPanel ; catégorie Scolarité complète
metadata: 
  node_type: memory
  type: project
  originSessionId: 1094ad61-3536-4f38-a312-7a097ec9bbfb
---

✅ 2026-06-26 — Catégorie **Scolarité** complétée (commits `877b01b`, `7339a65`, `4962a84`).

**Transferts** (`/user/transferts`, `transferts_provider.dart`) — registre des départs ; cycle de vie pending→approved/rejected→completed ; à l'approbation l'inscription bascule `transferred`. Destination en **cascade groupe→école** (`transfer_destination_picker.dart`, offline-aware : propre groupe + écoles sœurs synchronisées, repli « hors plateforme » texte libre) ; `createTransfer` porte `to_school_id`. Câblé form Transferts ET drawer Élève (réconciliation).

**Documents** (`/user/documents`, `documents_provider.dart`) — conformité des dossiers sur `student_documents`. Pièces EXIGÉES `kRequiredDocTypes` = {acte_naissance, photo_identite, certificat_medical}. Vue « Par élève » (checklist + détail avec upload Storage/vérif/consultation URL signée/retrait, gardé permissions) + vue « Registre ». KPIs Pièces déposées/Vérifiées/Dossiers complets/Expirées.

**Annuaire** (`/user/annuaire`, `annuaire_provider.dart`) — répertoire familles sur `student_tutors` (joints `students` via school_id). `FamilyRow` = élève actif + tuteurs. KPIs Familles/Avec contact/Sans contact/Tuteurs(+urgence). Détail famille = tuteurs (tel: cliquable, e-mail, métier, adresse, badges Principal/Urgence) + CRUD (`addTutor`/`updateTutor`/`deleteTutor`) gardé permissions. Bascule « Sans contact », table/cartes, export PDF.

**🔑 Panneau répartition PARTAGÉ** `lib/features/students/widgets/scope_drilldown_panel.dart` (`ScopeDrilldownPanel`) — extrait pour éviter la duplication (règle projet). **TABLEAU HIÉRARCHIQUE dépliable** (commit f8c94e8, refonte depuis l'ancien drill-down par barres) : lignes imbriquées **Cycle ▸ Niveau ▸ Classe**, sous-totaux EFFECTIF + métrique + % visibles à CHAQUE niveau + ligne TOTAL (pattern pivot/breakdown → tous les totaux d'un coup d'œil). Chevron = déplier/replier ; clic ligne = filtrer (composant **contrôlé** : props `selected: ScopeSel` + `onSelect`, le parent stocke le scope, filtre sa liste, affiche le bandeau actif). Colonne métrique paramétrable `metricLabel` (« Complets » Documents / « Avec contact » Annuaire). Entrée = `List<ScopeUnit>` (cycleCode/levelCode/levelOrder/classId/className + `ok`). Helpers cycle publics `scopeCycleColor/Name/Order`. Utilisé par Documents (ok=isComplete) ET Annuaire (ok=hasContact). Évolution UX pilotée par l'utilisateur : barres → tableau (meilleure lisibilité des totaux, choix validé via aperçus).

Reste catégories : Enseignement (Emploi du temps, Cahier de textes), Évaluation (Notes, Bulletins, Conseils), Vie scolaire, Finance, RH. Voir [[scolarite-pages-classes-matieres-eleves]].

⚠️ Friction test GUI : **piège GPU resize** — relancer l'app plante souvent (« Timed out waiting for OpenGL frame 2560x1368 / Lost connection to device »). Parade : après apparition de la fenêtre, `wmctrl -i -r $WID -b remove,maximized_vert,maximized_horz`. Voir [[gui-testing-linux]].
