# Refonte Sidebar / AppShell + Dashboards — Design

Date : 2026-06-29 · Branche : `refonte/sidebar-shell`

## Objectif

Rendre la navigation (sidebar) et les dashboards « professionnels » sur 3 plans —
**architecture du code**, **apparence/UX**, **architecture de l'information** — sans
casser le comportement existant et **sans toucher au super_admin** (espace figé,
19 pages livrées).

## Problèmes identifiés (état actuel)

- `app_shell.dart` = **1421 lignes** : modèle de nav + données (super_admin +
  admin_groupe en dur) + nav dynamique personnel + sidebar + header + footer +
  helpers de rôle, tout dans un fichier. Viole la règle ≤500.
- Séparation « items principaux / SYSTÈME » par `sectionLabel.contains('SYSTÈME')`
  → magic-string fragile.
- Entrée « Modules du groupe » **injectée en mutant la liste pendant `build()`**.
- Item actif détecté par `startsWith()` → faux positifs (parent allumé sous enfant).
- Mode réduit : les sections deviennent de simples traits (perte de repère).
- Tokens couleur dupliqués (`_kNavy` local vs `kNavy` de `admin_ui`, valeurs
  identiques) → divergence latente.

## Livraison 1 — Sidebar / AppShell

### Architecture (façade préservée)

`lib/core/widgets/app_shell.dart` reste le **point d'entrée public** : il continue
d'exposer `AppShell`, `themeModeProvider`, `sidebarExpandedProvider`,
`contentOverlayProvider`, `showContentOverlay`, `closeContentOverlay`
(43 fichiers en dépendent → zéro import à changer).

Sous-fichiers extraits (dossier `app_shell/`) :

| Fichier | Responsabilité |
|---|---|
| `app_shell/nav_models.dart` | `NavSection` (avec flag **`pinned`**), `NavEntry`, variantes info/divider |
| `app_shell/nav_config.dart` | Définitions déclaratives super_admin + admin_groupe ; builder dynamique personnel ; entrée « Modules du groupe » (ref-aware, **plus dans build()**) |
| `app_shell/app_sidebar.dart` | Widget Sidebar (header + sections scrollables + sections épinglées + footer) |
| `app_shell/nav_tile.dart` | `NavTile` (item cliquable, badge, états) |
| `app_shell/sidebar_header.dart` | En-tête logo + bouton |
| `app_shell/sidebar_footer.dart` | Statut synchro + déconnexion |
| `app_shell/resize_handle.dart` | Poignée de redimensionnement |
| `app_shell/app_header.dart` | Barre du haut + menu compte + helpers rôle |

Tokens : consolidés sur ceux de `admin_ui.dart` (valeurs **identiques** → aucun
changement visuel).

### Corrections de comportement

1. **Épinglage bas** par flag `pinned: true` sur la section (fini le `.contains`).
2. **Item actif** = match du **préfixe le plus long** :
   `loc == route || loc.startsWith('$route/')`, on retient la route la plus longue.
3. **Injection modules** propre : « Modules du groupe » construit dans `nav_config`.

### Polish visuel / UX

États actif/hover affinés, animation de largeur, mode réduit lisible (icônes +
tooltips), footer cohérent, espacements homogènes. Accessibilité (Semantics,
tooltips) conservée.

### Architecture de l'information (admin_groupe + personnel uniquement)

- admin_groupe : « Modules du groupe » remis à une place logique (plus après
  SYSTÈME).
- personnel : ordre des sections cohérent (Dashboard → Établissement → modules →
  Communication → Système).

### super_admin — INTOUCHÉ

Sa liste de menus reste à l'identique ; même rendu partagé (amélioration, pas
régression). Vérifié visuellement.

## Livraison 2 — Dashboards (après validation L1)

- `admin_dashboard_screen.dart` (2919 l.) et `user_dashboard_screen.dart`
  découpés en sous-widgets ≤500 l. + polish cohérent.
- **super_dashboard exclu.**

## Garde-fous « sans rien casser »

À chaque étape : `flutter analyze` (0 issue) → `flutter build linux --debug` →
vérif GUI réelle des 3 espaces (super_admin / admin_groupe / personnel).
Aucun changement de schéma, aucune route modifiée, aucun déploiement.
