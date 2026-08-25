# Cockpit examens nationaux & archive sourçable — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rendre le cockpit examens du ministère exploitable examen par examen, et faire de l'archive DEC un dossier qui se source sans cul-de-sac.

**Architecture:** Toute l'agrégation passe de « calculée dans le `FutureProvider` » à « fonctions pures sur une liste de lignes candidat ». Le provider fait UNE requête, garde les lignes brutes, et les vues recalculent en mémoire selon l'examen sélectionné. Conséquence : le filtre examen ne coûte aucun aller-retour serveur, et toute la logique devient testable sans Supabase (pattern déjà en place dans `exam_stats.dart`).

**Tech Stack:** Flutter · Riverpod · Supabase (`supabase.from()` direct — `admin_groupe` est online) · Syncfusion Charts · `OfficialPdfKit` / `showPdfPreviewDialog`.

**Spec:** `docs/superpowers/specs/2026-07-28-examens-nationaux-cockpit-design.md`

## Global Constraints

- Espace `admin_groupe` = **online, `supabase.from()` uniquement**. Jamais PowerSync, jamais de gate licence.
- **Aucune migration SQL.** Toutes les colonnes existent déjà.
- Tout fichier Dart reste **≤ 500 lignes** (alerte à 400). Découpe le long des coutures de cohésion.
- `flutter analyze` doit rester à **0 issue**.
- Taux inconnu ⇒ `null`, affiché « en attente ». **Jamais 0 %.** Règle unique : `isKnownExamResult()` de `lib/features/examens/models/exam_stats.dart` — ne jamais recopier la liste des résultats connus.
- Un pourcentage s'affiche **toujours avec son assiette** (`47 admis / 112 connus`).
- Colonne filière = **`classes.filiere_label`**, jamais `filiere_id`.
- Syncfusion : `primaryXAxis: CategoryAxis` ← `xValueMapper` String ; `primaryYAxis: NumericAxis` ← `yValueMapper` double. Inverser crache `String is not a subtype of num`.
- PDF : listes construites en **lignes**, jamais en `frame()` — un `frame()` ne se scinde pas entre pages et lève `TooManyPages`.
- API : `inFilter()` (pas `in_()`), `.withValues(alpha:)` (pas `withOpacity`), `CardThemeData` (pas `CardTheme`).
- Commandes depuis `epilote/` : `flutter test test/<fichier>.dart`, `flutter analyze`.
- Chaque commit finit par `Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>`.

---

## Structure des fichiers

**Chantier A — « Résultats & archives »**

| Fichier | Responsabilité |
|---|---|
| `providers/exam_archives_provider.dart` | *modif* — `keepAlive()` sur les 2 providers |
| `screens/admin_exam_results_screen.dart` | *modif* — un seul `when`, distribue les données aux sections |
| `widgets/exam_history_section.dart`, `exam_archives_section.dart`, `exam_figures_section.dart` | *modif* — reçoivent leurs données en paramètres |
| `widgets/exam_publication_dialog.dart` | *modif* — retourne le `pubId`, accepte un préremplissage |
| `widgets/exam_figure_fields.dart` | **neuf** — champs de saisie partagés (~200 l) |
| `widgets/exam_figure_panel.dart` | *modif* — bouton « Déposer la pièce… », consomme les champs partagés |
| `widgets/exam_figure_batch_panel.dart` | **neuf** — saisie groupée depuis une pièce (~300 l) |

**Chantier B — « Examens nationaux »**

| Fichier | Responsabilité |
|---|---|
| `providers/ministry_exam_rows.dart` | **neuf** — la ligne candidat + toutes les fonctions pures d'agrégation (~320 l) |
| `providers/admin_exams_provider.dart` | *modif* — requête unique → lignes brutes ; `examFilterProvider` |
| `widgets/exam_scope_chips.dart` | **neuf** — barre de puces examen (~110 l) |
| `widgets/admin_exams_views.dart` | *modif* — graphe entonnoir |
| `widgets/admin_exams_breakdown.dart` | *modif* — lignes cliquables |
| `widgets/exam_axis_drilldown_modal.dart` | **neuf** — écoles de l'axe (~280 l) |
| `services/exam_axis_pdf_service.dart` | **neuf** — export PDF axe + périmètre (~250 l) |
| `providers/school_exam_candidates_provider.dart` | **neuf** — candidats d'une école (~180 l) |
| `widgets/school_candidates_section.dart` | **neuf** — liste groupée + filtres (~320 l) |
| `widgets/admin_exam_school_modal.dart` | *modif* — accueille la section, relance détaillée |

Racine commune : `epilote/lib/features/admin_groupe/`.

---

## Task 1 : Le chargement de « Résultats & archives » ne ment plus

**Files:**
- Modify: `epilote/lib/features/admin_groupe/providers/exam_archives_provider.dart:258,307`
- Modify: `epilote/lib/features/admin_groupe/screens/admin_exam_results_screen.dart`
- Modify: `epilote/lib/features/admin_groupe/widgets/exam_history_section.dart`
- Modify: `epilote/lib/features/admin_groupe/widgets/exam_archives_section.dart`
- Modify: `epilote/lib/features/admin_groupe/widgets/exam_figures_section.dart`

**Interfaces:**
- Produces: `ExamHistorySection({required List<OfficialFigure> figures})`, `ExamArchivesSection({required List<ExamPublication> publications, required List<OfficialFigure> figures})`, `ExamFiguresSection({required List<OfficialFigure> figures})` — les trois cessent de `watch` les deux providers de données.

- [ ] **Step 1 : `keepAlive` sur les deux providers**

Dans `exam_archives_provider.dart`, ajouter `ref.keepAlive();` en première ligne du corps de `examPublicationsProvider` (l.258) et de `officialFiguresProvider` (l.307), à l'identique de `archiveSessionsProvider` (l.235) :

```dart
final examPublicationsProvider =
    FutureProvider.autoDispose<List<ExamPublication>>((ref) async {
  ref.keepAlive();
  final client = ref.watch(supabaseClientProvider);
```

- [ ] **Step 2 : l'écran résout une fois et distribue**

Dans `admin_exam_results_screen.dart`, remplacer les deux `.valueOrNull ?? const []` par une résolution conjointe. Le corps devient :

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final figuresAsync = ref.watch(officialFiguresProvider);
  final pubsAsync = ref.watch(examPublicationsProvider);

  return AppShell(
    title: 'Résultats & archives',
    child: _resolve(context, ref, figuresAsync, pubsAsync),
  );
}

/// Une page, un seul état de chargement. Tant que l'une des deux sources n'a
/// pas répondu, on montre un squelette : afficher « aucun chiffre officiel
/// enregistré » pendant que la requête tourne, c'est répondre à côté — le
/// ministère lit une archive vide qui ne l'est pas.
Widget _resolve(
  BuildContext context,
  WidgetRef ref,
  AsyncValue<List<OfficialFigure>> figuresAsync,
  AsyncValue<List<ExamPublication>> pubsAsync,
) {
  final error = figuresAsync.error ?? pubsAsync.error;
  if (error != null) {
    return ExamsErrorView(
      message: '$error',
      onRetry: () {
        ref.invalidate(officialFiguresProvider);
        ref.invalidate(examPublicationsProvider);
      },
    );
  }
  final figures = figuresAsync.valueOrNull;
  final pubs = pubsAsync.valueOrNull;
  // `valueOrNull` non nul = on a déjà des données : un rafraîchissement ne
  // doit pas revider la page sous les yeux de l'utilisateur.
  if (figures == null || pubs == null) return const ListShimmer();
  return _Content(figures: figures, publications: pubs);
}
```

`_Content` est un `StatelessWidget` privé qui reprend l'actuel `SingleChildScrollView` et passe `figures`/`publications` à `KpiGrid(items: _kpis(figures, pubs))`, `ExamHistorySection(figures: figures)`, `ExamArchivesSection(publications: pubs, figures: figures)`, `ExamFiguresSection(figures: figures)`.

`ExamsErrorView` et `ListShimmer` sont déjà importés via `core/widgets/list_chrome.dart` et `widgets/admin_exams_views.dart` — ajouter l'import de `admin_exams_views.dart` pour `ExamsErrorView`.

- [ ] **Step 3 : les trois sections reçoivent leurs données**

Dans chacune, remplacer le `ref.watch(officialFiguresProvider)` / `ref.watch(examPublicationsProvider)` par un champ de constructeur.

- `exam_history_section.dart:34` : `final figures = ref.watch(officialFiguresProvider).valueOrNull ?? const [];` → `final figures = this.figures;` (champ `final List<OfficialFigure> figures;`).
- `exam_archives_section.dart:29-30` : supprimer le `pubs.when(...)` de la l.52 — l'état de chargement est désormais porté par l'écran ; le corps du `data:` devient le corps direct.
- `exam_figures_section.dart:30` : idem, supprimer `async.when(...)` et travailler sur `figures`.

`archiveSessionsProvider` reste `watch`é localement dans `exam_figures_section.dart` : il a déjà son `keepAlive` et sert de référentiel, pas de donnée de page.

- [ ] **Step 4 : vérifier**

```bash
cd epilote && flutter analyze
```
Attendu : `No issues found!`

- [ ] **Step 5 : commit**

```bash
git add epilote/lib/features/admin_groupe
git commit -m "$(cat <<'EOF'
fix(ministère): l'archive cesse d'afficher une page vide qu'elle n'est pas

Les deux providers de « Résultats & archives » étaient autoDispose sans
keepAlive : chaque aller-retour les détruisait et relançait les requêtes.
Et l'écran rendait `?? const []`, donc pendant ce temps il affichait une
page complète et FAUSSE — KPI à zéro, « aucun chiffre officiel
enregistré », historique vide — avant de basculer sur les vraies données.

Une seule résolution pour toute la page, un vrai squelette pendant le
premier chargement, et rien ne se revide sur un rafraîchissement. Les
trois sections reçoivent leurs données en paramètres : elles cessent de
s'abonner quatre fois à deux requêtes, et deviennent testables sans base.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2 : Déposer la pièce depuis le panneau de relevé

**Files:**
- Modify: `epilote/lib/features/admin_groupe/widgets/exam_publication_dialog.dart:35-36,143,192`
- Modify: `epilote/lib/features/admin_groupe/widgets/exam_figure_panel.dart:299-304,362-419`
- Modify: `epilote/lib/features/admin_groupe/widgets/exam_figures_section.dart`

**Interfaces:**
- Produces: `Future<String?> showExamPublicationDialog(BuildContext context, {String? sessionId, PubScope? scope, String? department, String? schoolId})` — renvoie l'id de la publication déposée, `null` si annulé.

- [ ] **Step 1 : la pièce déposée remonte son identifiant**

Dans `exam_publication_dialog.dart` :

```dart
/// Renvoie l'id de la publication déposée — `null` si l'utilisateur annule.
/// Le panneau de relevé s'en sert pour rattacher immédiatement le chiffre à
/// la pièce qui vient d'être archivée : sans cette valeur de retour, il
/// faudrait ressortir, rouvrir, retrouver la pièce dans une liste.
Future<String?> showExamPublicationDialog(
  BuildContext context, {
  String? sessionId,
  PubScope? scope,
  String? department,
  String? schoolId,
}) =>
    showAdminSidePanel<String>(
      context,
      builder: (_) => _PublicationPanel(
        sessionId: sessionId,
        scope: scope,
        department: department,
        schoolId: schoolId,
      ),
    );
```

Le widget interne initialise son état depuis ces paramètres (`late String? _sessionId = widget.sessionId ?? …`, idem scope/département/école), et la ligne 192 `Navigator.of(context).pop();` devient `Navigator.of(context).pop(pubId);` — `pubId` est déjà en portée (l.143).

- [ ] **Step 2 : le bouton dans `_SourcePicker`**

`_SourcePicker` gagne deux paramètres : `final Future<void> Function() onDeposit;` et garde `sessionChosen`. Ses trois états deviennent :

```dart
@override
Widget build(BuildContext context) {
  if (!sessionChosen) {
    return _note('Choisissez d\'abord la session : les pièces proposées sont '
        'celles qui la couvrent.');
  }
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (publications.isEmpty)
      _note('Aucune pièce archivée pour cette session — déposez-la ici, elle '
          'sera rattachée à ce chiffre.')
    else
      SizedBox(
        height: 42,
        child: ListFilterDropdown(
          icon: Icons.attach_file_rounded,
          label: 'Pièce',
          value: selected ?? '',
          items: {
            '': 'Aucune — chiffre non sourcé',
            for (final p in publications) p.id: '${p.scopeLabel} · ${p.title}',
          },
          onChanged: (v) => onChanged(v.isEmpty ? null : v),
        ),
      ),
    const SizedBox(height: 8),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onDeposit,
        icon: const Icon(Icons.upload_file_rounded, size: 16),
        label: const Text('Déposer la pièce…'),
        style: TextButton.styleFrom(foregroundColor: kNavy),
      ),
    ),
  ]);
}
```

- [ ] **Step 3 : le panneau enchaîne dépôt → rattachement**

Dans `_State` de `exam_figure_panel.dart` :

```dart
/// Dépose la publication SANS quitter le relevé en cours, et la rattache.
/// Le périmètre déjà choisi pour le chiffre préremplit celui de la pièce :
/// on ne ressaisit pas « Pool » deux fois de suite.
Future<void> _depositPiece() async {
  final id = await showExamPublicationDialog(
    context,
    sessionId: _sessionId,
    scope: _scope,
    department: _department,
    schoolId: _schoolId,
  );
  if (id == null || !mounted) return;
  setState(() => _publicationId = id);
}
```

et le `_SourcePicker` de la l.299 reçoit `onDeposit: _depositPiece`.

- [ ] **Step 4 : réparer un chiffre non sourcé depuis la liste**

Dans `exam_figures_section.dart`, la ligne d'un relevé sans source gagne une action explicite. Dans `_FiguresTable`, pour une ligne où `!f.hasSource`, afficher à droite un `TextButton` « Sourcer » qui appelle `showExamFigurePanel(context, figure: f)` — le même panneau, où le bouton « Déposer la pièce… » attend. Le badge « sans source » cesse d'être un reproche muet.

- [ ] **Step 5 : vérifier**

```bash
cd epilote && flutter analyze
```
Attendu : `No issues found!`

- [ ] **Step 6 : commit**

```bash
git add epilote/lib/features/admin_groupe
git commit -m "$(cat <<'EOF'
feat(ministère): sourcer un chiffre cesse d'être un cul-de-sac

La DEC/DSIC produit toujours un document — le ministère publie, les écoles
viennent chercher les listes. Pourtant le panneau de relevé ne proposait que
les pièces DÉJÀ archivées pour la session : sans elles, on enregistrait un
chiffre non sourcé et plus rien n'y ramenait. Le KPI « Chiffres sans source »
comptait une dette qu'aucun écran ne permettait de rembourser.

Le dépôt se fait maintenant depuis le relevé lui-même, périmètre prérempli,
et la pièce se rattache au retour. Un chiffre déjà enregistré sans source se
répare par le même chemin, atteignable en un clic depuis sa ligne.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3 : Saisie groupée des chiffres d'une pièce

**Files:**
- Create: `epilote/lib/features/admin_groupe/widgets/exam_figure_fields.dart`
- Create: `epilote/lib/features/admin_groupe/widgets/exam_figure_batch_panel.dart`
- Modify: `epilote/lib/features/admin_groupe/widgets/exam_figure_panel.dart`
- Modify: `epilote/lib/features/admin_groupe/widgets/exam_archives_section.dart`
- Test: `epilote/test/exam_figure_batch_test.dart`

**Interfaces:**
- Consumes: `showExamPublicationDialog(...) → Future<String?>` (Task 2).
- Produces: `class FigureDraft` (valeur immuable d'un relevé en cours) + `FigureDraft resetForNext(FigureDraft d)` dans `exam_figure_fields.dart` ; `Future<void> showExamFigureBatchPanel(BuildContext, {required ExamPublication publication})`.

- [ ] **Step 1 : écrire le test qui échoue**

`epilote/test/exam_figure_batch_test.dart` :

```dart
import 'package:epilote/features/admin_groupe/widgets/exam_figure_fields.dart';
import 'package:epilote/features/admin_groupe/providers/exam_archives_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SAISIE GROUPÉE — une publication de la DEC porte des dizaines de chiffres.
//
//  Ce qui doit SURVIVRE d'un relevé au suivant : la pièce, la session, la date
//  de publication. Ce qui doit DISPARAÎTRE : le périmètre et les nombres. Se
//  tromper de côté, c'est soit ressaisir la pièce trente fois, soit recopier
//  par inadvertance les effectifs du Pool sur la Bouenza.
// ════════════════════════════════════════════════════════════════════════════
void main() {
  final base = FigureDraft(
    sessionId: 'sess-1',
    publicationId: 'pub-1',
    publishedAt: DateTime(2026, 7, 24),
    scope: PubScope.departement,
    department: 'Pool',
    schoolId: null,
    filiereLabel: 'F5',
    registered: 120,
    present: 112,
    admitted: 47,
    rate: null,
  );

  test('la pièce, la session et la date survivent au relevé suivant', () {
    final next = resetForNext(base);
    expect(next.publicationId, 'pub-1');
    expect(next.sessionId, 'sess-1');
    expect(next.publishedAt, DateTime(2026, 7, 24));
  });

  test('le périmètre et les nombres se vident', () {
    final next = resetForNext(base);
    expect(next.scope, PubScope.national);
    expect(next.department, isNull);
    expect(next.schoolId, isNull);
    expect(next.filiereLabel, isEmpty);
    expect(next.registered, isNull);
    expect(next.present, isNull);
    expect(next.admitted, isNull);
    expect(next.rate, isNull);
  });

  test('un relevé sans aucun chiffre n\'en est pas un', () {
    expect(base.isComplete, isTrue);
    expect(resetForNext(base).isComplete, isFalse);
  });

  test('le taux se déduit des effectifs, sinon c\'est le taux publié', () {
    expect(base.retainedRate, closeTo(47 / 112 * 100, 0.001));
    final published = base.copyWith(present: null, admitted: null, rate: 63.5);
    expect(published.retainedRate, 63.5);
  });
}
```

- [ ] **Step 2 : lancer le test, vérifier qu'il échoue**

```bash
cd epilote && flutter test test/exam_figure_batch_test.dart
```
Attendu : ÉCHEC — `exam_figure_fields.dart` n'existe pas.

- [ ] **Step 3 : `exam_figure_fields.dart`**

Contient (a) le modèle `FigureDraft` + `resetForNext` + `copyWith` + `isComplete` + `retainedRate`, (b) les widgets de saisie communs extraits de `exam_figure_panel.dart` : `FigureNumberField`, `FigureTextField`, `FigureScopeFields` (le trio ScopePicker / département / établissement), `FigureCountsRow` (inscrits · présents · admis + taux publié + aperçu du taux retenu).

```dart
/// Un relevé en cours de saisie. Immuable : la saisie groupée enchaîne les
/// relevés en repartant d'une copie amputée du précédent, jamais en mutant
/// des contrôleurs à la main — c'est ce qui garantit qu'aucun effectif ne
/// traîne d'un département sur le suivant.
class FigureDraft {
  const FigureDraft({
    required this.sessionId,
    required this.publicationId,
    required this.publishedAt,
    required this.scope,
    required this.department,
    required this.schoolId,
    required this.filiereLabel,
    required this.registered,
    required this.present,
    required this.admitted,
    required this.rate,
  });

  final String? sessionId;
  final String? publicationId;
  final DateTime? publishedAt;
  final PubScope scope;
  final String? department;
  final String? schoolId;
  final String filiereLabel;
  final int? registered;
  final int? present;
  final int? admitted;
  final double? rate;

  bool get hasCounts => present != null && admitted != null;

  /// Le taux retenu : les effectifs priment, sinon le pourcentage publié fait
  /// foi tel quel. `null` = ce n'est pas encore un relevé.
  double? get retainedRate =>
      hasCounts ? admitted! / present! * 100 : rate;

  bool get isComplete => retainedRate != null;

  FigureDraft copyWith({...}) => ...;
}

/// Ce qui survit d'un relevé au suivant : la PIÈCE, la session, la date. Le
/// périmètre et les nombres repartent de zéro.
FigureDraft resetForNext(FigureDraft d) => FigureDraft(
      sessionId: d.sessionId,
      publicationId: d.publicationId,
      publishedAt: d.publishedAt,
      scope: PubScope.national,
      department: null,
      schoolId: null,
      filiereLabel: '',
      registered: null,
      present: null,
      admitted: null,
      rate: null,
    );
```

`copyWith` doit distinguer « non fourni » de « mis à null » pour les champs nullables : utiliser des sentinelles (`Object? department = _unset`).

- [ ] **Step 4 : lancer le test, vérifier qu'il passe**

```bash
cd epilote && flutter test test/exam_figure_batch_test.dart
```
Attendu : 4 tests PASS.

- [ ] **Step 5 : le panneau de saisie groupée**

`exam_figure_batch_panel.dart` — un `AdminSidePanel` dont :
- l'en-tête épingle la pièce (`publication.title`, sa session, sa date) dans un encart figé qui ne se vide jamais ;
- le corps est `FigureScopeFields` + `FigureCountsRow` sur le `FigureDraft` courant ;
- sous le formulaire, la liste des relevés déjà enregistrés **pour cette pièce dans cette séance** (`Wrap` de puces « National · 51,61 % », « Pool · 63,50 % »), chacune retirable via `archiveActionsProvider.removeFigure` ;
- le pied porte **« Enregistrer et suivant »** (primaire) et « Terminer ».

« Enregistrer et suivant » appelle `recordFigure(...)` avec le draft, puis `setState(() => _draft = resetForNext(_draft))` et ajoute une puce. Le focus revient sur le sélecteur de périmètre.

- [ ] **Step 6 : les deux points d'entrée**

1. `exam_publication_dialog.dart`, après un dépôt réussi : au lieu de simplement `pop(pubId)`, afficher un `showAdminConfirm` « Relever les chiffres de cette pièce maintenant ? » → si oui, ouvrir `showExamFigureBatchPanel`. **Sauf** quand le panneau a été ouvert depuis le relevé (Task 2) : dans ce cas on retourne au relevé en cours. Distinguer via un paramètre `bool offerBatch = true`, passé à `false` par `_depositPiece`.
2. `exam_archives_section.dart` : le menu d'une pièce archivée gagne « Relever les chiffres » → `showExamFigureBatchPanel(context, publication: pub)`.

- [ ] **Step 7 : vérifier**

```bash
cd epilote && flutter test test/exam_figure_batch_test.dart && flutter analyze
```
Attendu : tests PASS, `No issues found!`

- [ ] **Step 8 : commit**

```bash
git add epilote/lib epilote/test
git commit -m "$(cat <<'EOF'
feat(ministère): relever une publication d'un trait, pas chiffre par chiffre

Une publication de la DEC porte le national, puis chacun des douze
départements, puis les établissements. Le panneau imposait un aller-retour
complet par chiffre : rouvrir, rechoisir la session, retrouver la pièce.

La pièce, la session et la date restent désormais épinglées d'un relevé à
l'autre ; seuls le périmètre et les nombres se vident. Le choix de ce qui
survit est le cœur du sujet : garder les effectifs recopierait le Pool sur
la Bouenza, et c'est précisément ce que le test verrouille.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4 : Le cockpit décompose par examen

**Files:**
- Create: `epilote/lib/features/admin_groupe/providers/ministry_exam_rows.dart`
- Modify: `epilote/lib/features/admin_groupe/providers/admin_exams_provider.dart`
- Test: `epilote/test/admin_exams_scope_test.dart`

**Interfaces:**
- Produces:
  - `class MinistryCandidateRow` — champs `schoolId, schoolName, department, examCode, examShortName, tutelle, sessionId, filiereLabel, dossierStatus, result, hasAttestation` ; getters `isComplete`, `isSubmitted`, `hasKnownResult`, `isAdmitted`.
  - `class MinistryTransmissionRow` — `schoolId, status, transmittedAt`.
  - `class ExamOption` — `code, shortName, candidates`.
  - `MinistryExamsData buildMinistryExamsData({required List<MinistryCandidateRow> rows, required List<MinistryTransmissionRow> transmissions, required int internshipsTotal, required int attestationsTotal, required String? yearLabel, String? examCode})`
  - `MinistryExamsData.forExam(String? code)`, `MinistryExamsData.examOptions`, `MinistryExamsData.selectedExamCode`, `MinistryExamsData.showsInternshipKpis`
  - `final examFilterProvider = StateProvider.autoDispose<String?>((_) => null);`

- [ ] **Step 1 : écrire le test qui échoue**

`epilote/test/admin_exams_scope_test.dart` :

```dart
import 'package:epilote/features/admin_groupe/providers/admin_exams_provider.dart';
import 'package:epilote/features/admin_groupe/providers/ministry_exam_rows.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  UN CHIFFRE PAR EXAMEN — la correction de justesse du cockpit.
//
//  La DEC proclame BET 77,59 %, BEP 74,29 %, BAC T/P 51,61 %. Elle ne publie
//  JAMAIS un taux tous examens confondus, et pour cause : additionner un
//  brevet et un baccalauréat ne décrit aucune réalité. Le cockpit le faisait.
//
//  Deuxième règle, moins visible : une attestation de stage ne conditionne que
//  les bacs technique et professionnel. Afficher « Bacs bloqués » pendant
//  qu'on regarde le BET, c'est promener une alerte hors de son périmètre.
// ════════════════════════════════════════════════════════════════════════════
MinistryCandidateRow _row({
  String schoolId = 's1',
  String schoolName = 'CET de Kinkala',
  String? department = 'Pool',
  String examCode = 'BET',
  String examShortName = 'BET',
  String? filiere = 'Mécanique',
  String dossier = 'valide',
  String result = 'admis',
  bool hasAttestation = true,
}) =>
    MinistryCandidateRow(
      schoolId: schoolId,
      schoolName: schoolName,
      department: department,
      examCode: examCode,
      examShortName: examShortName,
      tutelle: 'metp',
      sessionId: 'sess-$examCode',
      filiereLabel: filiere,
      dossierStatus: dossier,
      result: result,
      hasAttestation: hasAttestation,
    );

void main() {
  final rows = [
    _row(),                                                    // BET admis
    _row(result: 'ajourne'),                                   // BET ajourné
    _row(result: 'en_attente'),                                // BET non proclamé
    _row(examCode: 'BAC_T', examShortName: 'BAC T',
        filiere: 'Électrotechnique', hasAttestation: false),   // BAC T admis, sans stage
    _row(examCode: 'BAC_T', examShortName: 'BAC T',
        filiere: 'Électrotechnique', result: 'ajourne'),
  ];

  MinistryExamsData build({String? examCode}) => buildMinistryExamsData(
        rows: rows,
        transmissions: const [],
        internshipsTotal: 10,
        attestationsTotal: 4,
        yearLabel: '2025-2026',
        examCode: examCode,
      );

  test('sans filtre, le cockpit voit tout le réseau', () {
    final d = build();
    expect(d.totalCandidates, 5);
    expect(d.totalAdmitted, 2);
    expect(d.totalWithResult, 4); // en_attente ne compte pas
  });

  test('filtrer sur un examen ne garde que ses candidats', () {
    final d = build(examCode: 'BET');
    expect(d.totalCandidates, 3);
    expect(d.totalAdmitted, 1);
    expect(d.totalWithResult, 2);
    expect(d.successRate, closeTo(50, 0.001));
  });

  test('forExam recompose sans requête et reste cohérent', () {
    expect(build().forExam('BAC_T').totalCandidates, 2);
    expect(build(examCode: 'BET').forExam(null).totalCandidates, 5);
  });

  test('la ventilation suit le périmètre choisi', () {
    final bet = build(examCode: 'BET');
    expect(bet.byFiliere.map((l) => l.label), ['Mécanique']);
    final bac = build(examCode: 'BAC_T');
    expect(bac.byFiliere.map((l) => l.label), ['Électrotechnique']);
  });

  test('les KPI stages ne s\'affichent que sur les bacs technique et pro', () {
    expect(build().showsInternshipKpis, isTrue);          // « Tous »
    expect(build(examCode: 'BAC_T').showsInternshipKpis, isTrue);
    expect(build(examCode: 'BET').showsInternshipKpis, isFalse);
  });

  test('bacs bloqués = bac pro sans attestation, jamais un BET', () {
    expect(build().bacBlocked, 1);
    expect(build(examCode: 'BAC_T').bacBlocked, 1);
    expect(build(examCode: 'BET').bacBlocked, 0);
  });

  test('les puces d\'examen restent stables quel que soit le filtre', () {
    final codes = build(examCode: 'BET').examOptions.map((e) => e.code);
    expect(codes, containsAll(<String>['BET', 'BAC_T']));
    expect(build(examCode: 'BET').examOptions.first.candidates, 3); // trié par effectif
  });

  test('un taux sans résultat connu reste null, jamais zéro', () {
    final none = buildMinistryExamsData(
      rows: [_row(result: 'en_attente')],
      transmissions: const [],
      internshipsTotal: 0,
      attestationsTotal: 0,
      yearLabel: null,
    );
    expect(none.successRate, isNull);
    expect(none.byFiliere.single.rate, isNull);
  });
}
```

- [ ] **Step 2 : lancer le test, vérifier qu'il échoue**

```bash
cd epilote && flutter test test/admin_exams_scope_test.dart
```
Attendu : ÉCHEC — `ministry_exam_rows.dart` n'existe pas.

- [ ] **Step 3 : `ministry_exam_rows.dart`**

Le modèle de ligne et l'agrégation pure. Points d'attention :

- `hasKnownResult` délègue à `isKnownExamResult(result)` de `exam_stats.dart` — **ne pas** recopier `result != 'en_attente'`, la règle est unique.
- `isComplete` = `dossierStatus != 'incomplet'` ; `isSubmitted` = `dossierStatus == 'depose' || dossierStatus == 'valide'` (inchangé).
- `_kBacProInternship = {'BAC_T', 'BAC_P'}` déménage ici depuis `admin_exams_provider.dart`.
- `showsInternshipKpis` = `examCode == null || _kBacProInternship.contains(examCode)`.
- `examOptions` se calcule sur **toutes** les lignes, jamais sur les lignes filtrées : les puces ne doivent pas disparaître quand on en sélectionne une.
- `byFiliere` / `byDepartment` passent par `groupExamLines(...)` de `exam_stats.dart`.
- `sessionCount` = nombre de `sessionId` distincts **dans le périmètre**.
- `MinistryExamsData` conserve `rows` et `transmissions` pour que `forExam()` soit un simple `buildMinistryExamsData(rows: rows, …, examCode: code)`.

- [ ] **Step 4 : brancher le provider**

`adminExamsProvider` garde ses trois requêtes actuelles (candidats, transmissions, stages) et **cesse d'agréger** : il construit `List<MinistryCandidateRow>` + `List<MinistryTransmissionRow>` et appelle `buildMinistryExamsData(...)`. La colonne `student_id` sert à croiser `studentsWithAttestation` pour remplir `hasAttestation` sur chaque ligne.

Ajouter en fin de fichier :

```dart
/// Examen sélectionné dans le cockpit — `null` = tous les examens.
/// Vit hors du FutureProvider : changer de périmètre ne doit RIEN redemander
/// au serveur, tout se recalcule sur les lignes déjà en mémoire.
final examFilterProvider = StateProvider.autoDispose<String?>((_) => null);
```

- [ ] **Step 5 : lancer les tests, vérifier qu'ils passent**

```bash
cd epilote && flutter test test/admin_exams_scope_test.dart test/ministry_school_exam_test.dart && flutter analyze
```
Attendu : tous PASS, `No issues found!`

- [ ] **Step 6 : commit**

```bash
git add epilote/lib epilote/test
git commit -m "$(cat <<'EOF'
refactor(ministère): un chiffre par examen, et non un chiffre pour tous

La DEC proclame BET 77,59 %, BEP 74,29 %, BAC T/P 51,61 %. Elle ne publie
nulle part un taux tous examens confondus — additionner un brevet et un
baccalauréat ne décrit aucune réalité. Le cockpit le faisait pourtant sur
ses huit KPI et ses deux ventilations.

L'agrégation quitte le FutureProvider pour des fonctions pures sur des
lignes candidat. Le périmètre devient un paramètre : changer d'examen ne
redemande rien au serveur, et toute la logique se teste sans base.

Effet immédiat : « Stages du réseau » et « Bacs bloqués » ne suivent plus
un candidat au BET, à qui aucune attestation n'a jamais été demandée.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5 : Le sélecteur d'examen

**Files:**
- Create: `epilote/lib/features/admin_groupe/widgets/exam_scope_chips.dart`
- Modify: `epilote/lib/features/admin_groupe/screens/admin_exams_screen.dart`

**Interfaces:**
- Consumes: `ExamOption`, `examFilterProvider` (Task 4).
- Produces: `ExamScopeChips({required List<ExamOption> options, required String? selected, required ValueChanged<String?> onChanged})`.

- [ ] **Step 1 : la barre de puces**

`exam_scope_chips.dart` — un `Wrap` de `ChoiceChip`. « Tous les examens » d'abord (avec le total), puis une puce par examen triée par effectif décroissant, portant `shortName` et son nombre de candidats. Puce sélectionnée : fond `kNavy`, texte blanc, `showCheckmark: false`. Non sélectionnée : fond `kCardBg`, bordure `kBorder`.

- [ ] **Step 2 : l'écran se recadre**

Dans `admin_exams_screen.dart`, après `async.when(... data: (d) {`, insérer :

```dart
final code = ref.watch(examFilterProvider);
final scoped = d.forExam(code);
```

Puis **tout** ce qui suit consomme `scoped` au lieu de `d` : `_kpis(scoped)`, le graphe, `ExamBreakdownRow`, `_filter(scoped.schools)`, `ListResultHeader`, `ExamsRemindButton`. Les puces se construisent sur `d.examOptions` (jamais `scoped`).

`_kpis` n'émet les deux KPI stages/bacs que si `d.showsInternshipKpis`.

Placer `ExamScopeChips` juste sous le titre, avant `KpiGrid`.

- [ ] **Step 3 : vérifier**

```bash
cd epilote && flutter analyze
```
Attendu : `No issues found!`

- [ ] **Step 4 : commit**

```bash
git add epilote/lib/features/admin_groupe
git commit -m "$(cat <<'EOF'
feat(ministère): le cockpit se lit examen par examen

Une barre de puces sous le titre recadre toute la page — KPI, graphe,
réussite par filière, par département, tableau des écoles. Sur « Tous »,
la campagne d'ensemble ; sur un examen, ses seuls candidats.

Les puces se construisent toujours sur l'ensemble du réseau : sélectionner
le BET ne doit pas faire disparaître le BAC T de la barre, sinon on ne
peut plus en sortir.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6 : Le graphe raconte la campagne

**Files:**
- Modify: `epilote/lib/features/admin_groupe/providers/ministry_exam_rows.dart`
- Modify: `epilote/lib/features/admin_groupe/widgets/admin_exams_views.dart`
- Test: `epilote/test/admin_exams_scope_test.dart` (ajout)

**Interfaces:**
- Produces: `class ExamFunnelBar { final String label; final int declared, submitted, admitted; }` ; `List<ExamFunnelBar> funnelByExam(List<MinistryCandidateRow>)` ; `List<ExamFunnelBar> funnelByDepartment(List<MinistryCandidateRow>)`. `ExamChart({required List<ExamFunnelBar> bars, required String? yearLabel, required bool byDepartment})`.

- [ ] **Step 0 : charger la skill dataviz**

Avant d'écrire la moindre ligne de graphique, invoquer la skill `dataviz` et en appliquer la palette et la grammaire (séries, légende, axes, tooltip).

- [ ] **Step 1 : écrire le test qui échoue**

Ajouter à `test/admin_exams_scope_test.dart` :

```dart
  test('l\'entonnoir décroît : déclarés ≥ déposés ≥ admis', () {
    final bars = funnelByExam(rows);
    final bet = bars.firstWhere((b) => b.label == 'BET');
    expect(bet.declared, 3);
    expect(bet.submitted, 3);   // dossier « valide » = déposé
    expect(bet.admitted, 1);
    for (final b in bars) {
      expect(b.declared, greaterThanOrEqualTo(b.submitted));
      expect(b.submitted, greaterThanOrEqualTo(b.admitted));
    }
  });

  test('sur un examen, l\'entonnoir se lit par département', () {
    final bars = funnelByDepartment(rows.where((r) => r.examCode == 'BET').toList());
    expect(bars.single.label, 'Pool');
    expect(bars.single.declared, 3);
  });
```

- [ ] **Step 2 : lancer, vérifier l'échec**

```bash
cd epilote && flutter test test/admin_exams_scope_test.dart
```
Attendu : ÉCHEC — `funnelByExam` non défini.

- [ ] **Step 3 : implémenter les deux fonctions**

Dans `ministry_exam_rows.dart`, regroupement par `examShortName` (resp. `department`, défaut `'Non renseigné'`), tri par `declared` décroissant.

- [ ] **Step 4 : lancer, vérifier le passage**

```bash
cd epilote && flutter test test/admin_exams_scope_test.dart
```
Attendu : tous PASS.

- [ ] **Step 5 : refondre `ExamChart`**

Trois `ColumnSeries` groupées (`enableSideBySideSeriesPlacement: true`) : Déclarés · Déposés · Admis. Titre `'Déclarés → déposés → admis'` suffixé de l'année ; sous-titre implicite via l'axe X (examens ou départements selon `byDepartment`).

- légende en bas, `overflowMode: LegendItemOverflowMode.wrap` ;
- `borderRadius: BorderRadius.vertical(top: Radius.circular(5))` ;
- `dataLabelSettings` visible **uniquement** sur la série « Admis » — trois étiquettes par groupe illisibles sinon ;
- `tooltipBehavior` : `TooltipBehavior(enable: true, shared: true)`, qui affiche naturellement l'assiette des trois séries ;
- `animationDuration: 700` ;
- hauteur portée à `300` (trois séries ont besoin de plus d'air que la barre unique).
- l'état vide actuel (aucun candidat) est conservé tel quel.

- [ ] **Step 6 : brancher dans l'écran**

`admin_exams_screen.dart` :

```dart
ExamChart(
  bars: code == null
      ? funnelByExam(scoped.rows)
      : funnelByDepartment(scoped.rows),
  yearLabel: scoped.yearLabel,
  byDepartment: code != null,
),
```

- [ ] **Step 7 : vérifier**

```bash
cd epilote && flutter test test/admin_exams_scope_test.dart && flutter analyze
```
Attendu : PASS, `No issues found!`

- [ ] **Step 8 : commit**

```bash
git add epilote/lib epilote/test
git commit -m "$(cat <<'EOF'
feat(ministère): le graphe montre où la campagne fuit

Une série plate « candidats par examen » ne dit rien qu'un KPI ne dise
déjà. L'entonnoir déclarés → déposés → admis, lui, localise la perte :
un écart entre déclarés et déposés est un retard de dossier qu'on peut
encore rattraper ; un écart entre déposés et admis est un résultat.

Sur « Tous », un groupe par examen. Sur un examen, le même entonnoir par
département — une barre unique n'aurait rien comparé.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7 : Les ventilations deviennent cliquables

**Files:**
- Modify: `epilote/lib/features/admin_groupe/providers/ministry_exam_rows.dart`
- Modify: `epilote/lib/features/admin_groupe/widgets/admin_exams_breakdown.dart`
- Create: `epilote/lib/features/admin_groupe/widgets/exam_axis_drilldown_modal.dart`
- Test: `epilote/test/exam_axis_drilldown_test.dart`

**Interfaces:**
- Produces: `enum ExamAxis { filiere, departement }` ; `class AxisSchoolLine { final String schoolId, schoolName; final int candidates, known, admitted; final bool transmitted; double? get rate; }` ; `List<AxisSchoolLine> schoolsForAxis(List<MinistryCandidateRow> rows, {required ExamAxis axis, required String label, required Set<String> transmittedSchoolIds})` ; `Future<void> showExamAxisDrilldown(BuildContext, {required ExamAxis axis, required String label, required String? examLabel, required List<AxisSchoolLine> schools})`.

- [ ] **Step 1 : écrire le test qui échoue**

`epilote/test/exam_axis_drilldown_test.dart` :

```dart
import 'package:epilote/features/admin_groupe/providers/ministry_exam_rows.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  « MÉCANIQUE 42 % » — ET ENSUITE ?
//
//  La question qui suit une ventilation, c'est toujours « dans quelles
//  écoles ». Une card qui ne répond pas est un constat, pas du pilotage.
//
//  Deux pièges que ces tests verrouillent : une école dont AUCUN résultat
//  n'est proclamé ne vaut pas 0 % (elle n'a pas de taux), et le classement
//  doit ranger les taux inconnus à part — sinon elles occupent le bas du
//  tableau comme si elles étaient sinistrées.
// ════════════════════════════════════════════════════════════════════════════
MinistryCandidateRow _row({
  required String schoolId,
  required String schoolName,
  String? filiere = 'Mécanique',
  String? department = 'Pool',
  String result = 'admis',
}) =>
    MinistryCandidateRow(
      schoolId: schoolId,
      schoolName: schoolName,
      department: department,
      examCode: 'BET',
      examShortName: 'BET',
      tutelle: 'metp',
      sessionId: 'sess-1',
      filiereLabel: filiere,
      dossierStatus: 'valide',
      result: result,
      hasAttestation: true,
    );

void main() {
  final rows = [
    _row(schoolId: 'a', schoolName: 'LT Poaty'),
    _row(schoolId: 'a', schoolName: 'LT Poaty', result: 'ajourne'),
    _row(schoolId: 'b', schoolName: 'CET Owando', result: 'ajourne'),
    _row(schoolId: 'b', schoolName: 'CET Owando', result: 'ajourne'),
    _row(schoolId: 'c', schoolName: 'CET Sibiti', result: 'en_attente'),
    _row(schoolId: 'd', schoolName: 'LT Dolisie', filiere: 'Électrotechnique'),
  ];

  List<AxisSchoolLine> mecanique({Set<String> transmitted = const {'a'}}) =>
      schoolsForAxis(rows,
          axis: ExamAxis.filiere,
          label: 'Mécanique',
          transmittedSchoolIds: transmitted);

  test('l\'axe ne retient que ses propres candidats', () {
    expect(mecanique().map((s) => s.schoolId), isNot(contains('d')));
    expect(mecanique().length, 3);
  });

  test('le meilleur taux vient en tête', () {
    final s = mecanique();
    expect(s.first.schoolName, 'LT Poaty');
    expect(s.first.rate, closeTo(0.5, 0.001));
  });

  test('une école sans résultat proclamé n\'a pas de taux, et non zéro', () {
    final sibiti = mecanique().firstWhere((s) => s.schoolId == 'c');
    expect(sibiti.rate, isNull);
    expect(sibiti.known, 0);
    expect(sibiti.candidates, 1);
  });

  test('les taux inconnus se rangent après les taux connus', () {
    expect(mecanique().last.schoolId, 'c');
  });

  test('l\'assiette accompagne toujours le taux', () {
    final owando = mecanique().firstWhere((s) => s.schoolId == 'b');
    expect(owando.admitted, 0);
    expect(owando.known, 2);
    expect(owando.rate, 0);   // 0 % PROCLAMÉ : celui-là est vrai
  });

  test('une école qui n\'a rien transmis est signalée', () {
    expect(mecanique().firstWhere((s) => s.schoolId == 'a').transmitted, isTrue);
    expect(mecanique().firstWhere((s) => s.schoolId == 'b').transmitted, isFalse);
  });
}
```

- [ ] **Step 2 : lancer, vérifier l'échec**

```bash
cd epilote && flutter test test/exam_axis_drilldown_test.dart
```
Attendu : ÉCHEC — `schoolsForAxis` non défini.

- [ ] **Step 3 : implémenter `schoolsForAxis`**

Filtre sur l'axe (`filiereLabel` ou `department`, comparaison sur valeur trimée ; `'Non renseigné'` correspond aux valeurs vides — même convention que `groupExamLines`), agrège par école, puis trie : **taux connus décroissants d'abord, taux inconnus ensuite** (ordre secondaire : effectif décroissant).

- [ ] **Step 4 : lancer, vérifier le passage**

```bash
cd epilote && flutter test test/exam_axis_drilldown_test.dart
```
Attendu : 6 tests PASS.

- [ ] **Step 5 : la modal**

`exam_axis_drilldown_modal.dart` — `showAdminBottomModal` / `AdminBottomModal` (chrome partagé, `maxWidth: 860`, `heightFactor: 0.8`) :

- titre : le label de l'axe ; sous-titre : `'<n> candidats · <admis>/<connus> connus'` + l'examen si un filtre est actif ;
- corps : une ligne par école — nom, candidats, admis, taux + mini-barre proportionnelle (même code couleur que `ExamRateBreakdown._rateColor`), « en attente » en italique gris si `rate == null` ;
- une école avec `!transmitted` porte un ⚠ et un bouton « Relancer » appelant `ministryExamActionsProvider.remindSchools` ;
- pied : `[Exporter]` (Task 8) + `[Fermer]`.

- [ ] **Step 6 : rendre les lignes cliquables**

Dans `admin_exams_breakdown.dart`, `_RateRow` s'enveloppe dans un `InkWell` (`borderRadius: 6`, `hoverColor` léger) et `ExamRateBreakdown` / `ExamBreakdownRow` reçoivent `required void Function(ExamStatLine) onTap`. Ajouter un `Icons.chevron_right_rounded` discret en fin de ligne — une ligne cliquable qui ne le dit pas ne se clique pas.

`admin_exams_screen.dart` câble :

```dart
ExamBreakdownRow(
  filiere: scoped.byFiliere,
  departement: scoped.byDepartment,
  onTapFiliere: (l) => showExamAxisDrilldown(context,
      axis: ExamAxis.filiere,
      label: l.label,
      examLabel: _examLabel(d, code),
      schools: schoolsForAxis(scoped.rows,
          axis: ExamAxis.filiere,
          label: l.label,
          transmittedSchoolIds: scoped.transmittedSchoolIds)),
  onTapDepartement: (l) => ... ExamAxis.departement ...,
),
```

`MinistryExamsData.transmittedSchoolIds` (`Set<String>`) est ajouté en Task 4 s'il manque : `{for (final t in transmissions) t.schoolId}`.

- [ ] **Step 7 : vérifier**

```bash
cd epilote && flutter test test/exam_axis_drilldown_test.dart && flutter analyze
```
Attendu : PASS, `No issues found!`

- [ ] **Step 8 : commit**

```bash
git add epilote/lib epilote/test
git commit -m "$(cat <<'EOF'
feat(ministère): « Mécanique 42 % » ouvre enfin sur les écoles

Les deux ventilations étaient des culs-de-sac : elles nommaient le problème
sans jamais le localiser. On repartait vers un autre écran, ou on
téléphonait.

Cliquer une ligne ouvre les écoles de l'axe, classées par taux, avec la
relance directement disponible sur celles qui n'ont rien transmis. Rien
n'est redemandé au serveur : ce sont les lignes déjà en mémoire.

Les écoles sans résultat proclamé se rangent APRÈS les taux connus, et non
en bas du classement : ne pas encore savoir n'est pas mal faire.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8 : Export PDF

**Files:**
- Create: `epilote/lib/features/admin_groupe/services/exam_axis_pdf_service.dart`
- Modify: `epilote/lib/features/admin_groupe/widgets/exam_axis_drilldown_modal.dart`
- Modify: `epilote/lib/features/admin_groupe/screens/admin_exams_screen.dart`

**Interfaces:**
- Consumes: `AxisSchoolLine`, `MinistryExamsData` (Tasks 4, 7), `OfficialPdfKit` (`lib/core/services/official_pdf_kit.dart`), `showPdfPreviewDialog` (`lib/core/widgets/pdf_preview_dialog.dart`).
- Produces: `Future<Uint8List> buildAxisPdf({required String axisLabel, required String axisKind, required String? examLabel, required String? yearLabel, required String groupName, required List<AxisSchoolLine> schools})` et `Future<Uint8List> buildScopePdf({required MinistryExamsData data, required String? examLabel, required String groupName})`.

- [ ] **Step 1 : le service**

Suivre le gabarit de `exam_statistics_pdf_service.dart` (en-tête officiel, mêmes marges). Corps :

- un bandeau de synthèse (candidats, admis/connus, taux — ou « en attente ») ;
- **la liste d'écoles en lignes de tableau, jamais en `frame()`** — un `frame()` ne se scinde pas et lève `TooManyPages` dès qu'un axe dépasse une page ;
- pied de page : date d'édition + mention « chiffres de la plateforme, distincts des résultats proclamés par la DEC ». Cette mention n'est pas décorative : sans elle, un PDF sorti du cockpit peut se confondre avec une publication officielle.

`buildScopePdf` produit la même chose au niveau page : KPI du périmètre, les deux ventilations, puis le tableau des écoles.

- [ ] **Step 2 : les deux boutons**

Un seul intitulé, **« Exporter »**, avec `Icons.picture_as_pdf_rounded` :
- pied de la modal de drill-down → `buildAxisPdf` → `showPdfPreviewDialog` ;
- barre d'actions de l'écran, à côté de `ListResultHeader` → `buildScopePdf` → `showPdfPreviewDialog`.

L'aperçu porte déjà imprimer et enregistrer : ne pas ajouter d'autres boutons, et **pas de « partager »** (aucun canal sortant réel ; la relance par notification reste le seul geste sortant de cet écran).

`groupName` se lit sur `adminDashboardProvider.valueOrNull?.groupName` (motif déjà employé `exam_history_section.dart:116`).

- [ ] **Step 3 : vérifier**

```bash
cd epilote && flutter analyze
```
Attendu : `No issues found!`

- [ ] **Step 4 : commit**

```bash
git add epilote/lib/features/admin_groupe
git commit -m "$(cat <<'EOF'
feat(ministère): exporter un axe ou un périmètre en PDF officiel

Un bouton, pas trois : l'aperçu PDF porte déjà imprimer et enregistrer.
Pas de « partager » non plus — l'app n'a aucun canal sortant réel, et la
relance par notification reste le seul geste qui sort de cet écran.

Le document porte la mention qui le distingue d'une publication de la DEC.
Sans elle, un tableau sorti du cockpit circule et finit par faire autorité
à la place du chiffre proclamé.

Les écoles sont écrites en lignes et non en frame() : un frame ne se scinde
pas entre pages et lève TooManyPages dès qu'une filière dépasse une page.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9 : Les candidats dans la modal école

**Files:**
- Create: `epilote/lib/features/admin_groupe/providers/school_exam_candidates_provider.dart`
- Create: `epilote/lib/features/admin_groupe/widgets/school_candidates_section.dart`
- Modify: `epilote/lib/features/admin_groupe/widgets/admin_exam_school_modal.dart`
- Modify: `epilote/lib/features/admin_groupe/providers/admin_exams_provider.dart`
- Test: `epilote/test/school_exam_candidates_test.dart`

**Interfaces:**
- Produces:
  - `class SchoolCandidate { final String id, fullName, className, cycleCode, examShortName, examCode, dossierStatus; final String? candidateNumber, filiereLabel, levelCode; final List<String> missingDocuments; final bool isRepeater; bool get isComplete; }`
  - `class CandidateGroup { final String cycleLabel, examShortName; final String? filiereLabel; final List<SchoolCandidate> candidates; }`
  - `List<CandidateGroup> groupSchoolCandidates(List<SchoolCandidate> rows, {String? cycle, String? filiere, bool incompleteOnly = false})`
  - `final schoolExamCandidatesProvider = FutureProvider.autoDispose.family<List<SchoolCandidate>, String>(...)`
  - `SchoolCandidatesSection({required String schoolId})`

- [ ] **Step 1 : écrire le test qui échoue**

`epilote/test/school_exam_candidates_test.dart` :

```dart
import 'package:epilote/features/admin_groupe/providers/school_exam_candidates_provider.dart';
import 'package:flutter_test/flutter_test.dart';

// ════════════════════════════════════════════════════════════════════════════
//  QUI BLOQUE LE DOSSIER — la modal école disait « 8 complets sur 12 » sans
//  jamais dire lesquels. Une relance générique se classe ; « vos 6 candidats
//  de F5 sans acte de naissance » se traite.
//
//  Un établissement congolais couvre souvent collège ET lycée, parfois du
//  professionnel : le groupement cycle → examen → filière est la seule façon
//  de lire cette liste sans la trier à la main.
// ════════════════════════════════════════════════════════════════════════════
SchoolCandidate _c({
  required String id,
  required String name,
  String cycle = 'college',
  String exam = 'BET',
  String? filiere,
  String dossier = 'valide',
  List<String> missing = const [],
}) =>
    SchoolCandidate(
      id: id,
      fullName: name,
      className: '3ème A',
      cycleCode: cycle,
      levelCode: '3eme',
      examShortName: exam,
      examCode: exam,
      filiereLabel: filiere,
      candidateNumber: 'C-$id',
      dossierStatus: dossier,
      missingDocuments: missing,
      isRepeater: false,
    );

void main() {
  final rows = [
    _c(id: '1', name: 'MBEMBA Alice'),
    _c(id: '2', name: 'OKEMBA Jean',
        dossier: 'incomplet', missing: const ['Acte de naissance']),
    _c(id: '3', name: 'NGOMA Paul', cycle: 'lycee', exam: 'BAC T',
        filiere: 'F5', dossier: 'incomplet',
        missing: const ['Attestation de stage']),
    _c(id: '4', name: 'LOEMBA Sarah', cycle: 'lycee', exam: 'BAC T',
        filiere: 'F3'),
  ];

  test('le groupement suit cycle → examen → filière', () {
    final g = groupSchoolCandidates(rows);
    expect(g.length, 3);
    expect(g.first.cycleLabel, 'Collège');
    expect(g.first.candidates.length, 2);
    expect(g.map((x) => x.filiereLabel), containsAll(<String?>[null, 'F5', 'F3']));
  });

  test('le filtre cycle ne garde que son cycle', () {
    final g = groupSchoolCandidates(rows, cycle: 'lycee');
    expect(g.every((x) => x.cycleLabel == 'Lycée'), isTrue);
    expect(g.expand((x) => x.candidates).length, 2);
  });

  test('le filtre filière ne garde que sa filière', () {
    final g = groupSchoolCandidates(rows, filiere: 'F5');
    expect(g.single.candidates.single.fullName, 'NGOMA Paul');
  });

  test('« incomplets seulement » isole ceux qui bloquent', () {
    final g = groupSchoolCandidates(rows, incompleteOnly: true);
    final names = g.expand((x) => x.candidates).map((c) => c.fullName);
    expect(names, containsAll(<String>['OKEMBA Jean', 'NGOMA Paul']));
    expect(names, isNot(contains('MBEMBA Alice')));
  });

  test('un groupe vidé par les filtres disparaît au lieu de rester vide', () {
    final g = groupSchoolCandidates(rows, cycle: 'college', incompleteOnly: true);
    expect(g.length, 1);
    expect(g.single.candidates.single.fullName, 'OKEMBA Jean');
  });

  test('les pièces manquantes sont nommées, pas comptées', () {
    final paul = rows.firstWhere((c) => c.id == '3');
    expect(paul.isComplete, isFalse);
    expect(paul.missingDocuments, ['Attestation de stage']);
  });
}
```

- [ ] **Step 2 : lancer, vérifier l'échec**

```bash
cd epilote && flutter test test/school_exam_candidates_test.dart
```
Attendu : ÉCHEC — le fichier n'existe pas.

- [ ] **Step 3 : le provider et le groupement**

`school_exam_candidates_provider.dart` — modèle, `groupSchoolCandidates` (pur), et le `FutureProvider.family` :

```dart
final rows = await client
    .from('exam_candidates')
    .select('id, candidate_number, dossier_status, missing_documents, '
        'is_repeater, result, '
        'students(first_name, last_name), '
        'classes(name, cycle_code, level_code, filiere_label), '
        'exam_sessions!inner(national_exams!inner(code, short_name))')
    .eq('group_id', groupId)
    .eq('school_id', schoolId);
```

`cycleLabel` : `'college' → 'Collège'`, `'lycee' → 'Lycée'`, `'primaire' → 'Primaire'`, autre → la valeur telle quelle capitalisée. Ordre des cycles : primaire, collège, lycée, puis le reste. `missing_documents` est un `jsonb` tableau → `List<String>`.

`isComplete` = `dossierStatus != 'incomplet'`.

- [ ] **Step 4 : lancer, vérifier le passage**

```bash
cd epilote && flutter test test/school_exam_candidates_test.dart
```
Attendu : 6 tests PASS.

- [ ] **Step 5 : la section repliée**

`school_candidates_section.dart` — un `ExpansionTile` (ou un bouton « Afficher les candidats ») qui ne `watch` le provider **qu'une fois ouvert** : la modal doit s'ouvrir instantanément, la liste nominative est une requête de plus.

Une fois ouverte : deux `ListFilterDropdown` (cycle, filière) + un interrupteur « Incomplets seulement », puis les groupes. En-tête de groupe : `▾ LYCÉE · BAC T · F5 · 12 candidats`. Ligne : nom, classe, n° candidat, badge `✓ complet` (vert) ou `⚠` suivi des pièces manquantes nommées (orange).

- [ ] **Step 6 : brancher dans la modal et préciser la relance**

`admin_exam_school_modal.dart` : insérer `SchoolCandidatesSection(schoolId: row.schoolId)` après la ventilation par examen, avant les chiffres de la DEC.

Dans `admin_exams_provider.dart`, `remindSchools` enrichit son `body` quand l'école a des dossiers incomplets :

```dart
'body': '${school.candidates} candidat(s) déclaré(s) dans votre '
    'établissement n\'ont fait l\'objet d\'aucune transmission à la DEC'
    '${school.incomplete > 0 ? ', dont ${school.incomplete} au dossier incomplet' : ''}'
    '. Un dossier non déposé avant la clôture ne se rattrape pas.',
```

- [ ] **Step 7 : vérifier la taille des fichiers**

```bash
cd epilote && wc -l lib/features/admin_groupe/widgets/admin_exam_school_modal.dart \
  lib/features/admin_groupe/widgets/school_candidates_section.dart \
  lib/features/admin_groupe/providers/ministry_exam_rows.dart
```
Attendu : chacun ≤ 500. Si `admin_exam_school_modal.dart` dépasse, sortir `_ExamTable`/`_OfficialRow` dans `school_exam_bits.dart`.

- [ ] **Step 8 : suite complète**

```bash
cd epilote && flutter test && flutter analyze
```
Attendu : tous les tests PASS, `No issues found!`

- [ ] **Step 9 : commit**

```bash
git add epilote/lib epilote/test
git commit -m "$(cat <<'EOF'
feat(ministère): la fiche école nomme enfin qui bloque le dossier

« 8 complets sur 12 » ne se traite pas : le ministère relançait à l'aveugle
et le chef d'établissement recevait un reproche sans objet. La liste
nominative, groupée cycle → examen → filière parce qu'un établissement
couvre souvent collège ET lycée, porte pour chaque candidat les pièces qui
manquent, nommément.

Elle se charge à l'ouverture de la section et non de la modal : la fiche
doit s'ouvrir instantanément, la liste est une requête de plus.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10 : Vérification à l'écran

**Files:** aucun (validation).

- [ ] **Step 1 : lancer l'app**

```bash
cd epilote && flutter run -d linux
```

- [ ] **Step 2 : parcours « Résultats & archives »**

Ouvrir la page, en sortir, y revenir : plus de page vide transitoire, un squelette au premier chargement seulement. Relever un chiffre sur une session sans pièce → « Déposer la pièce… » → au retour, la pièce est sélectionnée. Déposer une pièce depuis l'archive → « Relever les chiffres » → enchaîner trois périmètres sans que la pièce ne se vide.

- [ ] **Step 3 : parcours « Examens nationaux »**

Basculer entre « Tous » et chaque examen : KPI, graphe, ventilations et tableau suivent. Vérifier que « Bacs bloqués » disparaît sur le BET. Cliquer une filière puis un département → la modal liste les écoles classées. Exporter → l'aperçu PDF s'ouvre, se scinde correctement sur plusieurs pages. Ouvrir une fiche école → déplier les candidats → filtrer par cycle et par filière.

- [ ] **Step 4 : vérifier l'absence de débordement**

Réduire la fenêtre jusqu'à ~900 px puis ~600 px de large : aucun `RenderFlex overflowed` en console.

- [ ] **Step 5 : commit final si retouches**

```bash
git add epilote/lib
git commit -m "$(cat <<'EOF'
fix(ministère): défauts de rendu vus à l'écran

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
EOF
)"
```

---

## Auto-revue du plan

**Couverture du spec** — A1 → Task 1 · A2 → Task 2 · A3 → Task 3 · B0 → Task 4 · B1 → Task 5 · B2 → Task 6 · B3 → Task 7 · B4 → Task 8 · B5 → Task 9. Les cinq tests annoncés au spec sont écrits (`exam_figure_batch`, `admin_exams_scope`, `exam_axis_drilldown`, `school_exam_candidates`) sauf `exam_results_loading_test` : l'état de chargement de la Task 1 est un pur assemblage de widgets sans logique propre, il est vérifié à la Task 10 étape 2 plutôt que par un test de widget qui ne testerait que Flutter. Écart assumé.

**Cohérence des types** — `MinistryCandidateRow` (Task 4) est consommé tel quel par `funnelByExam`/`funnelByDepartment` (Task 6) et `schoolsForAxis` (Task 7). `AxisSchoolLine` (Task 7) est consommé par `buildAxisPdf` (Task 8). `SchoolCandidate` (Task 9) est indépendant — il vient d'une autre requête. `PubScope` et `ExamPublication` viennent de `exam_archives_provider.dart` et sont importés par `exam_figure_fields.dart` (Task 3).
