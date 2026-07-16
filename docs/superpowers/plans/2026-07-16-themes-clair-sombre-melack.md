# Thèmes Clair · Sombre · Melack — Plan d'implémentation

> **Pour l'agent exécutant :** spec = `docs/superpowers/specs/2026-07-16-themes-clair-sombre-melack-design.md`.

**But :** rendre les 3 thèmes réellement fonctionnels (aujourd'hui le sélecteur ne change pas un pixel).

**Architecture :** les 11 jetons de `admin_ui.dart` passent de `const Color` à variables pilotées par `applyPalette()`. Les 121 fichiers consommateurs ne changent pas. Rebuild global via `key: ValueKey(themeId)` sur `MaterialApp`.

**Stack :** Flutter, Riverpod, shared_preferences.

## Contraintes globales

- **Clair == valeurs actuelles au hex près.** Non-régression verrouillée par test.
- `flutter analyze` doit retomber à **0 issue** (oracle du codemod).
- Les 217 tests existants restent verts.
- Dette assumée : Clair `kTextMuted`/`kSurface` = 4.31:1 (< AA 4.5) — antérieure, non corrigée.
- Fichiers Dart ≤ 500 lignes.
- Ne JAMAIS toucher vitrine / login / écran-verrou (déjà sombres par conception).

---

### Task 1 : Palette (données)

**Fichiers :** Créer `lib/core/theme/palette.dart` · Test `test/palette_test.dart`

**Produit :** `enum EpiloteThemeId { clair, sombre, melack }` ; `class EpilotePalette` (11 champs `Color` : navyDeep, navyDark, navy, green, accent, red, surface, cardBg, textPrimary, textMuted, border) ; `EpilotePalette.of(EpiloteThemeId)` ; constantes `kPaletteClair` / `kPaletteSombre` / `kPaletteMelack`.

- [ ] **Step 1 : test qui échoue** — Clair == hex actuels ; les 3 ids résolvent ; contraste ≥ 4.5 pour Sombre + Melack (helper `contrastRatio`), exemption Clair nommée.
- [ ] **Step 2 :** `flutter test test/palette_test.dart` → FAIL (fichier absent).
- [ ] **Step 3 :** implémenter `palette.dart` avec les valeurs du §4 de la spec.
- [ ] **Step 4 :** `flutter test test/palette_test.dart` → PASS.
- [ ] **Step 5 :** commit.

---

### Task 2 : Jetons runtime + `applyPalette`

**Fichiers :** Modifier `lib/core/widgets/admin_ui.dart:4-14`

**Consomme :** `EpilotePalette`, `kPaletteClair`. **Produit :** `void applyPalette(EpilotePalette p)`.

- [ ] **Step 1 :** les 11 `const Color kX = …` → `Color kX = kPaletteClair.x;`
- [ ] **Step 2 :** ajouter `applyPalette(p)` qui réaffecte les 11.
- [ ] **Step 3 :** `flutter analyze` → attendu ≈2210 issues (Task 3 les résorbe). NE PAS commiter ici.

---

### Task 3 : Codemod `const` (l'oracle)

**Fichiers :** ~209 fichiers, sites désignés par l'analyseur.

- [ ] **Step 1 :** script `tools/strip_const.dart` : lit `flutter analyze --machine`, pour chaque `invalid_constant` / `const_with_non_constant_argument` / `non_constant_*` retire le `const` englobant (le plus proche à gauche sur la ligne, ou la déclaration).
- [ ] **Step 2 :** boucler script + `flutter analyze` jusqu'à **0 issue**.
- [ ] **Step 3 :** `dart fix --apply` (prefer_const_constructors résiduels) puis `flutter analyze` → 0.
- [ ] **Step 4 :** `flutter test` → 217 verts.
- [ ] **Step 5 :** commit SÉPARÉ (diff mécanique énorme, doit rester relisible).

---

### Task 4 : Les 76 déclarations top-level → getters

**Fichiers :** sites de `grep -rnE '^(const|final) .*(kNavy|kGreen|kRed|kAccent|kTextMuted|kSurface|kCardBg|kBorder|kTextPrimary)' lib/`

**Piège :** rendues `final`, elles s'initialisent UNE fois au démarrage → thème figé, bug muet invisible à l'analyse.

- [ ] **Step 1 :** pour chaque déclaration, `final _x = Deco(color: kCardBg)` → `Deco get _x => Deco(color: kCardBg)`.
- [ ] **Step 2 :** `flutter analyze` → 0 ; `flutter test` → verts.
- [ ] **Step 3 :** commit.

---

### Task 5 : Préférence par agent

**Fichiers :** Créer `lib/core/theme/theme_provider.dart` · Test `test/theme_provider_test.dart`

**Modèle :** `deviceModeProvider` (`active_agent_provider.dart:288-293`) — StateNotifier + SharedPreferences.

**Produit :** `themeIdProvider` (StateNotifierProvider<ThemeIdNotifier, EpiloteThemeId>) ; `ThemeIdNotifier.set(EpiloteThemeId)` persiste + appelle `applyPalette` ; clé `epilote_theme_<profileId>`.

- [ ] **Step 1 :** tests — défaut = clair sans préférence ; persistance par profileId ; 2 agents = 2 thèmes ; `set()` mute les jetons globaux.
- [ ] **Step 2 :** FAIL. **Step 3 :** implémenter. **Step 4 :** PASS. **Step 5 :** commit.

---

### Task 6 : Câblage `ThemeData` + rebuild global

**Fichiers :** Modifier `lib/core/theme/app_theme.dart` (`AppTheme.from(palette)`) · `lib/main.dart:73-80`

- [ ] **Step 1 :** `AppTheme.from(EpilotePalette p)` construit le ThemeData depuis p (remplace les getters figés `light`/`dark`, conservés en alias si utilisés ailleurs).
- [ ] **Step 2 :** `main.dart` : `applyPalette` avant le 1ᵉʳ frame ; `MaterialApp(key: ValueKey(themeId), theme: AppTheme.from(palette))`.
- [ ] **Step 3 :** `flutter analyze` 0 + `flutter test` verts. **Step 4 :** commit.

---

### Task 7 : Sélecteur 3 thèmes

**Fichiers :** Modifier `lib/core/widgets/app_shell/app_header.dart` (icône lune → menu 3 entrées) · `lib/features/user/widgets/user_settings_cards.dart` · `lib/features/admin_groupe/screens/admin_settings_screen.dart`

- [ ] **Step 1 :** menu Clair / Sombre / Melack (icônes `light_mode` / `dark_mode` / `shield_moon`), coche sur l'actif, appelle `themeIdProvider.notifier.set()`.
- [ ] **Step 2 :** analyze 0 + tests verts. **Step 3 :** commit.

---

### Task 8 : Audit `Colors.white` (ciblé, pas en masse)

**Motifs :** `color: Colors.white`, `backgroundColor: Colors.white`, `fillColor: Colors.white`, `Card(color: Colors.white)`.

**Règle :** vrai fond → `kCardBg`. Texte/icône blanc sur bandeau coloré → **laisser** (correct dans les 3 thèmes).

- [ ] **Step 1 :** lister les sites par motif ; classer fond vs sur-couleur.
- [ ] **Step 2 :** convertir les vrais fonds uniquement.
- [ ] **Step 3 :** analyze 0 + tests verts. **Step 4 :** commit.

---

### Task 9 : Vérification GUI (critère d'arrêt)

**Un thème sombre à moitié fait est pire que pas de thème.**

- [ ] **Step 1 :** `flutter run -d linux` (GDK_SCALE=1), login `directeur@kinkala.cg` / `Admin@2024!`, PIN Aline `1994`.
- [ ] **Step 2 :** pour chacun des 3 thèmes, capturer : Tableau de bord, Élèves, Inscriptions, Finance, Messagerie, Paramètres (`import -window`).
- [ ] **Step 3 :** **regarder** chaque capture. Tout aplat blanc résiduel en Sombre/Melack = défaut → retour Task 8.
- [ ] **Step 4 :** vérifier vitrine + login intacts. **Step 5 :** commit final.
