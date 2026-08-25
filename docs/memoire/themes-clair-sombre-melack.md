---
name: themes-clair-sombre-melack
description: "Thèmes LIVRÉS (jetons runtime, préférence par agent) ; ⚠️ kNavy s'ÉCLAIRCIT en sombre (jeton de premier plan) ; super_admin avait sa propre palette"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3dd519ee-785a-464e-a27d-95c1a6fbc266
---

✅ **LIVRÉ 2026-07-17** (branche `feat/poste-vitrine-securite`, non poussé) — 3 thèmes
**Clair · Sombre · Melack** réellement fonctionnels. Avant : le sélecteur existait mais
ne changeait **pas un pixel** (2 appels à `Theme.of` sur 181k lignes ; l'UI peint ses
couleurs elle-même).

**Architecture** : les 11 jetons de `core/widgets/admin_ui.dart` (`kNavy`, `kSurface`…)
sont passés de `const Color` à **variables** pilotées par `applyPalette()` ;
`MaterialApp(key: ValueKey(themeId))` force le rebuild. Les 121 fichiers consommateurs
n'ont **pas changé** — ils écrivent toujours `kNavy`. `ThemeExtension` écarté : le coût
`const` (2210 issues) est intrinsèque au thème, pas au choix d'archi → à coût égal elle
ajoutait un diff de réécriture pure pour un gain (thème par sous-arbre) sans usage ici.

**Fichiers** : `core/theme/palette.dart` (données, 3 palettes) · `theme_prefs.dart`
(SharedPreferences par `profileId`) · `theme_provider.dart` (`themeIdProvider`, calqué
sur `deviceModeProvider`) · `AppTheme.from(palette)`. Sélecteur : en-tête + Paramètres
(staff & admin_groupe), `ThemePicker` partagé.

**Melack = APPARENCE seule** (noir carbone `#05080C`, neutres froids, vert phosphore
`#00E08A`), PAS un mode de sécurité : le thème est un choix personnel de l'agent, or un
agent ne doit pas pouvoir désactiver une protection en changeant de palette. Un vrai
mode sécurisé (masquage/filigrane) serait **imposé par la direction** → axe séparé.

**Le thème suit l'AGENT ACTIF** (pas l'appareil), local, zéro migration — cf.
[[poste-partage-agent-switch]]. Vérifié : persiste et se restaure au redémarrage.

## ⚠️ Pièges (chèrement appris)

- **`kNavy` s'ÉCLAIRCIT en thème sombre** (Sombre `#5B8FD4`, Melack `#3892CC`) — contre
  toute intuition. C'est un jeton à DOUBLE rôle : **432 usages texte/icône contre 282 en
  fond**. Foncé (`#1B2634`), contraste **1.13** → les titres de section devenaient
  INVISIBLES. Borné par le haut (blanc lisible dessus ≥3:1). Règle encodée dans
  `test/palette_test.dart` — ne pas la « corriger » sans lire la spec §11.4.
- **super_admin avait sa PROPRE palette** : 160 jetons locaux en dur dans 18 de ses 20
  fichiers (`const _kNavy = Color(0xFF1E3A5F);`), invisibles au levier `admin_ui`.
  Rebranchés en getters. Vérifier ce piège avant de croire qu'un espace « suit le thème ».
- **Un défaut de couleur ne se voit qu'à l'écran** : `analyze` 0 et tests verts pendant
  que des titres étaient invisibles. La vérification GUI dans les 3 thèmes est le seul
  critère d'arrêt.
- **`color:` ne dit rien** : trier sur le **constructeur englobant** (`BoxDecoration` =
  fond → `kCardBg` ; `TextStyle`/`Icon` = blanc sur bandeau coloré → LAISSER). Les
  ternaires (`color: sel ? x : Colors.white`) échappent aux motifs simples → 2 passes.
- **Un défaut Dart doit être `const`** même si le constructeur ne l'est pas : retirer
  `const` ne corrige PAS `non_constant_default_value` → paramètre nullable résolu dans
  la liste d'initialisation.
- **Jamais de `final` top-level sur un jeton** : figé au démarrage, bug muet invisible à
  l'analyse → **getter**.

**Outils réutilisables** : `epilote/tools/strip_const.py`, `fix_defaults.py`,
`fix_white_bg.py`, `relink_local_tokens.py` (l'analyseur sert d'oracle : boucler jusqu'à
`analyze == 0`).

**Dette laissée** : Clair `kTextMuted`/`kSurface` = 4.31 (< AA 4.5), **antérieure**, non
corrigée (la non-régression prime) ; exemption nommée dans le test. Avertissements
`ListTile … may be invisible` = antérieurs au chantier.

Spec : `docs/superpowers/specs/2026-07-16-themes-clair-sombre-melack-design.md` (§11 =
ce que la mise en œuvre a démenti). Voir [[regle-taille-fichier-500]], [[gui-testing-linux]].
