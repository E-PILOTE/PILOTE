import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/admin_exams_provider.dart';
import '../providers/exam_archives_provider.dart';
import 'school_candidates_section.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FICHE D'ÉTABLISSEMENT — le détail derrière une ligne du cockpit.
//
//  Le tableau du réseau dit « 12 candidats, 8 complets, aucune transmission ».
//  Il ne disait pas de QUELS examens il s'agit, ni ce que la DEC a proclamé
//  pour cette école — deux questions qu'on se pose immédiatement après. Les
//  lignes étaient des culs-de-sac : on repartait vers un autre écran, ou on
//  téléphonait.
//
//  Trois strates, dans l'ordre où on les lit :
//   1. l'état de la campagne (dossiers, dépôts, transmission) ;
//   2. la ventilation par examen — c'est là qu'un retard se localise ;
//   3. les chiffres OFFICIELS de la DEC pour cet établissement, quand elle en
//      publie (elle publie par école, avec son code). Absents ≠ nuls : l'écran
//      le dit.
// ════════════════════════════════════════════════════════════════════════════
void showSchoolExamModal(BuildContext context, MinistrySchoolExam row) {
  showAdminBottomModal<void>(
    context,
    builder: (_) => _SchoolSheet(row: row),
  );
}

class _SchoolSheet extends ConsumerWidget {
  const _SchoolSheet({required this.row});
  final MinistrySchoolExam row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risk = row.hasCandidatesNotTransmitted;
    // Chiffres officiels de CET établissement — le troisième niveau de
    // publication de la DEC, à côté du national et du départemental.
    final official = (ref.watch(officialFiguresProvider).valueOrNull ?? const [])
        .where((f) =>
            f.scope == PubScope.etablissement && f.schoolId == row.schoolId)
        .toList()
      ..sort((a, b) => (b.yearLabel ?? '').compareTo(a.yearLabel ?? ''));

    return AdminBottomModal(
      icon: Icons.account_balance_rounded,
      accent: risk ? kRed : kNavy,
      title: row.schoolName,
      subtitle: [
        if (row.department != null) row.department!,
        '${row.candidates} candidat(s) déclaré(s)',
        if (row.lastTransmittedAt != null)
          'dernière transmission le ${_d(row.lastTransmittedAt!)}',
      ].join('  ·  '),
      maxWidth: 900,
      heightFactor: 0.82,
      footer: _Footer(row: row),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (risk) ...[
          _RiskBanner(candidates: row.candidates),
          const SizedBox(height: 16),
        ],
        _Chips(row: row),
        const SizedBox(height: 20),
        const AdminModalSectionTitle('Ventilation par examen'),
        const SizedBox(height: 10),
        if (row.byExam.isEmpty)
          const _Muted('Aucun examen rattaché à cet établissement.')
        else
          _ExamTable(lines: row.byExam),
        const SizedBox(height: 22),
        // « 8 complets sur 12 » ne se traite pas. La liste nominative, avec
        // les pièces qui manquent, transforme la relance en instruction.
        const AdminModalSectionTitle('Candidats de l\'établissement'),
        const SizedBox(height: 10),
        SchoolCandidatesSection(schoolId: row.schoolId),
        const SizedBox(height: 22),
        const AdminModalSectionTitle('Ce que la DEC a proclamé pour cette école'),
        const SizedBox(height: 10),
        if (official.isEmpty)
          const _Muted(
            'Aucune publication de la DEC n\'a été relevée pour cet '
            'établissement. La DEC publie école par école, avec un code '
            'établissement : dès qu\'une de ces listes est archivée et ses '
            'chiffres relevés, ils s\'affichent ici. Leur absence ne veut pas '
            'dire zéro.',
          )
        else
          for (final f in official) _OfficialRow(figure: f),
      ]),
    );
  }

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ─── Alerte ─────────────────────────────────────────────────────────────────
class _RiskBanner extends StatelessWidget {
  const _RiskBanner({required this.candidates});
  final int candidates;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: kRed.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.report_problem_rounded, size: 20, color: kRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$candidates candidat(s) déclaré(s), aucune transmission à la '
              'DEC. Après la clôture des dépôts, ces candidatures sont perdues '
              'pour l\'année — c\'est la seule alerte irrattrapable de la '
              'campagne.',
              style: TextStyle(fontSize: 12.5, color: kTextPrimary, height: 1.45),
            ),
          ),
        ]),
      );
}

// ─── État de la campagne ────────────────────────────────────────────────────
class _Chips extends StatelessWidget {
  const _Chips({required this.row});
  final MinistrySchoolExam row;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (ctx, c) {
        final tiles = [
          _Tile(
            label: 'Candidats',
            value: '${row.candidates}',
            sub: '${row.byExam.length} examen(s)',
            color: kNavy,
            icon: Icons.groups_rounded,
          ),
          _Tile(
            label: 'Dossiers complets',
            value: '${row.complete}',
            sub: row.incomplete == 0
                ? 'aucun incomplet'
                : '${row.incomplete} incomplet(s)',
            color: row.incomplete == 0 ? kGreen : kListOrange,
            icon: Icons.folder_shared_rounded,
          ),
          _Tile(
            label: 'Déposés',
            value: '${row.submitted}',
            sub: 'validés par le chef d\'établissement',
            color: kAccent,
            icon: Icons.assignment_turned_in_rounded,
          ),
          _Tile(
            label: 'Transmissions',
            value: '${row.transmissions}',
            sub: row.transmissions == 0 ? 'aucun dépôt' : 'dépôts opposables',
            color: row.transmissions > 0 ? kGreen : kRed,
            icon: Icons.outbox_rounded,
          ),
          _Tile(
            label: 'Résultats connus',
            value: '${row.withResult}',
            sub: row.pending > 0
                ? '${row.pending} en attente'
                : 'tous proclamés',
            color: kListPurple,
            icon: Icons.workspace_premium_rounded,
          ),
        ];
        final cols = c.maxWidth > 820 ? 5 : (c.maxWidth > 520 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 92,
          ),
          itemCount: tiles.length,
          itemBuilder: (_, i) => tiles[i],
        );
      });
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });
  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: kBorder),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: kTextMuted)),
                ),
              ]),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: kTextMuted)),
            ]),
      );
}

// ─── Ventilation par examen ─────────────────────────────────────────────────
class _ExamTable extends StatelessWidget {
  const _ExamTable({required this.lines});
  final List<SchoolExamLine> lines;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(11),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: kNavy.withValues(alpha: 0.05),
            child: Row(children: [
              _h('EXAMEN', 30),
              _h('CANDIDATS', 16, end: true),
              _h('COMPLETS', 16, end: true),
              _h('DÉPOSÉS', 16, end: true),
              _h('RÉSULTATS', 22, end: true),
            ]),
          ),
          for (var i = 0; i < lines.length; i++)
            _ExamRow(line: lines[i], striped: i.isOdd),
        ]),
      );

  static Widget _h(String t, int flex, {bool end = false}) => Expanded(
        flex: flex,
        child: Text(t,
            textAlign: end ? TextAlign.end : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: kTextMuted)),
      );
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.line, required this.striped});
  final SchoolExamLine line;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    final rate = line.successRate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: striped ? kNavy.withValues(alpha: 0.02) : null,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        _c(line.examShortName, 30, bold: true),
        _c('${line.candidates}', 16, end: true),
        _c('${line.complete}', 16,
            end: true,
            color: line.complete == line.candidates ? kGreen : kListOrange),
        _c('${line.submitted}', 16, end: true, muted: true),
        Expanded(
          flex: 22,
          child: Text(
            // Le taux ne s'affiche jamais seul : « 100 % » sur 2 résultats
            // connus pour 30 candidats serait un mensonge de présentation.
            rate == null
                ? 'en attente'
                : '${rate.toStringAsFixed(0)} % · ${line.admitted}/${line.withResult} connus',
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: rate == null ? FontWeight.w500 : FontWeight.w800,
                fontStyle: rate == null ? FontStyle.italic : FontStyle.normal,
                color: rate == null ? kTextMuted : kListPurple),
          ),
        ),
      ]),
    );
  }

  static Widget _c(String t, int flex,
          {bool end = false,
          bool bold = false,
          bool muted = false,
          Color? color}) =>
      Expanded(
        flex: flex,
        child: Text(t,
            textAlign: end ? TextAlign.end : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color ?? (muted ? kTextMuted : kTextPrimary))),
      );
}

// ─── Chiffres officiels de l'école ──────────────────────────────────────────
class _OfficialRow extends StatelessWidget {
  const _OfficialRow({required this.figure});
  final OfficialFigure figure;

  @override
  Widget build(BuildContext context) {
    final rate = figure.passRate;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${figure.examShortName ?? '—'} · ${figure.yearLabel ?? '—'}',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary)),
            Text(
                figure.hasCounts
                    ? '${figure.admitted} admis sur ${figure.present} présents'
                    : 'taux publié, sans effectifs',
                style: TextStyle(fontSize: 11, color: kTextMuted)),
          ]),
        ),
        if (rate != null)
          Text('${rate.toStringAsFixed(2)} %',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: kGreen)),
        const SizedBox(width: 10),
        AdminBadge(figure.hasSource ? 'OFFICIEL DEC' : 'sans source',
            color: figure.hasSource ? kGreen : kListOrange),
      ]),
    );
  }
}

// ─── Pied : relance ─────────────────────────────────────────────────────────
class _Footer extends ConsumerStatefulWidget {
  const _Footer({required this.row});
  final MinistrySchoolExam row;

  @override
  ConsumerState<_Footer> createState() => _FooterState();
}

class _FooterState extends ConsumerState<_Footer> {
  bool _sending = false;

  Future<void> _remind() async {
    setState(() => _sending = true);
    try {
      final n = await ref
          .read(ministryExamActionsProvider)
          .remindSchools([widget.row]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 0
            ? 'Aucun chef d\'établissement enregistré pour cette école : '
                'la relance ne peut pas être adressée.'
            : 'Relance envoyée au chef d\'établissement.'),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Envoi impossible : $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final risk = widget.row.hasCandidatesNotTransmitted;
    return Row(children: [
      Expanded(
        child: Text(
          risk
              ? 'La relance part au chef d\'établissement, seul décideur du dépôt.'
              : 'Cet établissement a transmis. Rien n\'appelle de relance.',
          style: TextStyle(fontSize: 11.5, color: kTextMuted),
        ),
      ),
      const SizedBox(width: 12),
      if (risk)
        AdminPrimaryButton(
          label: 'Relancer l\'établissement',
          icon: Icons.notifications_active_rounded,
          color: kRed,
          saving: _sending,
          onTap: _remind,
        )
      else
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Fermer'),
          style: TextButton.styleFrom(foregroundColor: kTextMuted),
        ),
    ]);
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Text(text,
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.45)),
      );
}
