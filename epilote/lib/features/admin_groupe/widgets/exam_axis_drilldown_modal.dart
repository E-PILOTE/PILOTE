import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_exams_provider.dart';
import '../providers/ministry_exam_rows.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LES ÉCOLES D'UN AXE — ce qu'il y a derrière « Mécanique · 42 % ».
//
//  Les deux ventilations du cockpit étaient des culs-de-sac : elles nommaient
//  le problème sans jamais le localiser. Or la question qui suit « la mécanique
//  est à 42 % » est toujours « dans quelles écoles ». Faute de réponse, on
//  quittait l'écran ou on téléphonait.
//
//  ── L'ORDRE EST LE SUJET ────────────────────────────────────────────────────
//  Les taux CONNUS d'abord, du meilleur au pire, puis les écoles dont rien
//  n'est encore proclamé. Les mêler reviendrait à ranger « on ne sait pas »
//  avec « c'est mauvais » — et le ministère relancerait des établissements
//  irréprochables sur la foi d'un classement.
//
//  Aucune requête : ce sont les lignes déjà chargées par le cockpit.
// ════════════════════════════════════════════════════════════════════════════
Future<void> showExamAxisDrilldown(
  BuildContext context, {
  required ExamAxis axis,
  required String label,
  required String? examLabel,
  required List<AxisSchoolLine> schools,
  Widget? exportButton,
}) =>
    showAdminBottomModal<void>(
      context,
      builder: (_) => _AxisSheet(
        axis: axis,
        label: label,
        examLabel: examLabel,
        schools: schools,
        exportButton: exportButton,
      ),
    );

class _AxisSheet extends StatelessWidget {
  const _AxisSheet({
    required this.axis,
    required this.label,
    required this.examLabel,
    required this.schools,
    this.exportButton,
  });

  final ExamAxis axis;
  final String label;
  final String? examLabel;
  final List<AxisSchoolLine> schools;
  final Widget? exportButton;

  @override
  Widget build(BuildContext context) {
    final candidates = schools.fold<int>(0, (s, e) => s + e.candidates);
    final known = schools.fold<int>(0, (s, e) => s + e.known);
    final admitted = schools.fold<int>(0, (s, e) => s + e.admitted);
    final rate = known == 0 ? null : admitted / known * 100;
    final atRisk = schools.where((s) => !s.transmitted).length;

    return AdminBottomModal(
      icon: axis == ExamAxis.filiere
          ? Icons.category_rounded
          : Icons.public_rounded,
      accent: kNavy,
      title: label,
      subtitle: [
        'réussite par ${axis.label}',
        ?examLabel,
        '$candidates candidat(s)',
        // Le taux ne s'affiche JAMAIS sans son assiette : « 42 % » sur trois
        // résultats connus pour cent candidats serait un mensonge de
        // présentation.
        if (rate != null)
          '${rate.toStringAsFixed(1)} % · $admitted/$known connus'
        else
          'aucun résultat proclamé',
      ].join('  ·  '),
      maxWidth: 880,
      heightFactor: 0.8,
      footer: _Footer(atRisk: atRisk, exportButton: exportButton),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (schools.isEmpty)
          const _Muted('Aucun établissement ne présente de candidat sur cet axe.')
        else ...[
          const _Header(),
          for (var i = 0; i < schools.length; i++)
            _SchoolLine(line: schools[i], striped: i.isOdd),
        ],
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kNavy.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Row(children: [
          _h('ÉTABLISSEMENT', 34),
          _h('CAND.', 10, end: true),
          _h('ADMIS', 10, end: true),
          // Le même retrait que la cellule de taux : sans lui, « ADMIS »
          // aligné à droite et « TAUX » aligné à gauche se touchent, et
          // l'en-tête se lit « ADMISTAUX ».
          _h('TAUX', 32, indent: 12),
          const SizedBox(width: 108),
        ]),
      );

  static Widget _h(String t, int flex, {bool end = false, double indent = 0}) =>
      Expanded(
        flex: flex,
        child: Padding(
          padding: EdgeInsets.only(left: indent),
          child: Text(t,
            textAlign: end ? TextAlign.end : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                color: kTextMuted)),
        ),
      );
}

class _SchoolLine extends ConsumerStatefulWidget {
  const _SchoolLine({required this.line, required this.striped});
  final AxisSchoolLine line;
  final bool striped;

  @override
  ConsumerState<_SchoolLine> createState() => _SchoolLineState();
}

class _SchoolLineState extends ConsumerState<_SchoolLine> {
  bool _sending = false;
  bool _done = false;

  static const _amber = Color(0xFFF59E0B);

  /// Même code couleur que la card d'origine : passer d'une vue à l'autre ne
  /// doit pas changer la signification du vert.
  static Color _rateColor(double? r) {
    if (r == null) return kTextMuted;
    if (r >= 0.70) return kGreen;
    if (r >= 0.50) return _amber;
    return kRed;
  }

  Future<void> _remind() async {
    setState(() => _sending = true);
    try {
      final n = await ref.read(ministryExamActionsProvider).remindSchools([
        MinistrySchoolExam(
          schoolId: widget.line.schoolId,
          schoolName: widget.line.schoolName,
          candidates: widget.line.candidates,
          complete: 0,
          submitted: 0,
          withResult: widget.line.known,
          admitted: widget.line.admitted,
          transmissions: 0,
          lastTransmittedAt: null,
          department: widget.line.department,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _done = n > 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 0
            ? 'Aucun chef d\'établissement enregistré pour cette école : '
                'la relance ne peut pas être adressée.'
            : 'Relance envoyée au chef d\'établissement.'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Envoi impossible : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.line;
    final rate = l.rate;
    final color = _rateColor(rate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: widget.striped ? kNavy.withValues(alpha: 0.02) : null,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Expanded(
          flex: 34,
          child: Row(children: [
            if (!l.transmitted) ...[
              Icon(Icons.report_problem_rounded, size: 14, color: kRed),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(l.schoolName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
          ]),
        ),
        _c('${l.candidates}', 10, end: true),
        _c('${l.admitted}', 10, end: true),
        Expanded(
          flex: 32,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: rate == null
                ? Text('en attente',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: kTextMuted))
                : Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(children: [
                          Container(
                              height: 10,
                              color: color.withValues(alpha: 0.10)),
                          FractionallySizedBox(
                            widthFactor: rate.clamp(0.0, 1.0),
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 46,
                      child: Text('${(rate * 100).toStringAsFixed(1)} %',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: color)),
                    ),
                  ]),
          ),
        ),
        SizedBox(
          width: 108,
          child: Align(
            alignment: Alignment.centerRight,
            child: l.transmitted
                ? Text('transmis',
                    style: TextStyle(fontSize: 11, color: kTextMuted))
                : _done
                    ? Text('relancée',
                        style: TextStyle(fontSize: 11, color: kGreen))
                    : TextButton.icon(
                        onPressed: _sending ? null : _remind,
                        icon: _sending
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.notifications_active_rounded,
                                size: 14),
                        label: const Text('Relancer'),
                        style: TextButton.styleFrom(
                          foregroundColor: kRed,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                          textStyle: const TextStyle(fontSize: 11.5),
                        ),
                      ),
          ),
        ),
      ]),
    );
  }

  static Widget _c(String t, int flex, {bool end = false}) => Expanded(
        flex: flex,
        child: Text(t,
            textAlign: end ? TextAlign.end : TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: kTextPrimary)),
      );
}

class _Footer extends StatelessWidget {
  const _Footer({required this.atRisk, this.exportButton});
  final int atRisk;
  final Widget? exportButton;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(
            atRisk == 0
                ? 'Tous ces établissements ont transmis à la DEC.'
                : '$atRisk établissement(s) n\'ont rien transmis : après la '
                    'clôture, ces candidatures sont perdues pour l\'année.',
            style: TextStyle(
                fontSize: 11.5, color: atRisk == 0 ? kTextMuted : kRed),
          ),
        ),
        const SizedBox(width: 12),
        ?exportButton,
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('Fermer'),
          style: TextButton.styleFrom(foregroundColor: kTextMuted),
        ),
      ]);
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
