import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/class_context_banner.dart';
import '../../auth/providers/auth_provider.dart';
import '../../classes/providers/class_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../../structure/providers/timetable_provider.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/eval_grades_provider.dart';
import '../providers/evaluation_overview_provider.dart';
import '../providers/evaluations_provider.dart';
import 'evaluation_overview_widgets.dart';

part 'notes_parts.dart';
part 'notes_list.dart';
part 'notes_form.dart';
part 'notes_grades.dart';

const _kSlug = 'notes';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE ÉVALUATIONS & NOTES — design plateforme : en-tête trimestre → KPI hero
//  (école) → panneau Cycle ▸ Niveau ▸ Classe (couverture « classes évaluées »,
//  TOUTE la structure visible même sans données) → couverture par classe ; en
//  ouvrant une classe, ses évaluations (création, cycle de vie draft→publié,
//  feuille de saisie des notes). 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Notes',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _search = TextEditingController();
  String? _trimesterId;
  ScopeSel _scope = const ScopeSel(); // filtre du panneau (toujours valide)
  String? _openClassId; // classe ouverte via une carte de couverture
  String? _type, _status;

  String? get _activeClassId => _openClassId ?? _scope.classId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _resetFilters() => setState(() {
        _search.clear();
        _type = null;
        _status = null;
      });

  // Évaluations du trimestre courant (toute l'école).
  List<Evaluation> _trimEvals(List<Evaluation> all) => [
        for (final e in all)
          if (_trimesterId == null || e.trimesterId == _trimesterId) e,
      ];

  // Évaluations de la classe ouverte, filtrées (recherche/type/statut).
  List<Evaluation> _classEvals(List<Evaluation> trimEvals) {
    final q = _search.text.trim().toLowerCase();
    return trimEvals.where((e) {
      if (e.classId != _activeClassId) return false;
      if (_type != null && e.type != _type) return false;
      if (_status != null && e.status != _status) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          (e.subjectName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  void _openForm({Evaluation? evaluation}) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _EvaluationForm(
          evaluation: evaluation,
          presetClassId: evaluation == null ? _activeClassId : null,
          presetTrimesterId: evaluation == null ? _trimesterId : null,
        ),
      );

  void _openGrades(Evaluation e) {
    final readOnly = ref.read(yearReadOnlyProvider);
    final canGrade = ref.read(canProvider((slug: _kSlug, action: 'update'))) &&
        !readOnly &&
        !e.isPublished;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GradeSheet(evaluation: e, canEdit: canGrade),
    );
  }

  Future<void> _delete(Evaluation e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Supprimer cette évaluation ?'),
        content: Text(
            '« ${e.title} » et toutes ses notes (${e.gradedCount}) seront '
            'supprimées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await runModuleWrite(context, () => deleteEvaluation(e.id),
        success: 'Évaluation supprimée');
  }

  Future<void> _setStatus(Evaluation e, String status) async {
    final actorId = ref.read(authNotifierProvider).valueOrNull?.id;
    await runModuleWrite(
      context,
      () => setEvaluationStatus(id: e.id, status: status, actorId: actorId),
      success: 'Statut : ${evalStatusLabel(status)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final yearId = ref.watch(activeYearIdProvider);
    final trims = (yearId != null
            ? ref.watch(trimestersProvider(yearId)).valueOrNull
            : null) ??
        const [];
    _trimesterId ??=
        trims.where((t) => t.isCurrent).map((t) => t.id).firstOrNull ??
            (trims.isNotEmpty ? trims.first.id : null);
    final evalsAsync = ref.watch(evaluationsProvider);
    final overview = ref.watch(evaluationOverviewProvider(_trimesterId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EvalTrimesterHeader(
          title: 'Évaluations & Notes',
          subtitle: 'Couverture de l\'établissement par cycle, niveau et classe',
          trims: trims,
          trimesterId: _trimesterId,
          onTrimester: (v) => setState(() {
            _trimesterId = v;
            _scope = const ScopeSel();
            _openClassId = null;
          }),
        ),
        const SizedBox(height: 20),
        evalsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text('Erreur : $e'))),
          data: (all) => overview.maybeWhen(
            data: (ov) => _content(ov, _trimEvals(all)),
            orElse: () => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator())),
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _content(EvaluationOverview ov, List<Evaluation> trimEvals) {
    if (ov.classes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: AdminEmptyState(
          icon: Icons.grade_outlined,
          title: 'Aucune classe',
          message:
              'Aucune classe active dans votre périmètre pour cette année.',
        ),
      );
    }
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canUpdate = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final canDelete = ref.watch(canProvider((slug: _kSlug, action: 'delete')));
    final readOnly = ref.watch(yearReadOnlyProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _NotesKpis(items: trimEvals),
      const SizedBox(height: 16),
      ScopeDrilldownPanel(
        title: 'Couverture des évaluations',
        metricLabel: 'Évaluées',
        unitNoun: 'classes',
        selected: _scope,
        onSelect: (s) => setState(() {
          _scope = s;
          _openClassId = null;
        }),
        units: evalClassUnits(ov.classes, (c) => c.hasEvaluations),
      ),
      if (_scope.active || _openClassId != null) ...[
        const SizedBox(height: 12),
        EvalScopeChip(
          label: _openClassId != null
              ? 'Classe : ${_classNameFor(ov, _openClassId!) ?? ''}'
              : _scope.label,
          onClear: () => setState(() {
            _scope = const ScopeSel();
            _openClassId = null;
            _resetFilters();
          }),
        ),
      ],
      const SizedBox(height: 18),
      if (_activeClassId != null)
        _ClassWorkspace(
          className: _classNameFor(ov, _activeClassId!),
          evals: _classEvals(trimEvals),
          searchCtrl: _search,
          type: _type,
          status: _status,
          canCreate: canCreate && !readOnly,
          canEdit: canUpdate && !readOnly,
          canDelete: canDelete && !readOnly,
          onSearch: (_) => setState(() {}),
          onType: (v) => setState(() => _type = v),
          onStatus: (v) => setState(() => _status = v),
          onReset: _resetFilters,
          onAdd: () => _openForm(),
          onOpen: _openGrades,
          onEdit: (e) => _openForm(evaluation: e),
          onDelete: _delete,
          onSetStatus: _setStatus,
        )
      else ...[
        const EvalWorkflowGuide(steps: [
          (
            Icons.class_rounded,
            'Ouvrez une classe',
            'Cliquez « Ouvrir » sur une classe ci-dessous'
          ),
          (
            Icons.add_circle_outline_rounded,
            'Créez une évaluation',
            'Composition, devoir, séquence… (matière, barème, coef)'
          ),
          (
            Icons.edit_note_rounded,
            'Saisissez les notes',
            'Ouvrez l\'évaluation → feuille de saisie élève par élève'
          ),
        ]),
        const SizedBox(height: 16),
        const EvalSectionLabel(
            icon: Icons.touch_app_rounded,
            text: 'Ouvrez une classe pour saisir ses évaluations'),
        const SizedBox(height: 12),
        EvalCoverageList(
          classes: filterCoverage(ov.classes, _scope),
          metricLabel: 'complètes',
          okOf: (c) => c.evaluationsComplete,
          totalOf: (c) => c.evaluations,
          openLabel: 'Ouvrir',
          onOpen: (c) => setState(() => _openClassId = c.classId),
        ),
      ],
    ]);
  }

  String? _classNameFor(EvaluationOverview ov, String classId) => ov.classes
      .where((c) => c.classId == classId)
      .map((c) => c.className)
      .firstOrNull;
}
