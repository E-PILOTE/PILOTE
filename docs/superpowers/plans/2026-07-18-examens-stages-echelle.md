# Examens & Stages à l'échelle — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre les listes candidats (examens) et stages lisibles/fluides à toute échelle en les regroupant par classe (badge filière), en-têtes pliables, rendu virtualisé en slivers.

**Architecture:** Une utilitaire générique de regroupement/aplatissement (pure, testée) alimente un `SliverList.builder`. Les écrans Session-examen et Stages passent d'un `ListView` plat à un `CustomScrollView` ; l'état d'UI candidats remonte dans le `State` de l'écran. Aucune écriture, migration, sync-rule ou RLS modifiée.

**Tech Stack:** Flutter, Riverpod, PowerSync (offline `db.getAll`/`db.watch`), Syncfusion (inchangé).

## Global Constraints

- Architecture offline-first : côté école, **jamais** `supabase.from()` — lecture via `db.getAll`/`db.watch` uniquement.
- Fichiers Dart **≤ 500 lignes** ; découper par responsabilité.
- KPI = `KpiGrid`/`mainAxisExtent` (jamais `childAspectRatio`) — inchangé ici.
- Jetons couleur RUNTIME (`kNavy`, `kGreen`…) : **jamais** `const` sur un widget qui les porte.
- Le « lot » ne s'affiche **pas** à l'écran (transmission/PDF uniquement, code inchangé).
- `flutter analyze` doit rester à **0**. Binaire : `/home/melack/flutter/bin/flutter`.

---

### Task 1 : Utilitaire générique de regroupement par classe

**Files:**
- Create: `epilote/lib/core/utils/class_grouping.dart`
- Test: `epilote/test/class_grouping_test.dart`

**Interfaces:**
- Produces:
  - `class ClassGroup<T> { final String? classId; final String className; final String? filiereLabel; final int levelOrder; final List<T> items; }`
  - `List<ClassGroup<T>> groupByClass<T>(List<T> rows, {required String? Function(T) classId, required String Function(T) className, required String? Function(T) filiere, required int Function(T) levelOrder,})`
  - `sealed class GroupedRow<T> {}` avec `class GroupHeaderRow<T> extends GroupedRow<T> { final ClassGroup<T> group; }` et `class GroupItemRow<T> extends GroupedRow<T> { final T item; final String? classId; }`
  - `List<GroupedRow<T>> flattenGroups<T>(List<ClassGroup<T>> groups, Set<String?> collapsed)`

- [ ] **Step 1: Écrire le test qui échoue**

```dart
// epilote/test/class_grouping_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:epilote/core/utils/class_grouping.dart';

class _Row {
  const _Row(this.cid, this.cls, this.fil, this.ord, this.name);
  final String? cid;
  final String cls;
  final String? fil;
  final int ord;
  final String name;
}

List<ClassGroup<_Row>> _group(List<_Row> rows) => groupByClass<_Row>(
      rows,
      classId: (r) => r.cid,
      className: (r) => r.cls,
      filiere: (r) => r.fil,
      levelOrder: (r) => r.ord,
    );

void main() {
  group('groupByClass', () {
    test('regroupe par classe, trie par levelOrder puis nom de classe', () {
      final rows = [
        const _Row('b', 'Tle A', 'BAC_T', 2, 'Zoé'),
        const _Row('a', '3e B', null, 1, 'Ana'),
        const _Row('b', 'Tle A', 'BAC_T', 2, 'Bob'),
      ];
      final g = _group(rows);
      expect(g.map((e) => e.classId).toList(), ['a', 'b']);
      expect(g[1].items.length, 2);
      expect(g[1].filiereLabel, 'BAC_T');
      expect(g[0].levelOrder, 1);
    });

    test('liste vide -> aucun groupe', () {
      expect(_group(const []), isEmpty);
    });
  });

  group('flattenGroups', () {
    test('groupe déplié = header + items ; replié = header seul', () {
      final rows = [
        const _Row('a', '3e B', null, 1, 'Ana'),
        const _Row('b', 'Tle A', 'BAC_T', 2, 'Bob'),
      ];
      final g = _group(rows);
      final flat = flattenGroups<_Row>(g, {'b'}); // 'b' replié
      // a: header + 1 item ; b: header seul
      expect(flat.length, 3);
      expect(flat[0], isA<GroupHeaderRow<_Row>>());
      expect(flat[1], isA<GroupItemRow<_Row>>());
      expect(flat[2], isA<GroupHeaderRow<_Row>>());
    });
  });
}
```

- [ ] **Step 2: Lancer le test (échec attendu)**

Run: `cd epilote && /home/melack/flutter/bin/flutter test test/class_grouping_test.dart`
Expected: FAIL — `class_grouping.dart` introuvable.

- [ ] **Step 3: Écrire l'implémentation minimale**

```dart
// epilote/lib/core/utils/class_grouping.dart

/// Regroupement générique de lignes par CLASSE, pour un rendu virtualisé et
/// pliable (examens, stages). Pure : aucune dépendance Flutter, testable seul.
class ClassGroup<T> {
  ClassGroup({
    required this.classId,
    required this.className,
    required this.filiereLabel,
    required this.levelOrder,
    required this.items,
  });

  final String? classId;
  final String className;
  final String? filiereLabel;
  final int levelOrder;
  final List<T> items;
}

/// Regroupe `rows` par `classId`, chaque groupe trié par `levelOrder` puis nom.
/// L'ordre des items à l'intérieur d'un groupe suit l'ordre d'entrée (déjà trié
/// par la requête SQL : last_name, first_name).
List<ClassGroup<T>> groupByClass<T>(
  List<T> rows, {
  required String? Function(T) classId,
  required String Function(T) className,
  required String? Function(T) filiere,
  required int Function(T) levelOrder,
}) {
  final map = <String?, ClassGroup<T>>{};
  for (final r in rows) {
    final id = classId(r);
    final g = map.putIfAbsent(
      id,
      () => ClassGroup<T>(
        classId: id,
        className: className(r),
        filiereLabel: filiere(r),
        levelOrder: levelOrder(r),
        items: <T>[],
      ),
    );
    g.items.add(r);
  }
  final list = map.values.toList()
    ..sort((a, b) {
      final d = a.levelOrder.compareTo(b.levelOrder);
      return d != 0 ? d : a.className.compareTo(b.className);
    });
  return list;
}

/// Une entrée de la liste APLATIE consommée par le SliverList : soit un en-tête
/// de groupe, soit une ligne d'item (présente seulement si le groupe est déplié).
sealed class GroupedRow<T> {
  const GroupedRow();
}

class GroupHeaderRow<T> extends GroupedRow<T> {
  const GroupHeaderRow(this.group);
  final ClassGroup<T> group;
}

class GroupItemRow<T> extends GroupedRow<T> {
  const GroupItemRow(this.item, this.classId);
  final T item;
  final String? classId;
}

/// Aplati les groupes en une séquence header/items. Un groupe dont le `classId`
/// est dans `collapsed` n'émet que son en-tête. C'est ce que parcourt le
/// `SliverList.builder` -> virtualisation réelle.
List<GroupedRow<T>> flattenGroups<T>(
  List<ClassGroup<T>> groups,
  Set<String?> collapsed,
) {
  final out = <GroupedRow<T>>[];
  for (final g in groups) {
    out.add(GroupHeaderRow<T>(g));
    if (!collapsed.contains(g.classId)) {
      for (final it in g.items) {
        out.add(GroupItemRow<T>(it, g.classId));
      }
    }
  }
  return out;
}
```

- [ ] **Step 4: Lancer le test (succès attendu)**

Run: `cd epilote && /home/melack/flutter/bin/flutter test test/class_grouping_test.dart`
Expected: PASS (tous).

- [ ] **Step 5: Commit**

```bash
git add epilote/lib/core/utils/class_grouping.dart epilote/test/class_grouping_test.dart
git commit -m "feat(core): utilitaire de regroupement par classe (pliable, virtualisable)"
```

---

### Task 2 : Champ `filiereLabel` sur `ExamCandidateRow`

**Files:**
- Modify: `epilote/lib/features/examens/providers/exam_candidates_provider.dart`

**Interfaces:**
- Consumes: rien.
- Produces: `ExamCandidateRow.filiereLabel` (`String?`), alimenté depuis `classes.filiere_label`.

- [ ] **Step 1: Ajouter le champ au modèle**

Dans `ExamCandidateRow` : ajouter `required this.filiereLabel,` au constructeur et `final String? filiereLabel;` aux champs (à côté de `className`).

- [ ] **Step 2: Ajouter la colonne au SELECT + au mapping**

Dans la requête `db.getAll` qui construit les candidats, ajouter `c.filiere_label` au `SELECT` (le join `classes c` existe déjà). Dans le mapping de `ExamCandidateRow`, ajouter `filiereLabel: r['filiere_label'] as String?,`.

- [ ] **Step 3: Vérifier la compilation (analyze)**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze lib/features/examens/providers/exam_candidates_provider.dart`
Expected: `No issues found!` (ou 0 après correction d'un `required` manquant ailleurs).

- [ ] **Step 4: Corriger tout appelant cassé**

Si un test/mock construit `ExamCandidateRow(...)`, ajouter `filiereLabel: null,`. Chercher : `grep -rn "ExamCandidateRow(" epilote/lib epilote/test`. Corriger chaque construction.

- [ ] **Step 5: analyze global + commit**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze`
Expected: `No issues found!`

```bash
git add epilote/lib/features/examens/providers/exam_candidates_provider.dart
git commit -m "feat(examens): filiereLabel sur ExamCandidateRow (source classes.filiere_label)"
```

---

### Task 3 : Rendu groupé/virtualisé des candidats (widget slivers)

**Files:**
- Create: `epilote/lib/features/examens/widgets/exam_candidate_grouped.dart`
- Modify: `epilote/lib/features/examens/widgets/exam_candidate_views.dart` (réutiliser le contenu de ligne existant)

**Interfaces:**
- Consumes: `groupByClass`, `flattenGroups`, `ClassGroup`, `GroupedRow` (Task 1) ; `ExamCandidateRow.filiereLabel` (Task 2) ; `ExamCandidateActions`, `candidateDossierTone`, `CandidatePill`, `ResultChip` (existants).
- Produces:
  - `class ExamGroupState { final Set<String?> collapsed; }` (ou géré par l'écran — voir Task 4).
  - `SliverList examCandidateSliver({required List<ExamCandidateRow> rows, required Set<String?> collapsed, required void Function(String? classId) onToggleGroup, required bool canEdit, required bool isTable, required String sessionId, required String examCode, required Set<String> selected, required void Function(String id) onToggle, required void Function(ClassGroup<ExamCandidateRow>) onToggleGroupAll, required bool showFiliere,})` — retourne un `SliverList` prêt à insérer dans le `CustomScrollView` de l'écran.
  - `class ExamGroupHeader extends StatelessWidget` — en-tête : `Classe · [badge filière] · N candidats · C complets · D déposés` + chevron + (si canEdit) case tout-sélectionner du groupe.

- [ ] **Step 1: Construire le sliver + l'en-tête de groupe**

Créer `exam_candidate_grouped.dart`. Points clés :
- `final groups = groupByClass<ExamCandidateRow>(rows, classId: (r) => r.classId, className: (r) => r.className ?? '—', filiere: (r) => r.filiereLabel, levelOrder: (r) => 0);` — `levelOrder` : ExamCandidateRow n'ayant pas `levelOrder`, trier par `className` (passer `levelOrder: (r) => 0` et laisser le tri secondaire par nom faire le travail) **ou** ajouter un ordre stable. Si l'ordre par niveau est souhaité, exposer aussi `levelOrder` dans la requête (déjà présent : `c.level_order`) — préférer l'ajouter au modèle. Décision : ajouter `levelOrder` au modèle si absent, sinon 0.
- `final flat = flattenGroups(groups, collapsed);`
- `SliverList.builder(itemCount: flat.length, itemBuilder: (ctx, i) { final e = flat[i]; if (e is GroupHeaderRow<ExamCandidateRow>) return ExamGroupHeader(...); final item = (e as GroupItemRow<ExamCandidateRow>).item; return ExamCandidateRowTile(row: item, ...); });`
- `ExamGroupHeader` : `Container` cliquable (bascule collapse), fond `kNavy.withValues(alpha: 0.05)`, chevron `expand_more/less`, badge filière (si `group.filiereLabel != null`), compteurs dérivés du `group.items` (`complete = items.where((r) => r.isComplete).length`, `submitted = items.where((r) => r.isSubmitted).length`).
- Réutiliser le **contenu** de ligne existant : extraire de `exam_candidate_views.dart` le corps de `_TableRow`/`_CandidateCard` en un widget public `ExamCandidateRowTile` (table) et carte, ou appeler les widgets existants ligne à ligne. Ne PAS dupliquer `ExamCandidateActions`.

- [ ] **Step 2: analyze**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze lib/features/examens/widgets/`
Expected: `No issues found!` (corriger const/quotes au besoin).

- [ ] **Step 3: Commit**

```bash
git add epilote/lib/features/examens/widgets/exam_candidate_grouped.dart epilote/lib/features/examens/widgets/exam_candidate_views.dart
git commit -m "feat(examens): rendu candidats groupé par classe + en-têtes pliables (sliver)"
```

---

### Task 4 : Écran Session en `CustomScrollView` + filière (filtre/colonne)

**Files:**
- Modify: `epilote/lib/features/examens/screens/exam_session_screen.dart`
- Modify: `epilote/lib/features/examens/widgets/exam_candidate_list.dart` (dissoudre `ExamCandidatePanel` : logique filtres/sélection/bulk remonte dans l'écran ; conserver `_BulkBar`, `ExamKpiRow`, dialogues `_confirm`)

**Interfaces:**
- Consumes: `examCandidateSliver` + `ExamGroupHeader` (Task 3) ; `ExamKpiRow`, `_BulkBar`, `ListFilterBar`, `ListResultHeader` (existants).
- Produces: écran Session dont le corps est **un** `CustomScrollView`.

- [ ] **Step 1: Déplacer l'état candidats dans le `State` de l'écran**

Dans `_State` de `ExamSessionScreen`, ajouter : `final _search = TextEditingController(); String _dossier = 'tous'; String _result = 'tous'; String _filiere = 'toutes'; bool _isTable = true; final _selected = <String>{}; final _collapsed = <String?>{};`. Reprendre `_filter`, `_bulkDeposit`, `_bulkRemove`, `_confirm`, `_snack` depuis `ExamCandidatePanel` (déplacement, pas réécriture). Ajouter au filtre : `if (_filiere != 'toutes' && c.filiereLabel != _filiere) return false;`.

- [ ] **Step 2: Reconstruire le corps en slivers**

Remplacer le `ListView(children: [...])` par :
```dart
final filtered = _filter(rows);
final filieres = {for (final r in rows) if (r.filiereLabel != null) r.filiereLabel!};
CustomScrollView(slivers: [
  SliverToBoxAdapter(child: _Head(...)),
  const SliverToBoxAdapter(child: SizedBox(height: 20)),
  SliverToBoxAdapter(child: ExamKpiRow(session: s, canWrite: canRegister || canSubmit)),
  const SliverToBoxAdapter(child: SizedBox(height: 24)),
  SliverToBoxAdapter(child: ScopeDrilldownPanel(...)),
  const SliverToBoxAdapter(child: SizedBox(height: 24)),
  SliverToBoxAdapter(child: _filterBar(filieres)),          // ListFilterBar + dropdowns (dont filière si filieres non vide)
  if (canEdit && selectedRows.isNotEmpty)
    SliverToBoxAdapter(child: _BulkBar(...)),
  SliverToBoxAdapter(child: ListResultHeader(total: rows.length, filtered: filtered.length, noun: 'candidat')),
  examCandidateSliver(rows: filtered, collapsed: _collapsed, showFiliere: filieres.isNotEmpty, ...),
  SliverToBoxAdapter(child: TransmissionsPanel(...)),
  const SliverToBoxAdapter(child: SizedBox(height: 32)),
]);
```
Padding horizontal : envelopper chaque `SliverToBoxAdapter` enfant dans un `Padding(horizontal: 20)` OU utiliser `SliverPadding` autour des groupes. Défaut collapse : à la 1ʳᵉ construction, si `groups.length > 2` et scope non-classe, initialiser `_collapsed` avec tous les `classId` sauf le premier — calculé une fois (garder un `bool _collapseInit`).

- [ ] **Step 3: Supprimer l'ancien `ExamCandidatePanel` et ses usages**

`ExamCandidatePanel` n'est plus référencé → le retirer de `exam_candidate_list.dart` (garder `ExamKpiRow`, `_BulkBar` rendus publics si besoin par l'écran). `grep -rn "ExamCandidatePanel" epilote/lib` doit être vide.

- [ ] **Step 4: analyze + test**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze && /home/melack/flutter/bin/flutter test`
Expected: `No issues found!` et tests verts.

- [ ] **Step 5: Commit**

```bash
git add epilote/lib/features/examens/screens/exam_session_screen.dart epilote/lib/features/examens/widgets/exam_candidate_list.dart
git commit -m "feat(examens): écran Session virtualisé (CustomScrollView) + filtre/colonne filière"
```

---

### Task 5 : Champ `filiereLabel` sur `InternshipRow`

**Files:**
- Modify: `epilote/lib/features/stages/providers/stages_provider.dart`

**Interfaces:**
- Produces: `InternshipRow.filiereLabel` (`String?`) + `InternshipRow.levelOrder` (`int`, depuis `classes.level_order`) pour l'ordre des groupes.

- [ ] **Step 1: Ajouter les champs au modèle**

Dans `InternshipRow` : `required this.filiereLabel,` / `final String? filiereLabel;` et `required this.levelOrder,` / `final int levelOrder;` (à côté de `className`). Ajouter aussi `final String? classId;` si absent (pour la clé de regroupement).

- [ ] **Step 2: SELECT + mapping**

Dans la requête stages, ajouter `c.filiere_label, c.level_order, c.id AS class_id` au `SELECT` (join `classes c` existant). Mapper : `filiereLabel: r['filiere_label'] as String?, levelOrder: (r['level_order'] as int?) ?? 0, classId: r['class_id'] as String?,`.

- [ ] **Step 3: Corriger les constructeurs cassés + analyze**

`grep -rn "InternshipRow(" epilote/lib epilote/test` → ajouter les nouveaux champs partout. Run: `cd epilote && /home/melack/flutter/bin/flutter analyze`. Expected: `No issues found!`.

- [ ] **Step 4: Commit**

```bash
git add epilote/lib/features/stages/providers/stages_provider.dart
git commit -m "feat(stages): filiereLabel + levelOrder + classId sur InternshipRow"
```

---

### Task 6 : Stages groupés/virtualisés + écran en slivers

**Files:**
- Create: `epilote/lib/features/stages/widgets/stages_grouped.dart`
- Modify: `epilote/lib/features/stages/screens/stages_screen.dart`
- Modify: `epilote/lib/features/stages/widgets/stages_views.dart` (réutiliser le contenu de ligne)

**Interfaces:**
- Consumes: `groupByClass`, `flattenGroups` (Task 1) ; `InternshipRow.filiereLabel/levelOrder/classId` (Task 5) ; `stageTone`, `StagesTable`/`StagesCards` contenu de ligne (existants).
- Produces: `SliverList internshipSliver({required List<InternshipRow> rows, required Set<String?> collapsed, required void Function(String? classId) onToggleGroup, required bool showFiliere, ...})` + `StageGroupHeader`.

- [ ] **Step 1: Sliver groupé + en-tête stages**

Créer `stages_grouped.dart` sur le modèle de Task 3. En-tête : `Classe · [badge filière] · N stages · A attestations · B bloqués` (compteurs dérivés du `group.items` : `attestations = items.where((i) => i.hasAttestation).length` ; « bloqués » = croisement déjà porté par `StagesOverview.blocked` au niveau écran — pour l'en-tête par classe, compter `items.where((i) => i.attestationOverdue).length` comme « attestations dues » par classe, ne pas recalculer le blocage bac ici). Réutiliser le contenu de ligne stage existant (extraire un `StageRowTile` public de `stages_views.dart` sans dupliquer les actions).

- [ ] **Step 2: Écran Stages en `CustomScrollView`**

Convertir le `ListView`/`Column` de `stages_screen.dart` en `CustomScrollView(slivers: [...])` : KPI (`KpiGrid`), `StagesStatusChart`, barre de filtres (+ filtre filière alimenté par les filières présentes), `internshipSliver(...)`, actions groupées existantes conservées. Même logique de collapse par défaut (>2 groupes → tout replié sauf le premier, `_collapseInit`).

- [ ] **Step 3: analyze + test + build**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze && /home/melack/flutter/bin/flutter test`
Expected: `No issues found!` + tests verts.

- [ ] **Step 4: Commit**

```bash
git add epilote/lib/features/stages/
git commit -m "feat(stages): écran virtualisé (CustomScrollView) + regroupement classe/filière"
```

---

### Task 7 : Vérification finale + build release

**Files:** aucun (vérification).

- [ ] **Step 1: analyze 0**

Run: `cd epilote && /home/melack/flutter/bin/flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Tests complets**

Run: `cd epilote && /home/melack/flutter/bin/flutter test`
Expected: tous verts (nouveaux tests grouping inclus, anciens intacts).

- [ ] **Step 3: Build release**

Run: `cd epilote && /home/melack/flutter/bin/flutter build linux --release`
Expected: `✓ Built build/linux/x64/release/bundle/epilote`.

- [ ] **Step 4: Commit final si diff résiduel** (sinon néant).

---

## Notes de découpage fichiers

- `class_grouping.dart` : pur, ~90 lignes.
- `exam_candidate_grouped.dart` / `stages_grouped.dart` : rendu groupé (<300 lignes chacun).
- Si `exam_session_screen.dart` dépasse 500 lignes après absorption de l'état, extraire les constructeurs de slivers (`_filterBar`, `_bulkBarSliver`) dans un part-file `exam_session_slivers.dart`.

## Auto-revue (couverture spec)

- Regroupement classe + en-têtes pliables → Tasks 3, 6.
- Virtualisation slivers → Tasks 3, 4, 6.
- Filière (modèle/badge/colonne/filtre) → Tasks 2, 3, 4, 5, 6.
- Lot jamais à l'écran → respecté (aucune tâche ne l'affiche).
- KPI/actions/dialogues inchangés → déplacement, pas réécriture (Task 4).
- Tests logique d'aplatissement → Task 1.
