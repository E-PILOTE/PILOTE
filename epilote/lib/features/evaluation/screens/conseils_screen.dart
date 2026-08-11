import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../../students/widgets/scope_drilldown_panel.dart';
import '../providers/bulletins_provider.dart';
import '../providers/conseils_provider.dart';
import '../providers/evaluation_overview_provider.dart';
import '../services/conseil_pdf_service.dart';
import 'evaluation_overview_widgets.dart';
import '../../../core/utils/message_erreur.dart';

part 'conseils_parts.dart';
part 'conseils_roster.dart';
part 'conseils_deliberation.dart';

const _kSlug = 'conseils';

// ════════════════════════════════════════════════════════════════════════════
//  PAGE CONSEIL DE CLASSE — la délibération de fin de trimestre. Design
//  plateforme : en-tête trimestre → KPI hero (école) → panneau Cycle ▸ Niveau ▸
//  Classe (couverture « élèves délibérés ») → couverture par classe ; en ouvrant
//  une classe, l'espace de délibération (distinctions + appréciations + synthèse,
//  validation du conseil, procès-verbal PDF). Les décisions sont portées par les
//  bulletins. 100% offline.
// ════════════════════════════════════════════════════════════════════════════
class ConseilsScreen extends ConsumerWidget {
  const ConseilsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Conseil de classe',
        // Le conseil de fin d'année est la SUITE de celui-ci, pas un autre
        // module : on y accède d'ici plutôt que par une entrée de sidebar de
        // plus, qui laisserait croire à deux instances distinctes.
        //
        // Il vit dans la PAGE, en bas, et non dans la barre de titre : la barre
        // est le chrome de l'application, partagé par tous les écrans. Y poser
        // l'action la plus lourde de l'année — celle qui fait passer ou
        // redoubler une promotion entière — la présentait comme un utilitaire
        // de navigation, à portée de clic distrait, et sans un mot pour dire ce
        // qu'elle déclenche.
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

  String? get _activeClassId => _openClassId ?? _scope.classId;

  CouncilArgs get _args =>
      (classId: _activeClassId!, trimesterId: _trimesterId);

  void _refresh() {
    ref.invalidate(evaluationOverviewProvider(_trimesterId));
    if (_activeClassId != null) {
      ref.invalidate(bulletinComputationProvider(_args));
      ref.invalidate(councilSessionProvider(_args));
    }
  }

  Future<void> _generate() async {
    if (_activeClassId == null || _trimesterId == null) return;
    final p = ref.read(authNotifierProvider).valueOrNull;
    final yearId = ref.read(activeYearIdProvider);
    if (yearId == null) return;

    // Un bulletin généré sans rattachement serait refusé à la remontée et
    // emporterait le lot PowerSync entier — toute une classe de bulletins
    // perdue sans message.
    final missing = missingWriteIds(
      groupId: p?.groupId,
      schoolId: p?.schoolId,
      actorId: p?.id,
    );
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(writeIdentityMessage(missing)),
        backgroundColor: kRed,
        duration: const Duration(seconds: 6),
      ));
      return;
    }
    setState(() => _busy = true);
    await runModuleWrite(context, () async {
      final comp = await ref.read(bulletinComputationProvider(_args).future);
      await generateBulletins(
        groupId: p!.groupId!,
        schoolId: p.schoolId!,
        academicYearId: yearId,
        trimesterId: _trimesterId!,
        comp: comp,
      );
    }, success: 'Bulletins générés — délibération prête');
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
  }

  Future<void> _autofill(List<CouncilEntry> entries) async {
    if (_trimesterId == null) return;
    setState(() => _busy = true);
    await runModuleWrite(
      context,
      () => autofillAwards(trimesterId: _trimesterId!, entries: entries),
      success: 'Distinctions proposées pré-remplies',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
  }

  Future<void> _setStatus(String status) async {
    if (_activeClassId == null || _trimesterId == null) return;
    final actorId = ref.read(authNotifierProvider).valueOrNull?.id;
    setState(() => _busy = true);
    await runModuleWrite(
      context,
      () => setBulletinsStatus(
        classId: _activeClassId!,
        trimesterId: _trimesterId!,
        status: status,
        actorId: actorId,
      ),
      success: status == 'validated'
          ? 'Délibération validée par le conseil'
          : 'Délibération rouverte',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    _refresh();
  }

  Future<void> _editSynthesis(String? current) async {
    if (_activeClassId == null || _trimesterId == null) return;
    final ctrl = TextEditingController(text: current ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Synthèse du conseil'),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: ctrl,
            maxLines: 5,
            autofocus: true,
            decoration: const InputDecoration(
              hintText:
                  'Appréciation générale de la classe, dynamique, axes de '
                  'progrès, décisions collectives…',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    await runModuleWrite(
      context,
      () => saveCouncilSynthesis(
        classId: _activeClassId!,
        trimesterId: _trimesterId!,
        comment: ctrl.text,
      ),
      success: 'Synthèse enregistrée',
    );
    if (mounted) _refresh();
  }

  void _deliberate(CouncilEntry e, bool canEdit) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DeliberationSheet(
          entry: e,
          trimesterId: _trimesterId!,
          canEdit: canEdit,
          onSaved: _refresh,
        ),
      );

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
    final canUpdate = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final readOnly = ref.watch(yearReadOnlyProvider);
    final canEdit = canUpdate && !readOnly;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EvalTrimesterHeader(
          title: 'Conseil de classe',
          subtitle: 'Délibération par cycle, niveau et classe',
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
              child: Center(child: Text(messageErreur(e)))),
          data: (ov) => _content(ov, canEdit, trims),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _content(EvaluationOverview ov, bool canEdit, List trims) {
    if (ov.classes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: AdminEmptyState(
          icon: Icons.groups_rounded,
          title: 'Aucune classe',
          message:
              'Aucune classe active dans votre périmètre pour cette année.',
        ),
      );
    }
    final genRate =
        ov.students == 0 ? 0 : (ov.generated * 100 / ov.students).round();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      EvalHeroKpis(cards: [
        (Icons.groups_2_rounded, 'Élèves', '${ov.students}',
            const Color(0xFF0EA5E9), '${ov.classesTotal} classes'),
        (Icons.fact_check_rounded, 'Bulletins générés',
            '${ov.generated}/${ov.students}', kNavy, '$genRate% — prérequis'),
        (Icons.how_to_vote_rounded, 'Classes délibérées',
            '${ov.classesDeliberated}/${ov.classesTotal}', kGreen,
            '${ov.deliberated} élèves'),
        (Icons.functions_rounded, 'Moyenne école',
            ov.schoolAverage == null
                ? '—'
                : '${ov.schoolAverage!.toStringAsFixed(2)}/20',
            const Color(0xFF8B5CF6), 'bulletins générés'),
      ]),
      const SizedBox(height: 16),
      ScopeDrilldownPanel(
        title: 'Couverture des délibérations',
        metricLabel: 'Délibérés',
        unitNoun: 'élèves',
        selected: _scope,
        onSelect: (s) => setState(() {
          _scope = s;
          _openClassId = null;
        }),
        units: evalScopeUnits(ov.classes, (c) => c.deliberated),
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
        _CouncilBody(
          args: _args,
          busy: _busy,
          canEdit: canEdit,
          className: _classNameFor(ov, _activeClassId!),
          trimesterLabel: trims
              .where((t) => t.id == _trimesterId)
              .map((t) => t.label as String)
              .firstOrNull,
          onGenerate: _generate,
          onAutofill: _autofill,
          onStatus: _setStatus,
          onSynthesis: _editSynthesis,
          onDeliberate: (e) => _deliberate(e, canEdit),
        )
      else ...[
        const EvalWorkflowGuide(steps: [
          (
            Icons.class_rounded,
            'Ouvrez une classe',
            'Cliquez « Délibérer » sur une classe ci-dessous'
          ),
          (
            Icons.workspace_premium_rounded,
            'Attribuez les distinctions',
            'Félicitations, encouragements… + appréciation par élève'
          ),
          (
            Icons.how_to_reg_rounded,
            'Validez la délibération',
            'Le conseil valide ; les bulletins sont prêts à publier'
          ),
        ]),
        const SizedBox(height: 16),
        const EvalSectionLabel(
            icon: Icons.touch_app_rounded,
            text: 'Ouvrez une classe pour délibérer'),
        const SizedBox(height: 12),
        EvalCoverageList(
          classes: filterCoverage(ov.classes, _scope),
          metricLabel: 'délibérés',
          okOf: (c) => c.deliberated,
          openLabel: 'Délibérer',
          onOpen: (c) => setState(() => _openClassId = c.classId),
        ),
      ],
      // En bas, et non en haut : c'est l'étape D'APRÈS. Placée avant les
      // classes, elle aurait concurrencé le travail du trimestre en cours.
      const SizedBox(height: 24),
      const _PassageGateway(),
    ]);
  }

  String? _classNameFor(EvaluationOverview ov, String classId) => ov.classes
      .where((c) => c.classId == classId)
      .map((c) => c.className)
      .firstOrNull;
}
