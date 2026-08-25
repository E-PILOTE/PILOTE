---
name: overlay-builder-golden-blindspot
description: "Les widgets montés dans MaterialApp.builder n'ont pas d'Overlay ancêtre ; les golden/widget tests le masquent — lancer l'app réelle"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 66c7bd66-1eb0-4744-a41e-b4efd39667b6
---

Un widget monté dans `MaterialApp.builder` (ex. un overlay global comme `AgentLockGate`) est **frère du Navigator**, donc **sans Overlay ancêtre**. `Tooltip`, `TextField`/`EditableText`, `DropdownButton`, `showMenu`… **exigent un Overlay au build** → `No Overlay widget found` → écran d'erreur rouge en prod.

**Why:** découvert en lançant l'app réelle après avoir livré la refonte de l'écran-verrou poste partagé (2026-07-06) : golden + widget tests TOUS verts, mais crash immédiat au `flutter run -d linux`. Cause : les tests enveloppent le widget dans `MaterialApp(home: ...)` qui, lui, fournit un Navigator→Overlay. Le vrai câblage (`builder:`) ne l'a pas → angle mort.

**How to apply:**
1. Pour un widget hébergé dans `MaterialApp.builder` (hors Navigator), lui fournir un Overlay ancêtre — mais **ne monter cet Overlay QUE quand l'écran s'affiche** (`showing ? Overlay(...) : rien`), le `child` (Navigator) restant en position stable dans le `Stack`. Un Overlay+AnimatedSwitcher monté EN PERMANENCE en frère de l'app fait lever `!child.attached` à CHAQUE frame de `flushSemantics`, même à vide (login/dashboard) → ~400 exceptions/accessibilité cassée (corrigé `f028d9b`, gate `agent_lock_gate.dart`).
2. ⚠️ **`Overlay.initialEntries` n'est lu qu'à la création.** Ne PAS capturer un contenu réactif dans la closure de l'`OverlayEntry` : il se fige sur sa 1ʳᵉ valeur (le verrou ne réapparaissait jamais sur simple changement de provider — « Changer d'utilisateur » mort). Monter l'Overlay à la demande (contenu frais au montage) ou héberger un `ConsumerWidget` DANS l'entrée + `ValueKey` pour forcer un Overlay neuf au changement de contenu.
3. Test de régression reproduisant le vrai câblage `MaterialApp(builder:)` + un test qui **fait basculer le provider APRÈS le montage** (pas seulement `overrideWithValue` figé) → prouve que le contenu se met à jour.
4. **Toujours lancer l'app réelle** (`flutter run -d linux`, cf. [[gui-testing-linux]]) et **grep le log runtime** (`EXCEPTION|child.attached`) à CHAQUE écran (login inclus, pas seulement le lock) : les tests `MaterialApp(home:)` masquent ces bugs. Voir [[poste-vitrine-securite-refonte]].

**Bonus (même session) :** crash au clic « Afficher » du PIN → un `AnimatedContainer` NE PEUT PAS animer `shape` cercle↔rectangle (BoxDecoration.lerp garde `shape:circle` en interpolant un `borderRadius` → assertion `shape != circle || borderRadius == null`). Garder la forme rectangulaire et n'animer que le rayon (à 15×15 un rayon ≥7,5 = cercle).
