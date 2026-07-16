# Thèmes E-PILOTE — Clair · Sombre · Melack

> Spec de conception — 2026-07-16 — branche `feat/poste-vitrine-securite`
> **LIVRÉ 2026-07-17** — voir §11 : ce que la mise en œuvre a démenti.

## 1. Problème

L'app expose un sélecteur de thème qui ne fait rien. `themeModeProvider`
existe, `AppTheme.light` / `AppTheme.dark` sont câblés dans `main.dart:78-80`,
l'icône lune est dans l'en-tête — et **cliquer dessus ne change pas un pixel**
(vérifié en GUI le 2026-07-16 : captures avant/après identiques).

Cause racine, mesurée et non supposée :

| Mesure | Valeur |
|---|---|
| Fichiers Dart / lignes | 455 / 181 186 |
| Couleurs hex écrites en dur (`Color(0x…)`) | 1 005 dans 175 fichiers |
| `Colors.white` / `Colors.black` | 1 379 |
| Appels à `Theme.of(context)` | **2** |

L'UI ne lit jamais le thème : elle peint ses couleurs elle-même. `ThemeData` est
un décor sans spectateur.

**Point de levier** : `lib/core/widgets/admin_ui.dart` déclare 11 jetons
(`kNavyDeep`, `kNavyDark`, `kNavy`, `kGreen`, `kAccent`, `kRed`, `kSurface`,
`kCardBg`, `kTextPrimary`, `kTextMuted`, `kBorder`) importés par **121 des 175**
fichiers qui peignent. Le chantier n'est donc pas « réécrire 1 005 couleurs »,
c'est « faire varier 11 jetons ». L'obstacle : ils sont `const`, donc figés à la
compilation.

## 2. Décisions

### 2.1 Melack = apparence seule

Melack est une **3ᵉ palette**, pas un mode de sécurité. Raison : le thème est un
choix personnel de l'agent (§2.2) ; or un agent ne doit pas pouvoir désactiver
une protection en changeant de palette. Un thème-qui-protège et un
thème-qu'on-choisit sont contradictoires.

Un futur « mode sécurisé » (masquage au repos, filigrane, verrouillage
agressif), lui, serait **imposé par la direction** et vivrait sur un axe séparé
— il pourra forcer la palette Melack sans que Melack ne le porte. Hors périmètre
ici (§10).

### 2.2 Préférence par agent, locale

Le thème suit l'**agent actif**, pas l'appareil ni le compte Supabase — c'est
l'agent qui regarde l'écran (cf. architecture poste partagé : identité APPAREIL
vs AGENT ACTIF). Stocké dans `SharedPreferences`, clé indexée par `profileId`,
sur le modèle exact de `deviceModeProvider` / des clés PIN
(`active_agent_provider.dart`). Aucune migration base, fonctionne hors-ligne.

- Poste partagé (`agentLockApplies(role) == true`) → clé = id de l'agent actif ;
  chaque agent retrouve son thème après le PIN.
- Sinon (super_admin / admin_groupe) → clé = id du compte connecté.
- Aucune préférence enregistrée → **Clair** (comportement actuel préservé).

### 2.3 Architecture : jetons globaux pilotés par la palette

Les 11 jetons de `admin_ui.dart` deviennent des variables alimentées par la
palette active ; `applyPalette(p)` les réaffecte, puis l'arbre est reconstruit
intégralement.

**Les 121 fichiers ne changent pas d'une ligne** : ils continuent d'écrire
`kNavy`. Seul le `const` devenu invalide disparaît.

Alternative écartée — `ThemeExtension` canonique (`context.colors.navy`) :
orthodoxe et durable, mais exige de réécrire **tous** les sites d'appel *en plus*
de retirer les mêmes `const`. Le coût `const` est intrinsèque au thème, pas au
choix d'architecture : toute couleur variable à l'exécution tue le `const`. À
coût `const` égal, `ThemeExtension` ajoute un diff de plusieurs milliers de
lignes de réécriture pure, pour un seul gain réel — le thème par sous-arbre —
dont le projet n'a pas l'usage (vitrine et login sont déjà sombres par
conception, indépendamment du thème).

**Limite assumée** : deux sous-arbres ne peuvent pas porter deux thèmes
différents. Sans conséquence ici.

## 3. Composants

| Fichier | Rôle |
|---|---|
| `lib/core/theme/palette.dart` **(neuf)** | `EpilotePalette` : les 11 jetons comme données + les 3 constantes `clair` / `sombre` / `melack` + `EpiloteThemeId` (enum). Aucune dépendance widget. Testable seul. |
| `lib/core/widgets/admin_ui.dart` **(modifié)** | Les 11 jetons passent de `const Color` à variables ; `applyPalette(EpilotePalette)` les réaffecte. Reste la seule source des jetons. |
| `lib/core/theme/theme_provider.dart` **(neuf)** | `themeIdProvider` (StateNotifier, calqué sur `deviceModeProvider`) : charge la préférence de l'agent, la persiste, appelle `applyPalette`. |
| `lib/core/theme/app_theme.dart` **(modifié)** | `AppTheme.from(palette)` construit le `ThemeData` depuis la palette (au lieu de deux getters figés `light`/`dark`). |
| `lib/main.dart` **(modifié)** | Applique la palette avant le 1ᵉʳ frame ; `MaterialApp(key: ValueKey(themeId), theme: AppTheme.from(p))` → le changement de clé force le rebuild complet. |

Le sélecteur : l'icône lune de l'en-tête devient un menu à 3 entrées
(`app_header.dart`), et la carte thème de `user_settings_cards.dart` /
`admin_settings_screen.dart` expose le même choix.

## 4. Les trois palettes

Chaque palette définit les mêmes 11 jetons. Contrastes **calculés** (WCAG 2.x,
2026-07-16) pour `kTextPrimary` / `kTextMuted` sur `kSurface` / `kCardBg` :

| Palette | texte/surface | texte/carte | atténué/surface | atténué/carte |
|---|---|---|---|---|
| Clair | 16.15 | 17.85 | **4.31 ⚠️** | 4.76 |
| Sombre | 16.02 | 14.64 | 6.15 | 5.62 |
| Melack | 17.43 | 16.57 | 5.76 | 5.48 |

⚠️ **Dette pré-existante, assumée** : en Clair, `kTextMuted #64748B` sur
`kSurface #F0F4F8` = 4.31:1, sous le seuil AA (4.5). Elle est **antérieure à ce
chantier** et n'est pas corrigée ici : éclaircir le texte secondaire modifierait
l'apparence de *tous* les écrans clairs existants — un effet de bord étranger à
un chantier de thèmes, et une régression visuelle pour l'utilisateur. La
non-régression prime (§4, « Clair »). À traiter séparément si souhaité (le
passage à `#5A6675` suffirait).

| Jeton | Clair (actuel) | Sombre | Melack |
|---|---|---|---|
| `kNavyDeep` | `#091828` | `#0A0F16` | `#000000` |
| `kNavyDark` | `#0F2340` | `#111823` | `#04070B` |
| `kNavy` | `#1E3A5F` | `#1B2634` | `#080D14` |
| `kGreen` | `#009A44` | `#22C55E` | `#00E08A` |
| `kAccent` | `#FBBC04` | `#FBBF24` | `#FFB300` |
| `kRed` | `#DC2626` | `#F87171` | `#FF3B30` |
| `kSurface` | `#F0F4F8` | `#0D1117` | `#05080C` |
| `kCardBg` | `#FFFFFF` | `#161B22` | `#0B1017` |
| `kTextPrimary` | `#0F172A` | `#E6EDF3` | `#E8F0F7` |
| `kTextMuted` | `#64748B` | `#8B949E` | `#7D8B9A` |
| `kBorder` | `#E2E8F0` | `#2D333B` | `#1B2531` |

**Clair** : strictement les valeurs actuelles. Non-régression par construction.

**Sombre** : sombre lisible et confortable — gris-bleu, pas noir ; accents
éclaircis pour tenir le contraste sur fond foncé (`kGreen` `#009A44` → `#22C55E`,
sinon illisible).

**Melack** — identité décidée : *poste classifié*. Noir carbone quasi pur
(`kSurface #05080C`), neutres **froids**, contraste plus élevé que Sombre, vert
**phosphore** (`#00E08A`) évoquant le terminal sécurisé, ambre et rouge francs
pour les alertes. Ce qui le distingue de Sombre au premier coup d'œil : le fond
est *noir*, pas gris ; la chrome (sidebar/en-tête, `kNavyDeep #000000`) disparaît
dans l'écran ; les accents sont plus saturés et plus froids.

## 5. Migration — le codemod `const`

Retirer les jetons de `const` casse **2 210 issues dans 209 fichiers** (mesuré
2026-07-16 en passant les 11 jetons en non-`const` puis `flutter analyze`) :

| Type | Nb |
|---|---|
| `invalid_constant` | 2 106 |
| `non_constant_list_element` | 32 |
| `const_initialized_with_non_constant_value` | 21 |
| `non_constant_default_value` | 18 |
| `non_constant_map_value` | 12 |
| `const_with_non_constant_argument` | 11 |

Toutes sont **mécaniques** : l'analyseur désigne chaque site (fichier:ligne:col),
et le correctif est le retrait du `const` englobant. Procédure :

1. Passer les 11 jetons en variables.
2. Boucler : `flutter analyze` → retirer le `const` englobant de chaque site
   signalé → recommencer jusqu'à **0 issue**. Le compilateur est l'oracle : le
   critère de fin n'est pas un jugement, c'est `analyze == 0`.
3. `dart fix --apply` en fin de course (les `prefer_const_constructors` restants).

### 5.1 Les 76 déclarations top-level — le vrai piège

76 déclarations top-level lisent les jetons (`grep -rnE '^(const|final) .*(kNavy|…)'`),
p. ex. `const _kCardDeco = BoxDecoration(color: kCardBg)`. Rendues simplement
`final`, elles s'initialiseraient **une fois au démarrage** et ne suivraient
jamais un changement de thème — un bug silencieux, invisible à l'analyse.

→ Chacune doit devenir un **getter** (`BoxDecoration get _kCardDeco => …`), donc
réévaluée à chaque build. À traiter une par une, pas en masse : c'est le seul
endroit du codemod qui exige un jugement.

## 6. Les 1 379 `Colors.white` / `Colors.black`

Ils ne passent pas par les jetons et **resteront blancs et noirs** — c'est là que
Sombre et Melack seront laids. Ils se répartissent en deux familles qu'il faut
distinguer **à la lecture, pas en masse** :

- **Faux positifs, à laisser** : texte blanc sur bandeau coloré, icône blanche
  sur bouton plein, `Colors.white.withValues(alpha:)` sur la sidebar navy. Ils
  sont corrects dans les 3 thèmes.
- **Vrais fonds, à convertir** en `kCardBg` / `kTextPrimary` : `Container(color:
  Colors.white)`, `Scaffold(backgroundColor: Colors.white)`, `Card(color:
  Colors.white)`.

Audit ciblé par motif (`color: Colors.white`, `backgroundColor: Colors.white`,
`fillColor: Colors.white`) plutôt que balayage des 1 379.

## 7. Tests

- `palette_test.dart` : les 3 palettes définissent les 11 jetons ; Clair ==
  valeurs actuelles **au hex près** (verrou de non-régression) ; contrastes
  `kTextPrimary`/`kTextMuted` sur `kSurface`/`kCardBg` ≥ 4.5:1 pour **Sombre et
  Melack** (les palettes que ce chantier crée). Clair est explicitement exempté
  pour `kTextMuted`/`kSurface` (4.31, dette antérieure documentée §4) : l'exemption
  est **nommée et commentée** dans le test, pas un seuil abaissé en silence —
  sinon le verrou ne détecterait plus une vraie régression.
- `theme_provider_test.dart` : défaut = Clair sans préférence ; persistance par
  `profileId` ; deux agents = deux thèmes ; `applyPalette` muté → jetons changés.
- Les 217 tests existants doivent rester verts. **Ils doivent réinitialiser la
  palette** (`setUp(() => applyPalette(EpilotePalette.clair))`) — sinon l'état
  global fuit d'un test à l'autre. C'est le prix de l'architecture §2.3, assumé.

## 8. Critère d'arrêt — vérification GUI

**Un thème sombre à moitié fait est pire que pas de thème** (flashs blancs). Le
critère n'est donc pas « ça compile » mais **l'inspection visuelle écran par
écran**, dans les 3 thèmes, via `flutter run -d linux` + `import -window`
(cf. `gui-testing-linux`) :

Espace école (Tableau de bord, Élèves, Inscriptions, Finance, EDT, Messagerie,
Annonces, Paramètres) · admin_groupe (dashboard, écoles, abonnement) ·
super_admin (dashboard, annonces) · vitrine + login + écran-verrou (doivent
rester intacts : déjà sombres par conception).

Tout écran qui garde un aplat blanc en Sombre/Melack est un défaut à corriger
avant de livrer.

## 9. Risques

| Risque | Traitement |
|---|---|
| État global mutable | Assumé (§2.3). Une seule porte d'écriture : `applyPalette`. `setUp` dans les tests. |
| Perte de `const` → rebuilds | Coût réel mais léger ; intrinsèque au thème (§2.3). Surveiller à l'œil sur les longues listes (Élèves, Messagerie). |
| Codemod de 2 106 sites = diff énorme | Mécanique et vérifié par l'oracle `analyze == 0` + 217 tests + GUI. **Commit séparé** du reste pour rester relisible. |
| 76 getters oubliés → thème figé | Le seul point exigeant un jugement ; traité un par un et vérifié en GUI (§8). |
| Régression du thème Clair | Verrouillée par le test hex de §7 : Clair == valeurs actuelles. |

## 10. Hors périmètre

- Mode sécurisé fonctionnel (masquage au repos, filigrane, anti-capture) et son
  imposition par la direction — axe séparé (§2.1).
- Thème imposé par l'établissement / synchronisé en base.
- Suivi du thème système (`ThemeMode.system`).
- Refonte `ThemeExtension` (§2.3).
- Thème de la vitrine / login / écran-verrou : déjà sombres par conception.

---

## 11. Ce que la mise en œuvre a démenti (2026-07-17)

La spec avait raison sur la structure, faux sur trois chiffres — et il a manqué
un défaut qu'aucune analyse statique ne pouvait voir.

### 11.1 Les « 76 déclarations top-level » étaient 14

Le `grep` surestimait : l'analyseur n'en signale que 14 (puis 8 de plus après le
rebranchement des palettes locales, §11.3). La règle, elle, tenait : rendues
`final`, elles auraient figé la couleur au démarrage. Toutes converties en
getters. Plusieurs étaient en réalité des variables **locales** dans un
`build()` — pour celles-là `final` suffit (réévaluées à chaque build).

### 11.2 `non_constant_default_value` n'était PAS mécanique

La spec les rangeait avec les autres `const` à retirer. C'est faux : en Dart une
valeur par défaut doit être une constante de compilation **quelle que soit** la
constness du constructeur — retirer `const` ne corrige rien. Les 18 sites
(`this.color = kNavy`) sont devenus `Color? color` résolu dans la liste
d'initialisation : le champ reste non-nullable, aucun site d'usage ne change.

### 11.3 super_admin avait sa PROPRE palette (angle mort de la spec)

Le levier « 11 jetons dans `admin_ui`, 121 fichiers » ne couvrait pas
`super_admin` : **160 jetons locaux en dur dans 18 de ses 20 fichiers**
(`const _kNavy = Color(0xFF1E3A5F);`), dupliquant la palette canonique au hex
près. Sans traitement, cet espace serait resté clair pendant que le reste
passait au sombre — précisément le « moitié fait » que §8 interdit. Les jetons
dupliqués sont rebranchés en getters vers les jetons globaux ; les accents
décoratifs propres (violet, orange…) restent `const`.

### 11.4 ⚠️ Le vrai défaut : `navy` est à DOUBLE rôle

Invisible à l'analyse, invisible aux tests d'alors, visible en 2 secondes à
l'écran : les titres de section (« Taux de recouvrement »…) DISPARAISSAIENT en
Sombre.

`navy` avait été traité comme une couleur de chrome et foncé (`#1B2634`) →
contraste **1.13** sur les cartes. Or `navy` sert d'abord de **premier plan** :
**432 usages texte/icône contre 282 en fond** (mesuré). Les deux rôles tirent en
sens opposés en thème sombre. Le premier plan l'emporte → `navy` s'ÉCLAIRCIT
(Sombre `#5B8FD4`, Melack `#3892CC`), ce qui est aussi la convention Material.
Borné par le haut : le blanc des bandeaux doit rester lisible dessus (≥ 3:1).

**La règle est désormais dans `palette_test.dart`**, pas dans une intention :
`navy` lisible sur `cardBg` (≥4.5), blanc lisible sur `navy` (≥3.0), chrome
`navyDeep`/`navyDark` toujours foncé. Le premier essai de correction a été
rattrapé par ce test (`#4FB0E8` : blanc à 2.41 dessus).

### 11.5 Les blancs en dur : deux passes, pas une

§6 disait « auditer par motif ». Insuffisant : le motif `color: Colors.white`
rate les **ternaires** (`color: selected ? x : Colors.white`) — 32 fonds
supplémentaires, dont les cartes cycle et les bulles de chat, restés blancs au
1ᵉʳ passage. Le tri fiable est le **constructeur englobant** (`BoxDecoration` vs
`TextStyle`), pas le nom de la propriété : `color:` ne dit rien à lui seul.
Total : 250 fonds convertis, 391 blancs de premier plan laissés.

### 11.6 Bilan

`flutter analyze` 0 · 236 tests verts (19 neufs) · vérifié à l'écran dans les 3
thèmes (Tableau de bord, Inscriptions, Élèves, Matières, Paiements, Paramètres)
+ persistance par agent vérifiée au redémarrage. Outils du codemod conservés
dans `epilote/tools/` (`strip_const.py`, `fix_defaults.py`, `fix_white_bg.py`,
`relink_local_tokens.py`) : réutilisables si un nouvel espace doit rejoindre la
palette.

**Reste** : les avertissements `ListTile ... may be invisible` observés au
lancement sont **antérieurs** à ce chantier (log daté avant toute bascule) et
non traités ici.
