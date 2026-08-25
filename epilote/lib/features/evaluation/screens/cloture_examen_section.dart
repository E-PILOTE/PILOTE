import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/write_identity.dart';
import '../../../core/widgets/admin_ui.dart';
import '../../auth/providers/auth_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/cloture_examen_provider.dart';
import 'evaluation_overview_widgets.dart';
import '../../../core/utils/message_erreur.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CLÔTURE DES CLASSES D'EXAMEN — l'écran qui tire les conséquences.
//
//  Le pendant de la délibération, pour les classes que la DEC tranche. On n'y
//  vote pas : on y reporte une proclamation, puis on réinscrit les ajournés et
//  on prononce la sortie des admis que l'établissement n'accueille plus.
//
//  Trois gestes, dans cet ordre, et chacun ne fait qu'une chose :
//    1. Reporter les résultats  → écrit le verdict de fin d'année.
//    2. Réinscrire              → crée les inscriptions de l'année suivante.
//    3. Prononcer les sorties   → ferme l'inscription des diplômés sortants.
//
//  Aucun n'est automatique. Un enfant qui redouble, un enfant qui s'en va :
//  ce sont des actes d'établissement, ils se posent à la main et ils se lisent
//  avant d'être posés.
// ════════════════════════════════════════════════════════════════════════════

/// Les trois issues possibles d'une année scolaire.
enum YearEndTab { passage, examen, nonRevenus }

/// La bascule entre les régimes de fin d'année.
///
/// Des onglets et non des pages : c'est la MÊME échéance — le 30 juin — et le
/// chef d'établissement doit voir d'un coup d'œil que rien n'a été oublié. Le
/// compteur porté par chaque onglet est là pour ça.
///
/// Le troisième onglet ferme la boucle. Les deux premiers disent ce que
/// l'établissement DÉCIDE ; celui-ci dit ce qu'il CONSTATE — les enfants qu'il
/// attendait et qui ne sont pas revenus. Sans lui, une classe pouvait être
/// entièrement délibérée pendant qu'un tiers de ses élèves disparaissait sans
/// que rien ne l'écrive nulle part.
class YearEndRegimeTabs extends StatelessWidget {
  const YearEndRegimeTabs({
    super.key,
    required this.tab,
    required this.passageCount,
    required this.examCount,
    required this.onChanged,
    this.absentCount,
  });

  final YearEndTab tab;
  final int? passageCount, examCount, absentCount;
  final ValueChanged<YearEndTab> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          _tab(
            selected: tab == YearEndTab.passage,
            icon: Icons.how_to_vote_rounded,
            label: 'Classes de passage',
            count: passageCount,
            hint: 'le conseil décide',
            onTap: () => onChanged(YearEndTab.passage),
          ),
          const SizedBox(width: 4),
          _tab(
            selected: tab == YearEndTab.examen,
            icon: Icons.workspace_premium_rounded,
            label: 'Classes d\'examen',
            count: examCount,
            hint: 'la DEC proclame',
            onTap: () => onChanged(YearEndTab.examen),
          ),
          const SizedBox(width: 4),
          _tab(
            selected: tab == YearEndTab.nonRevenus,
            icon: Icons.person_search_rounded,
            label: 'Non revenus',
            count: absentCount,
            hint: 'ce qu\'on constate',
            onTap: () => onChanged(YearEndTab.nonRevenus),
          ),
        ]),
      );

  Widget _tab({
    required bool selected,
    required IconData icon,
    required String label,
    required int? count,
    required String hint,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: Material(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          elevation: selected ? 1 : 0,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Icon(icon,
                    size: 17, color: selected ? kNavy : kTextMuted),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == null ? label : '$label · $count',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected ? kTextPrimary : kTextMuted,
                        ),
                      ),
                      Text(hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 10.5, color: kTextMuted)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
}

class ExamClosureSection extends ConsumerStatefulWidget {
  const ExamClosureSection({
    super.key,
    required this.yearId,
    required this.yearLabel,
    required this.canEdit,
  });

  final String yearId, yearLabel;
  final bool canEdit;

  @override
  ConsumerState<ExamClosureSection> createState() => _ExamClosureSectionState();
}

class _ExamClosureSectionState extends ConsumerState<ExamClosureSection> {
  String? _openClassId;
  bool _busy = false;

  void _refresh() {
    ref.invalidate(examClosureClassesProvider(widget.yearId));
    if (_openClassId != null) {
      ref.invalidate(examClosureSessionProvider(_openClassId!));
    }
  }

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

  Future<void> _run(
      Future<int> Function() action, String Function(int) msg) async {
    setState(() => _busy = true);
    var n = 0;
    await runModuleWrite(context, () async => n = await action());
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg(n)),
      backgroundColor: n == 0 ? kTextMuted : kGreen,
    ));
    _refresh();
  }

  Future<void> _apply(ExamClosureSession s) async {
    final id = _identity();
    if (id == null) return;
    await _run(
      () => applyExamResults(session: s, actorId: id.actorId),
      (n) => n == 0
          ? 'Aucun résultat à reporter — tout est déjà décidé, ou la '
              'proclamation n\'est pas encore enregistrée.'
          : '$n décision(s) reportée(s) depuis la proclamation.',
    );
  }

  Future<void> _reenroll(ExamClosureSession s) async {
    final id = _identity();
    if (id == null) return;
    await _run(
      () => reenrollAfterExam(
        session: s,
        groupId: id.groupId,
        schoolId: id.schoolId,
        actorId: id.actorId,
      ),
      (n) => n == 0
          ? 'Aucune réinscription à créer.'
          : '$n élève(s) réinscrit(s) en ${s.nextYearLabel ?? 'année suivante'}.',
    );
  }

  Future<void> _graduate(ExamClosureSession s) async {
    final id = _identity();
    if (id == null) return;
    final n = s.leavers.length;
    final ok = await showAdminConfirm(
      context,
      title: 'Prononcer la sortie de $n diplômé(s) ?',
      message:
          'Ces élèves ont obtenu leur diplôme et l\'établissement n\'accueille '
          'pas le niveau suivant : leur scolarité ici se termine.\n\n'
          'Leur inscription ${widget.yearLabel} passera de « active » à '
          '« diplômée ». Ils quitteront donc les effectifs et les listes de '
          'classe. Leur dossier, leurs notes, leurs bulletins et leur '
          'candidature restent intacts.',
      confirmLabel: 'Prononcer la sortie',
      confirmIcon: Icons.workspace_premium_rounded,
      icon: Icons.school_rounded,
      danger: true,
    );
    if (!ok || !mounted) return;
    await _run(
      () => graduateLeavers(session: s, actorId: id.actorId),
      (n) => n == 0
          ? 'Aucune sortie à prononcer.'
          : '$n sortie(s) diplômée(s) prononcée(s).',
    );
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(examClosureClassesProvider(widget.yearId));
    return classes.when(
      loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(child: Text(messageErreur(e)))),
      data: _content,
    );
  }

  Widget _content(List<ExamClosureClass> rows) {
    if (rows.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.workspace_premium_outlined,
        title: 'Aucune classe d\'examen',
        message: 'Aucune classe de cette année ne prépare un examen d\'État. '
            'Toutes se décident au conseil de passage.',
      );
    }

    final students = rows.fold(0, (a, r) => a + r.students);
    final admitted = rows.fold(0, (a, r) => a + r.admitted);
    final failed = rows.fold(0, (a, r) => a + r.failed);
    final reenrolled = rows.fold(0, (a, r) => a + r.reenrolled);
    final proclaimed = admitted + failed;
    final waiting = rows.where((r) => r.awaitingProclamation).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Notice(
        color: kNavy,
        icon: Icons.gavel_rounded,
        text: 'Ici, l\'établissement ne délibère pas : il enregistre ce que la '
            'DEC a proclamé, puis en tire les conséquences. L\'admis passe — '
            'dans l\'établissement s\'il y accueille le niveau suivant, hors '
            'de lui sinon. L\'ajourné et l\'absent redoublent, et se '
            'réinscrivent sans qu\'on ait à ressaisir leur dossier.',
      ),
      const SizedBox(height: 16),
      EvalHeroKpis(cards: [
        (
          Icons.workspace_premium_rounded,
          'Classes d\'examen',
          '${rows.length}',
          const Color(0xFF8B5CF6),
          waiting == 0
              ? 'résultats reçus'
              : '$waiting en attente de proclamation'
        ),
        (Icons.groups_2_rounded, 'Élèves concernés', '$students', kNavy,
            '${rows.length} classes'),
        (
          Icons.verified_rounded,
          'Admis',
          '$admitted',
          kGreen,
          proclaimed == 0
              ? 'aucun résultat enregistré'
              : '${(admitted * 100 / proclaimed).round()} % des proclamés'
        ),
        (Icons.how_to_reg_rounded, 'Réinscrits', '$reenrolled', kAccent,
            '$failed ajourné(s) à réinscrire'),
      ]),
      const SizedBox(height: 18),
      if (_openClassId == null) ...[
        const EvalSectionLabel(
            icon: Icons.touch_app_rounded,
            text: 'Ouvrez une classe pour la clore'),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 1100 ? 4 : (c.maxWidth > 760 ? 3 : 2);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 124,
            ),
            itemCount: rows.length,
            itemBuilder: (_, i) => _ExamClassCard(
              row: rows[i],
              onOpen: () => setState(() => _openClassId = rows[i].classId),
            ),
          );
        }),
      ] else
        _ClassClosure(
          classId: _openClassId!,
          className: rows
                  .where((r) => r.classId == _openClassId)
                  .map((r) => r.className)
                  .firstOrNull ??
              '',
          canEdit: widget.canEdit,
          busy: _busy,
          onClose: () => setState(() => _openClassId = null),
          onApply: _apply,
          onReenroll: _reenroll,
          onGraduate: _graduate,
        ),
    ]);
  }
}

// ─── Carte de classe ─────────────────────────────────────────────────────────

class _ExamClassCard extends StatelessWidget {
  const _ExamClassCard({required this.row, required this.onOpen});
  final ExamClosureClass row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final proclaimed = row.admitted + row.failed;
    return AdminCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(row.className,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                ),
                if (row.qualifyPending)
                  Icon(Icons.help_outline_rounded, size: 15, color: kAccent),
              ]),
              if ((row.filiereLabel ?? '').isNotEmpty)
                Text(row.filiereLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: kTextMuted)),
              const Spacer(),
              if (row.awaitingProclamation)
                Text(
                  row.pending > 0
                      ? '${row.students} élèves · résultats attendus'
                      : '${row.students} élèves · aucun candidat',
                  style: TextStyle(fontSize: 11, color: kTextMuted),
                )
              else
                Row(children: [
                  _pill('${row.admitted} admis', kGreen),
                  const SizedBox(width: 6),
                  _pill('${row.failed} ajournés', kRed),
                ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: row.students == 0
                          ? 0
                          : (row.reenrolled / row.students).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: kBorder,
                      valueColor: AlwaysStoppedAnimation(
                          proclaimed == 0 ? kTextMuted : kAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${row.reenrolled}/${row.students} réinscrits',
                    style: TextStyle(fontSize: 10, color: kTextMuted)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(t,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: c)),
      );
}

// ─── Clôture d'une classe ────────────────────────────────────────────────────

class _ClassClosure extends ConsumerWidget {
  const _ClassClosure({
    required this.classId,
    required this.className,
    required this.canEdit,
    required this.busy,
    required this.onClose,
    required this.onApply,
    required this.onReenroll,
    required this.onGraduate,
  });

  final String classId, className;
  final bool canEdit, busy;
  final VoidCallback onClose;
  final void Function(ExamClosureSession) onApply, onReenroll, onGraduate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(examClosureSessionProvider(classId));
    return async.when(
      loading: () => const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Center(child: Text(messageErreur(e)))),
      data: (s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.arrow_back_rounded, size: 18, color: kTextMuted),
              tooltip: 'Toutes les classes d\'examen',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(className,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary)),
                  if (s.examLabel != null)
                    Text(s.examLabel!,
                        style: TextStyle(fontSize: 11.5, color: kTextMuted)),
                ],
              ),
            ),
            if (canEdit) ...[
              OutlinedButton.icon(
                onPressed:
                    busy || s.reportableCount == 0 ? null : () => onApply(s),
                icon: const Icon(Icons.download_done_rounded, size: 15),
                label: Text(s.reportableCount == 0
                    ? 'Résultats reportés'
                    : 'Reporter ${s.reportableCount} résultat(s)'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: kNavy),
                onPressed: busy || !s.canReenroll || s.decidedCount == 0
                    ? null
                    : () => onReenroll(s),
                icon: const Icon(Icons.how_to_reg_rounded, size: 15),
                label: const Text('Réinscrire'),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          ..._notices(context, s),
          AdminCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: kNavy.withValues(alpha: 0.04),
                  border: Border(bottom: BorderSide(color: kBorder)),
                ),
                child: Row(children: [
                  Expanded(flex: 4, child: _h('ÉLÈVE')),
                  const SizedBox(width: 8),
                  SizedBox(width: 108, child: _h('N° CANDIDAT')),
                  SizedBox(width: 116, child: _h('RÉSULTAT')),
                  Expanded(flex: 3, child: _h('SUITE DONNÉE')),
                  const SizedBox(width: 96),
                ]),
              ),
              if (s.entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text('Aucun élève dans cette classe.',
                      style: TextStyle(fontSize: 12.5, color: kTextMuted)),
                ),
              for (var i = 0; i < s.entries.length; i++) ...[
                if (i > 0) Divider(height: 1, color: kBorder),
                _EntryRow(entry: s.entries[i], session: s),
              ],
            ]),
          ),
          if (canEdit && s.leavers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _LeaversPanel(
              count: s.leavers.length,
              busy: busy,
              onGraduate: () => onGraduate(s),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _notices(BuildContext context, ExamClosureSession s) {
    final out = <Widget>[];
    void add(Color c, IconData i, String t) {
      out
        ..add(_Notice(color: c, icon: i, text: t))
        ..add(const SizedBox(height: 12));
    }

    if (s.qualifyPending) {
      add(
        kAccent,
        Icons.help_outline_rounded,
        'Cette classe est marquée « à qualifier » : le système n\'a pas su '
        'dire si elle mène à un examen d\'État. Elle n\'apparaît donc ni au '
        'conseil de passage ni de plein droit ici. Faites-la rattacher à un '
        'examen, ou basculez-la en classe de passage, avant de clore l\'année.',
      );
    }
    if (s.pendingCount > 0) {
      add(
        kTextMuted,
        Icons.hourglass_empty_rounded,
        '${s.pendingCount} candidat(s) sans résultat proclamé. Leur sort ne '
        'peut pas être réglé : enregistrez d\'abord la proclamation dans le '
        'module Examens.',
      );
    }
    if (s.notPresentedCount > 0) {
      add(
        kAccent,
        Icons.person_search_rounded,
        '${s.notPresentedCount} élève(s) de cette classe n\'ont pas été '
        'présentés à l\'examen. Aucune proposition n\'est faite pour eux : '
        'leur décision revient entièrement à l\'établissement.',
      );
    }
    if (s.nextYearId == null) {
      add(
        kRed,
        Icons.event_busy_rounded,
        // Même correction que dans l'onglet Passage : « non déclarée » était un
        // diagnostic, et il était faux une fois sur deux. Une année créée mais
        // laissée en BROUILLON par le groupe ne descend pas sur les postes
        // (sync-rules : `published_at IS NOT NULL`). L'école la cherchait alors
        // du mauvais côté.
        'Aucune année scolaire suivante n\'est disponible sur ce poste — soit '
        'elle n\'a pas été créée, soit elle n\'a pas été publiée par le '
        'groupe. Les décisions s\'enregistrent malgré tout ; seule la '
        'réinscription attend.',
      );
    } else if (!s.nextYearHasStructure) {
      // Le message qui manquait. Sans lui, l'écran lisait l'absence de
      // structure comme un établissement sans niveau suivant, et proposait de
      // faire sortir toute une classe d'admis qu'il accueille pourtant.
      add(
        kAccent,
        Icons.class_outlined,
        'Aucune classe n\'existe encore en ${s.nextYearLabel} : la structure '
        'de l\'année d\'accueil n\'a pas été reconduite. Tant qu\'elle manque, '
        'la destination des élèves reste inconnue — ni redoublement ni sortie '
        'ne peuvent être prononcés. Reconduisez-la depuis l\'onglet '
        '« Classes de passage ».',
      );
    } else if (s.repeatClass == null && s.failedCount > 0) {
      add(
        kAccent,
        Icons.class_outlined,
        'La classe de ${s.nextYearLabel} qui accueillerait les redoublants '
        'n\'existe pas encore. Les ${s.failedCount} ajourné(s) n\'ont donc '
        'nulle part où se réinscrire.',
      );
    }
    if (s.admittedLeave && s.admittedCount > 0) {
      add(
        kGreen,
        Icons.flight_takeoff_rounded,
        'L\'établissement n\'accueille pas le niveau suivant en '
        '${s.nextYearLabel} : les ${s.admittedCount} admis quittent l\'école '
        'avec leur diplôme. Prononcez leur sortie en bas de page.',
      );
    }
    return out;
  }

  Widget _h(String t, {TextAlign align = TextAlign.left}) => Text(t,
      textAlign: align,
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: kTextMuted));
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.session});
  final ExamClosureEntry entry;
  final ExamClosureSession session;

  @override
  Widget build(BuildContext context) {
    final tone = examResultTone(entry.result);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
              if ((entry.matricule ?? '').isNotEmpty)
                Text(entry.matricule!,
                    style: TextStyle(fontSize: 10.5, color: kTextMuted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 108,
          child: Text(
            entry.candidateNumber ?? '—',
            style: TextStyle(
                fontSize: 11.5,
                color: entry.candidateNumber == null ? kTextMuted : kTextPrimary),
          ),
        ),
        SizedBox(
          width: 116,
          child: Row(children: [
            Icon(tone.icon, size: 14, color: tone.color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                entry.examAverage == null
                    ? tone.label
                    : '${tone.label} · ${entry.examAverage!.toStringAsFixed(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: tone.color),
              ),
            ),
          ]),
        ),
        Expanded(flex: 3, child: _outcome()),
        SizedBox(
          width: 96,
          child: entry.graduated
              ? _tag('Sorti(e)', kGreen)
              : entry.reenrolled
                  ? _tag('Réinscrit', kAccent)
                  : const SizedBox.shrink(),
        ),
      ]),
    );
  }

  Widget _outcome() {
    if (entry.graduated) {
      return _line(Icons.workspace_premium_rounded, kGreen,
          'Sortie diplômée prononcée');
    }
    final code = entry.decision ?? entry.suggestion;
    if (code == null) {
      return Text(
        entry.presented
            ? 'En attente de la proclamation'
            : 'Décision de l\'établissement',
        style: TextStyle(fontSize: 11.5, color: kTextMuted),
      );
    }
    final proposed = !entry.decided;
    if (code == 'passe') {
      // Une décision PRISE porte sa classe d'accueil ; une décision PROPOSÉE
      // n'en a pas encore, il faut donc regarder celle que le report lui
      // donnerait. Confondre les deux ferait annoncer « quitte
      // l'établissement » à tout admis avant même le report.
      final hasTarget = entry.decided
          ? entry.targetClassId != null
          : session.nextLevelClass != null;
      return _line(
        Icons.arrow_upward_rounded,
        kGreen,
        hasTarget
            ? 'Passe en ${session.nextLevelClass?.name ?? 'classe supérieure'}'
            : session.nextYearHasStructure
                ? 'Passe — quitte l\'établissement'
                : 'Passe — destination à établir',
        proposed: proposed,
      );
    }
    return _line(
      Icons.replay_rounded,
      kRed,
      session.repeatClass == null
          ? 'Redouble — classe d\'accueil à créer'
          : 'Redouble en ${session.repeatClass!.name}',
      proposed: proposed,
    );
  }

  Widget _line(IconData i, Color c, String t, {bool proposed = false}) => Row(
        children: [
          Icon(i, size: 14, color: c),
          const SizedBox(width: 6),
          Flexible(
            child: Text(t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: proposed ? kTextMuted : kTextPrimary)),
          ),
          if (proposed) ...[
            const SizedBox(width: 6),
            Text('proposé',
                style: TextStyle(
                    fontSize: 9.5,
                    fontStyle: FontStyle.italic,
                    color: kTextMuted)),
          ],
        ],
      );

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(t,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: c)),
      );
}

class _LeaversPanel extends StatelessWidget {
  const _LeaversPanel({
    required this.count,
    required this.busy,
    required this.onGraduate,
  });
  final int count;
  final bool busy;
  final VoidCallback onGraduate;

  @override
  Widget build(BuildContext context) => AdminCard(
        child: Row(children: [
          Icon(Icons.workspace_premium_rounded, size: 20, color: kGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$count diplômé(s) quittent l\'établissement',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                const SizedBox(height: 2),
                Text(
                  'Leur scolarité ici est terminée. Prononcer la sortie ferme '
                  'leur inscription : ils sortent des effectifs, leur dossier '
                  'reste consultable.',
                  style: TextStyle(fontSize: 11.5, color: kTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: kGreen),
            onPressed: busy ? null : onGraduate,
            icon: const Icon(Icons.school_rounded, size: 15),
            label: const Text('Prononcer la sortie'),
          ),
        ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.color, required this.icon, required this.text});
  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          border: Border.all(color: color.withValues(alpha: 0.25)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12, height: 1.45, color: kTextPrimary)),
          ),
        ]),
      );
}
