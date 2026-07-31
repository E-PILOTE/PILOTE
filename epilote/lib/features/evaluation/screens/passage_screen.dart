import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../../structure/providers/academic_year_context.dart';
import '../../structure/providers/academic_year_provider.dart';
import '../../structure/providers/class_rollover.dart';
import '../providers/passage_provider.dart';
import '../services/passage_pdf_service.dart';
import 'evaluation_overview_widgets.dart';

part 'passage_parts.dart';

const _kSlug = 'conseils';

// ════════════════════════════════════════════════════════════════════════════
//  PASSAGE EN CLASSE SUPÉRIEURE — le conseil de fin d'année.
//
//  Le conseil de classe trimestriel décerne des distinctions ; celui-ci rend le
//  verdict annuel : passe, redouble, réorienté. C'est la même instance, d'où
//  le même module (`conseils`) — mais un geste différent, d'où une page à part.
//
//  ── LE PARCOURS ────────────────────────────────────────────────────────────
//  1. Reconduire les classes vers l'année suivante (préalable matériel).
//  2. Ouvrir une classe, laisser proposer les verdicts, corriger au cas par cas.
//  3. Imprimer le procès-verbal — c'est lui qui fait foi.
//  4. Réinscrire : les inscriptions de l'année suivante sont créées.
//
//  Les classes d'EXAMEN n'apparaissent pas : la DEC proclame, l'école n'a pas
//  à décider à sa place.
// ════════════════════════════════════════════════════════════════════════════
class PassageScreen extends ConsumerWidget {
  const PassageScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Passage en classe supérieure',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  String? _openClassId;
  bool _busy = false;

  void _refresh(String yearId) {
    ref.invalidate(passageClassesProvider(yearId));
    if (_openClassId != null) {
      ref.invalidate(passageSessionProvider(_openClassId!));
    }
  }

  /// Identifiants de rattachement — sans eux, une écriture est refusée au
  /// serveur et PowerSync abandonne tout le lot, en silence.
  ({String groupId, String schoolId, String? actorId})? _identity() {
    final p = ref.read(authNotifierProvider).valueOrNull;
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
      return null;
    }
    return (groupId: p!.groupId!, schoolId: p.schoolId!, actorId: p.id);
  }

  Future<void> _rollover(String yearId, String nextYearId) async {
    final id = _identity();
    if (id == null) return;
    setState(() => _busy = true);
    var created = 0;
    await runModuleWrite(context, () async {
      final r = await rolloverClasses(
        fromYearId: yearId,
        toYearId: nextYearId,
        groupId: id.groupId,
        schoolId: id.schoolId,
      );
      created = r.created;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(created == 0
          ? 'Aucune classe à reconduire — la structure existe déjà.'
          : '$created classe(s) reconduite(s) avec leur programme.'),
      backgroundColor: created == 0 ? kTextMuted : kGreen,
    ));
    _refresh(yearId);
  }

  Future<void> _autofill(PassageSession s, String yearId) async {
    final id = _identity();
    if (id == null) return;
    setState(() => _busy = true);
    var n = 0;
    await runModuleWrite(context, () async {
      n = await autofillVerdicts(session: s, actorId: id.actorId);
    });
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(n == 0
          ? 'Tous les élèves sont déjà délibérés.'
          : '$n proposition(s) inscrite(s) — à revoir élève par élève.'),
      backgroundColor: n == 0 ? kTextMuted : kNavy,
    ));
    _refresh(yearId);
  }

  Future<void> _reenroll(PassageSession s, String yearId) async {
    final id = _identity();
    if (id == null) return;
    final ok = await showAdminConfirm(
      context,
      title: 'Réinscrire les élèves délibérés',
      message: 'Les inscriptions de ${s.nextYearLabel} seront créées pour les '
          'élèves qui passent et ceux qui redoublent. Les élèves réorientés '
          'sont laissés de côté : leur classe se choisit au cas par cas.',
      confirmLabel: 'Réinscrire',
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    var n = 0;
    await runModuleWrite(context, () async {
      n = await reenrollDecided(
        session: s,
        groupId: id.groupId,
        schoolId: id.schoolId,
        actorId: id.actorId,
      );
    });
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(n == 0
          ? 'Aucun élève à réinscrire.'
          : '$n élève(s) réinscrit(s) en ${s.nextYearLabel}.'),
      backgroundColor: n == 0 ? kTextMuted : kGreen,
    ));
    _refresh(yearId);
  }

  Future<void> _decide(PassageEntry e, PassageSession s, String yearId) async {
    final id = _identity();
    if (id == null) return;
    final res = await showModalBottomSheet<({String? code, String? targetClassId})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerdictSheet(
        entry: e,
        upper: s.upperClass,
        repeat: s.repeatClass,
      ),
    );
    if (res == null || !mounted) return;
    await runModuleWrite(
      context,
      () => savePassageDecision(
        enrollmentId: e.enrollmentId,
        decision: res.code,
        average: e.annualAverage,
        targetClassId: res.targetClassId,
        actorId: id.actorId,
      ),
      success: res.code == null ? 'Décision effacée' : 'Décision enregistrée',
    );
    if (mounted) _refresh(yearId);
  }

  Future<void> _printMinutes(PassageSession s, String className) async {
    final school = ref.read(currentSchoolProvider).valueOrNull;
    final year = ref.read(activeYearProvider);
    await showPdfPreviewDialog(
      context,
      title: 'Procès-verbal — Passage en classe supérieure',
      subtitle: '$className · ${year?.label ?? ''}',
      pdfFileName: 'pv_passage_${className.replaceAll(' ', '_')}.pdf',
      build: (_) => PassagePdfService.build(
        className: className,
        yearLabel: year?.label ?? '',
        schoolName: school?['name'] as String? ?? '',
        session: s,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final yearId = ref.watch(activeYearIdProvider);
    final year = ref.watch(activeYearProvider);
    if (yearId == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 60),
        child: AdminEmptyState(
          icon: Icons.event_busy_rounded,
          title: 'Aucune année active',
          message: 'Sélectionnez une année scolaire pour délibérer.',
        ),
      );
    }
    final canUpdate = ref.watch(canProvider((slug: _kSlug, action: 'update')));
    final readOnly = ref.watch(yearReadOnlyProvider);
    final canEdit = canUpdate && !readOnly;
    final classes = ref.watch(passageClassesProvider(yearId));
    final next = ref.watch(nextYearProvider(yearId)).valueOrNull;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        classes.when(
          loading: () => const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(child: Text('Erreur : $e'))),
          data: (rows) => _content(rows, yearId, year?.label ?? '', next, canEdit),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _content(
    List<PassageClass> rows,
    String yearId,
    String yearLabel,
    (String, String)? next,
    bool canEdit,
  ) {
    // La structure d'accueil est prête dès qu'une classe existe l'an prochain.
    final structureReady = rows.isNotEmpty &&
        ref
                .watch(passageSessionProvider(rows.first.classId))
                .valueOrNull
                ?.upperClass !=
            null;

    final students = rows.fold(0, (a, r) => a + r.students);
    final decided = rows.fold(0, (a, r) => a + r.decided);
    final reenrolled = rows.fold(0, (a, r) => a + r.reenrolled);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _CampaignHeader(
        yearLabel: yearLabel,
        nextLabel: next?.$2,
        structureReady: structureReady,
        canEdit: canEdit,
        busy: _busy,
        onRollover: () => next == null ? null : _rollover(yearId, next.$1),
      ),
      const SizedBox(height: 16),
      EvalHeroKpis(cards: [
        (Icons.class_rounded, 'Classes de passage', '${rows.length}',
            const Color(0xFF0EA5E9), 'hors classes d\'examen'),
        (Icons.groups_2_rounded, 'Élèves concernés', '$students', kNavy,
            '${rows.length} classes'),
        (Icons.how_to_vote_rounded, 'Délibérés', '$decided/$students', kGreen,
            students == 0 ? '—' : '${(decided * 100 / students).round()}%'),
        (Icons.how_to_reg_rounded, 'Réinscrits', '$reenrolled',
            const Color(0xFF8B5CF6), next?.$2 ?? 'année suivante à ouvrir'),
      ]),
      const SizedBox(height: 18),
      if (rows.isEmpty)
        const AdminEmptyState(
          icon: Icons.class_outlined,
          title: 'Aucune classe de passage',
          message: 'Toutes les classes de cette année sont des classes '
              'd\'examen : leur résultat est proclamé par la DEC.',
        )
      else if (_openClassId == null) ...[
        const EvalSectionLabel(
            icon: Icons.touch_app_rounded,
            text: 'Ouvrez une classe pour délibérer'),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 1100 ? 4 : (c.maxWidth > 760 ? 3 : 2);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 138,
            ),
            itemCount: rows.length,
            itemBuilder: (_, i) => _ClassCard(
              row: rows[i],
              onOpen: () => setState(() => _openClassId = rows[i].classId),
            ),
          );
        }),
      ] else
        _ClassDeliberation(
          classId: _openClassId!,
          className: rows
                  .where((r) => r.classId == _openClassId)
                  .map((r) => r.className)
                  .firstOrNull ??
              '',
          yearId: yearId,
          canEdit: canEdit,
          busy: _busy,
          onClose: () => setState(() => _openClassId = null),
          onAutofill: _autofill,
          onReenroll: _reenroll,
          onDecide: _decide,
          onPrint: _printMinutes,
        ),
    ]);
  }
}

/// Table de délibération d'une classe.
class _ClassDeliberation extends ConsumerWidget {
  const _ClassDeliberation({
    required this.classId,
    required this.className,
    required this.yearId,
    required this.canEdit,
    required this.busy,
    required this.onClose,
    required this.onAutofill,
    required this.onReenroll,
    required this.onDecide,
    required this.onPrint,
  });

  final String classId, className, yearId;
  final bool canEdit, busy;
  final VoidCallback onClose;
  final void Function(PassageSession, String) onAutofill, onReenroll;
  final void Function(PassageEntry, PassageSession, String) onDecide;
  final void Function(PassageSession, String) onPrint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(passageSessionProvider(classId));
    return async.when(
      loading: () => const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(child: Text('Erreur : $e'))),
      data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              IconButton(
                onPressed: onClose,
                icon: Icon(Icons.arrow_back_rounded, size: 18, color: kTextMuted),
                tooltip: 'Toutes les classes',
              ),
              Expanded(
                child: Text(className,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary)),
              ),
              if (s.entries.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () => onPrint(s, className),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 15),
                  label: const Text('Procès-verbal'),
                ),
              if (canEdit) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => onAutofill(s, yearId),
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 15),
                  label: const Text('Proposer'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kNavy),
                  onPressed: busy || !s.canReenroll || s.decidedCount == 0
                      ? null
                      : () => onReenroll(s, yearId),
                  icon: const Icon(Icons.how_to_reg_rounded, size: 15),
                  label: const Text('Réinscrire'),
                ),
              ],
            ]),
            const SizedBox(height: 12),
            AdminCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kNavy.withValues(alpha: 0.04),
                    border: Border(bottom: BorderSide(color: kBorder)),
                  ),
                  child: Row(children: [
                    SizedBox(width: 34, child: _h('RG')),
                    Expanded(flex: 4, child: _h('ÉLÈVE')),
                    SizedBox(width: 92, child: _h('MOY. ANNUELLE')),
                    Expanded(flex: 3, child: _h('DÉCISION')),
                    const SizedBox(width: 96),
                    const SizedBox(width: 14),
                  ]),
                ),
                if (s.entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Text(
                      'Aucun élève actif dans cette classe.',
                      style: TextStyle(fontSize: 12.5, color: kTextMuted),
                    ),
                  ),
                for (var i = 0; i < s.entries.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: kBorder),
                  _StudentRow(
                    entry: s.entries[i],
                    canEdit: canEdit,
                    onTap: () => onDecide(s.entries[i], s, yearId),
                  ),
                ],
              ]),
            ),
          ]),
    );
  }

  Widget _h(String t) => Text(t,
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: kTextMuted));
}
