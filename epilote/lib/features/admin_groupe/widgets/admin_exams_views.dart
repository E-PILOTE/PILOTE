import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/admin_exams_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  VUES DE « EXAMENS NATIONAUX » — graphique, tableau, cartes, états vides.
//
//  Extraites de l'écran, qui dépassait 500 lignes en mêlant sa logique de
//  filtrage à cinq présentations distinctes. La coupure suit une couture
//  naturelle : l'écran décide QUOI montrer, ces widgets décident COMMENT.
// ════════════════════════════════════════════════════════════════════════════

class ExamChart extends StatelessWidget {
  const ExamChart({super.key, required this.bars, required this.yearLabel});
  final List<MinistryExamBar> bars;
  final String? yearLabel;

  @override
  Widget build(BuildContext context) {
    final data = bars.where((b) => b.candidates > 0).toList();
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(Icons.bar_chart_rounded, size: 20, color: kTextMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aucun candidat déclaré sur le réseau — le graphique se remplira à '
              'mesure que les écoles inscrivent.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted),
            ),
          ),
        ]),
      );
    }
    return Container(
      height: 260,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: SfCartesianChart(
        title: ChartTitle(
          text: 'Candidats par examen'
              '${yearLabel != null ? ' · $yearLabel' : ''}',
          alignment: ChartAlignment.near,
          textStyle: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
        ),
        plotAreaBorderWidth: 0,
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: TextStyle(fontSize: 10.5, color: kTextMuted),
          axisLine: AxisLine(color: kBorder),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: MajorGridLines(width: 0.5, color: kBorder),
          axisLine: const AxisLine(width: 0),
          labelStyle: TextStyle(fontSize: 10.5, color: kTextMuted),
        ),
        tooltipBehavior: TooltipBehavior(enable: true),
        series: <CartesianSeries<MinistryExamBar, String>>[
          ColumnSeries<MinistryExamBar, String>(
            name: 'Candidats',
            dataSource: data,
            xValueMapper: (b, _) => b.examShortName,
            yValueMapper: (b, _) => b.candidates,
            pointColorMapper: (b, _) => b.tutelle == 'mepsa' ? kAccent : kNavy,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            // `width` = fraction du créneau : rétrécie quand les barres sont
            // rares, sinon une seule colonne mange tout le graphique.
            width: switch (data.length) {
              1 => 0.12,
              2 => 0.22,
              <= 4 => 0.38,
              _ => 0.55,
            },
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(fontSize: 10, color: kTextMuted),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tableau ──────────────────────────────────────────────────────────────────
class SchoolsTable extends StatelessWidget {
  const SchoolsTable({super.key, required this.rows});
  final List<MinistrySchoolExam> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: kNavy.withValues(alpha: 0.04),
          child: Row(children: [
            _h('ÉCOLE', flex: 5),
            _h('CANDIDATS', flex: 2),
            _h('COMPLETS', flex: 2),
            _h('DÉPOSÉS', flex: 2),
            _h('TRANSMIS', flex: 2),
            _h('RÉSULTATS', flex: 2),
          ]),
        ),
        for (var i = 0; i < rows.length; i++)
          _SchoolRow(row: rows[i], striped: i.isOdd),
      ]),
    );
  }

  Widget _h(String t, {required int flex}) => Expanded(
        flex: flex,
        child: Text(t,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: kTextMuted)),
      );
}

class _SchoolRow extends StatelessWidget {
  const _SchoolRow({required this.row, required this.striped});
  final MinistrySchoolExam row;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: striped ? kNavy.withValues(alpha: 0.02) : null,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: Row(children: [
            if (row.hasCandidatesNotTransmitted) ...[
              Icon(Icons.circle, size: 8, color: kRed),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(row.schoolName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ),
          ]),
        ),
        _num('${row.candidates}', flex: 2, color: kTextPrimary, bold: true),
        _num('${row.complete}',
            flex: 2,
            color: row.complete == row.candidates ? kGreen : kListOrange),
        _num('${row.submitted}', flex: 2, color: kTextMuted),
        Expanded(
          flex: 2,
          child: row.transmissions > 0
              ? _Chip('${row.transmissions}', kGreen)
              : (row.candidates > 0
                  ? _Chip('aucune', kRed)
                  : Text('—', style: TextStyle(color: kTextMuted))),
        ),
        _num(row.withResult > 0 ? '${row.withResult}' : '—',
            flex: 2, color: row.withResult > 0 ? kListPurple : kTextMuted),
      ]),
    );
  }

  Widget _num(String t, {required int flex, required Color color, bool bold = false}) =>
      Expanded(
        flex: flex,
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color)),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ),
      );
}

// ─── Cartes ───────────────────────────────────────────────────────────────────
class SchoolsCards extends StatelessWidget {
  const SchoolsCards({super.key, required this.rows});
  final List<MinistrySchoolExam> rows;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 1100 ? 3 : (c.maxWidth > 720 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          mainAxisExtent: 150,
        ),
        itemCount: rows.length,
        itemBuilder: (_, i) => _SchoolCard(row: rows[i]),
      );
    });
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.row});
  final MinistrySchoolExam row;

  @override
  Widget build(BuildContext context) {
    final risk = row.hasCandidatesNotTransmitted;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: risk ? kRed.withValues(alpha: 0.5) : kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(row.schoolName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            if (risk) Icon(Icons.report_problem_rounded, size: 18, color: kRed),
          ]),
          const Spacer(),
          Row(children: [
            _stat('${row.candidates}', 'candidats', kNavy),
            _stat('${row.complete}', 'complets',
                row.complete == row.candidates ? kGreen : kListOrange),
            _stat('${row.transmissions}', 'transmis',
                row.transmissions > 0 ? kGreen : kRed),
            _stat(row.withResult > 0 ? '${row.withResult}' : '—', 'résultats',
                kListPurple),
          ]),
        ],
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(fontSize: 10.5, color: kTextMuted)),
        ]),
      );
}

// ─── États ────────────────────────────────────────────────────────────────────
class ExamsEmptyView extends StatelessWidget {
  const ExamsEmptyView({super.key, required this.hasData});
  final bool hasData;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          Icon(Icons.school_outlined, size: 34, color: kTextMuted),
          const SizedBox(height: 12),
          Text(
            hasData
                ? 'Aucune école ne correspond au filtre.'
                : 'Aucune candidature déclarée sur le réseau pour l\'instant.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kTextMuted),
          ),
        ]),
      );
}

class ExamsErrorView extends StatelessWidget {
  const ExamsErrorView({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: kRed, size: 40),
          const SizedBox(height: 12),
          Text('Erreur : $message',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextMuted)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      );
}
