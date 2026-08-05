---
name: dashboard-direction-uxui
description: "Refonte UX/UI du Tableau de bord espace école (Directeur/Proviseur) — glass card, lanceur header, recouvrement bar, bloc Personnel, finance year-scope — livré+GUI-vérifié 2026-07-04"
metadata: 
  node_type: memory
  type: project
  originSessionId: 012e8fef-2c27-4d9d-a848-ba9c0832077f
---

✅ **2026-07-04 (branche `refonte/sidebar-shell`, non commité, analyze 0 / hot-reload 0 erreur / GUI-vérifié live en Directeur « Aline M. » Collège Public de Kinkala)** — Passe UX/UI approfondie du **Tableau de bord espace école** (`lib/features/user/screens/user_dashboard_screen.dart` + `dashboard_*_parts.dart` + `dashboard_provider.dart`).

**Livré & vérifié à l'écran :**
1. **Card identité (`_SchoolBanner`) → glassmorphism** : Stateless→Stateful, verre navy translucide (gradient alpha) + **aurora lumineuse animée** (`_AuroraPainter` : 3 halos vert/bleu/violet flous `MaskFilter.blur`, dérive lente 9 s) + bord lumineux + ombres colorées périphériques. Volontairement **discret** (gouvernement) — peut être intensifié si demandé. `import 'dart:math'`.
2. **Recouvrement : donut → barre de taux** (`_RecouvrementBar` dans dashboard_block_parts) : « X % » en grand + barre segmentée animée vert=encaissé / ambre=attente + légende + « … encaissés sur … attendus ». Meilleure pratique dataviz (part/tout avec cible = barre, pas cercle).
3. **« Accès rapide » sorti du corps → lanceur dans le top header** (`_ModuleLauncher` dans `core/widgets/app_shell/app_header.dart`, pattern app-switcher Notion/Linear) : `MenuAnchor` + icône `grid_view_rounded` à droite du toggle thème, **gaté `isStaff`** (jamais super_admin/admin_groupe). Popover largeur clampée responsive, grille de tuiles verticales groupées par catégorie, filtré `can_read`. `_QuickModulesGrid`/`_ModuleChip` supprimés du dashboard (+ imports module_routes/module_model retirés). ⚠️ piège corrigé : `Opacity` d'anim doit être `.clamp(0,1)` (assertion sinon).
4. **Bloc Personnel direction** (`_PersonnelBlock` + `staffSummaryProvider`) : total/enseignants/en-activité sur `profiles WHERE role NOT IN (eleve,parent)`. Nouveau `_Section.personnel` **gaté `perms['personnel']?.canRead`** + ajouté à `_sectionSlugs`/`_roleTiebreak` (toutes les listes doivent contenir les 5 sections). **Règle rappelée par le user** : ces KPI/contenus apparaissent/se réordonnent selon les responsabilités que l'admin groupe attribue (accès = permissions, ordre = charge — cf [[dashboard-persona-ordering]]).
5. **Fix données finance year-scope** : `paymentsSummaryProvider` était non scopé année (incohérent avec Dépenses). `student_payments` n'a pas `academic_year_id` → **JOIN `class_enrollments` via `enrollment_id`** + filtre année active. Vérifié : Encaissé inchangé (7,8 M) = aucun paiement perdu. Paiement sans enrollment_id = non imputable à une année (exclu, volontaire).
6. **Robustesse/a11y** : `_KpiGrid`/`_StatGrid` `childAspectRatio`→`GridView.builder`+`mainAxisExtent:172` (convention KPI, anti-overflow) ; résumé sémantique lecteur d'écran sur les 2 graphes.

**Affinage transparence (2026-07-04, itération 2)** : sur retour user (« faire disparaître ce bleu sans totalement, effet transparent magnifique ») → **verre fumé** : base navy alpha 0.55→0.40 (au lieu de 0.93/0.82) + voile bas dense pour le contraste + aurora renforcée (4 halos, alpha ↑) + **ombre de texte** `_kBannerTextShadow` (lisibilité blanc sur verre). PAS encore vu GUI (user sur admin_groupe) — réglage d'alpha si à retoucher.

Aussi : bug écran-verrou corrigé au passage — `Scrollbar.thumbVisibility` sans `ScrollController` dans `agent_grid.dart` (assertion en boucle) → `ScrollController` partagé.
