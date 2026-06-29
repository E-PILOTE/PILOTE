import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/bulletins_provider.dart';
import '../providers/conseils_provider.dart' show awardFor;
import '../providers/evaluation_overview_provider.dart';
import '../services/bulletin_pdf_service.dart';
import 'evaluation_overview_widgets.dart';

part 'bulletins_parts.dart';
part 'bulletins_detail.dart';

const _kSlug = 'bulletins';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE BULLETINS — relevés de notes par classe × trimestre. Design plateforme :
//  en-tête trimestre → KPI hero (école) → panneau Cycle ▸ Niveau ▸ Classe
//  (couverture « bulletins générés ») → couverture par classe ; en ouvrant une
//  classe, l'espace de travail (calcul depuis les notes, génération, cycle de
//  vie brouillon→publié, liste classée, détail + PDF officiel). 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class BulletinsScreen extends ConsumerWidget {
  const BulletinsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Bulletins',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  String? _trimesterId;
  ScopeSel _scope = const ScopeSel(); // filtre du panneau (toujours valide)
  String? _openClassId; // classe ouverte via une carte de couverture
  bool _busy = false;

  // Classe active = ouverte par carte, ou choisie via le déroulant du panneau.
  String? get _activeClassId => _openClassId ?? _scope.classId;

  BulletinArgs get _args =>
      (classId: _activeClassId!, trimesterId: _trimesterId);

  void _refresh() {
    ref.invalidate(evaluationOverviewProvider(_trimesterId));
    if (_activeClassId != null) {
      ref.invalidate(bulletinComputationProvider(_args));
    }
  }

  Future<void> _generate(BulletinComputation comp) async {
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null || _trimesterId == null) return;
    setState(() => _busy = true);
    await runModuleWrite(
      context,
      () => generateBulletins(
        groupId: p?.groupId ?? '',
        schoolId: p?.schoolId ?? '',
        academicYearId: yearId,
        trimesterId: _trimesterId!,
        comp: comp,
      ),
      success: 'Bulletins générés (${comp.students.length})',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
  }

  Future<void> _setStatus(String status) async {
    if (_scope.classId == null || _trimesterId == null) return;
    final actorId = ref.read(authNotifierProvider).valueOrNull?.id;
    setState(() => _busy = true);
    await runModuleWrite(
      context,
      () => setBulletinsStatus(
        classId: _scope.classId!,
        trimesterId: _trimesterId!,
        status: status,
        actorId: actorId,
      ),
      success: 'Bulletins : ${status == 'published' ? 'publiés' : status}',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
  }

  void _openDetail(StudentBulletin s, double? classAvg, String? className) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BulletinDetailSheet(
        student: s,
        classAverage: classAvg,
        className: className,
        trimesterId: _trimesterId,
      ),
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
    final overview = ref.watch(evaluationOverviewProvider(_trimesterId));
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    final canUpdate = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final readOnly = ref.watch(yearReadOnlyProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EvalTrimesterHeader(
          title: 'Bulletins scolaires',
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
        overview.when(
          loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text('Erreur : $e'))),
          data: (ov) => _content(ov, canCreate, canUpdate, readOnly),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _content(
      EvaluationOverview ov, bool canCreate, bool canUpdate, bool readOnly) {
    if (ov.classes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: AdminEmptyState(
          icon: Icons.assignment_outlined,
          title: 'Aucune classe',
          message:
              'Aucune classe active dans votre périmètre pour cette année.',
        ),
      );
    }
    final rate = ov.students == 0 ? 0 : (ov.generated * 100 / ov.students).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      EvalHeroKpis(cards: [
        (Icons.groups_2_rounded, 'Élèves', '${ov.students}',
            const Color(0xFF0EA5E9), '${ov.classesTotal} classes'),
        (Icons.fact_check_rounded, 'Bulletins générés',
            '${ov.generated}/${ov.students}', kNavy, '$rate% des élèves'),
        (Icons.published_with_changes_rounded, 'Publiés', '${ov.published}',
            kGreen, '${ov.classesPublished} classes complètes'),
        (Icons.functions_rounded, 'Moyenne école',
            ov.schoolAverage == null
                ? '—'
                : '${ov.schoolAverage!.toStringAsFixed(2)}/20',
            const Color(0xFF8B5CF6), 'bulletins générés'),
      ]),
      const SizedBox(height: 16),
      ScopeDrilldownPanel(
        title: 'Couverture des bulletins',
        metricLabel: 'Générés',
        unitNoun: 'élèves',
        selected: _scope,
        onSelect: (s) => setState(() {
          _scope = s;
          _openClassId = null;
        }),
        units: evalScopeUnits(ov.classes, (c) => c.generated),
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
          }),
        ),
      ],
      const SizedBox(height: 18),
      if (_activeClassId != null && _trimesterId != null)
        _BulletinBody(
          args: _args,
          className: _classNameFor(ov, _activeClassId!),
          busy: _busy,
          canGenerate: canCreate && !readOnly,
          canPublish: canUpdate && !readOnly,
          onGenerate: _generate,
          onStatus: _setStatus,
          onOpen: (s, avg) =>
              _openDetail(s, avg, _classNameFor(ov, _activeClassId!)),
        )
      else ...[
        const EvalWorkflowGuide(steps: [
          (
            Icons.class_rounded,
            'Ouvrez une classe',
            'Cliquez « Ouvrir » sur une classe ci-dessous'
          ),
          (
            Icons.calculate_rounded,
            'Générez les bulletins',
            'Calcul auto des moyennes, du rang et de la mention'
          ),
          (
            Icons.publish_rounded,
            'Publiez aux familles',
            'Après la délibération du conseil de classe'
          ),
        ]),
        const SizedBox(height: 16),
        const EvalSectionLabel(
            icon: Icons.touch_app_rounded,
            text: 'Ouvrez une classe pour générer ses bulletins'),
        const SizedBox(height: 12),
        EvalCoverageList(
          classes: filterCoverage(ov.classes, _scope),
          metricLabel: 'générés',
          okOf: (c) => c.generated,
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
