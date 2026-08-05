---
name: sidebar-personnel-est-defilante
description: "⚠️ NE PAS 'RÉPARER' : la sidebar personnel n'affiche que ~13 modules à l'écran parce qu'elle DÉFILE — les autres sont sous la ligne de flottaison"
metadata: 
  node_type: memory
  type: reference
  originSessionId: db933423-7daf-438d-9460-97e0abf9b86b
  modified: 2026-08-04T00:14:46.381Z
---

# La sidebar du personnel défile (constat 2026-08-03, à ne pas re-chercher)

Sur un poste 1500×1300, un proviseur ne voit que **~13 des 30 modules** que
son plan et son profil lui accordent. Bulletins, Conseils, Discipline,
Finance, RH, Personnel semblent absents.

**Ce n'est PAS un bug.** Dans `core/widgets/app_shell/app_sidebar.dart` :
- `pinnedTop` → hors défilement, en haut ;
- les sections de modules → `Expanded > ListView` = **défilant** ;
- `pinned` (COMMUNICATION, SYSTÈME) → hors défilement, en bas.

COMMUNICATION apparaît donc juste sous le dernier module visible, ce qui donne
l'illusion d'une liste tronquée.

## Vérifications déjà faites (ne pas refaire)

| Verrou | État |
|---|---|
| `modules` serveur | 30, toutes `is_active = true` |
| `plan_modules` (plan Institutionnel) | 30 |
| `profile_permissions` du profil Direction | 30, `can_read` partout |
| Base locale PowerSync | 30 modules, 8 catégories, 30 permissions |
| Requête exacte de `modulesGroupedByCategoryProvider` en local | 30 sur 8 catégories |

⚠️ Ici `is_active = 1` fonctionne (typeof = integer en local) — ce n'est PAS
un cas de [[powersync-is-active-egalite-stricte]], contrairement à l'intuition.

Liens : [[modules-acces-hierarchie]] · [[sidebar-modules-empty-cause]] ·
[[gui-testing-linux]]
