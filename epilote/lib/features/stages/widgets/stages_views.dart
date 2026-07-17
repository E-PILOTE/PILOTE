import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../examens/widgets/examens_widgets.dart' show formatDate;
import '../providers/stages_provider.dart';

// ════════════════════════════════════════════════════════════════════════════
//  STAGES — vues tableau/cartes + graphique, style page Administrateurs.
//  Extraites de l'écran pour tenir la règle des 500 lignes.
// ════════════════════════════════════════════════════════════════════════════

(Color, String) stageTone(InternshipStatus s) => switch (s) {
      InternshipStatus.enCours => (kGreen, 'En cours'),
      InternshipStatus.valide => (kGreen, 'Validé'),
      InternshipStatus.termine => (kNavy, 'Terminé'),
      InternshipStatus.interrompu => (kRed, 'Interrompu'),
      InternshipStatus.prevu => (kTextMuted, 'Prévu'),
    };

// ─── Graphique : répartition par statut ───────────────────────────────────────
class StagesStatusChart extends StatelessWidget {
  const StagesStatusChart({super.key, required this.internships});
  final List<InternshipRow> internships;

  @override
  Widget build(BuildContext context) {
    final counts = <InternshipStatus, int>{};
    for (final i in internships) {
      counts[i.status] = (counts[i.status] ?? 0) + 1;
    }
    final data = [
      for (final s in InternshipStatus.values)
        if ((counts[s] ?? 0) > 0) (label: stageTone(s).$2, value: counts[s]!, tone: stageTone(s).$1),
    ];

    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Icon(Icons.insights_rounded, size: 20, color: kTextMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Le graphique se remplira dès le premier stage enregistré.',
                style: TextStyle(fontSize: 12.5, color: kTextMuted)),
          ),
        ]),
      );
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: SfCartesianChart(
        title: ChartTitle(
          text: 'Stages par statut',
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
        series: <CartesianSeries<({String label, int value, Color tone}), String>>[
          ColumnSeries<({String label, int value, Color tone}), String>(
            dataSource: data,
            xValueMapper: (d, _) => d.label,
            yValueMapper: (d, _) => d.value,
            pointColorMapper: (d, _) => d.tone,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            width: switch (data.length) {
              1 => 0.12,
              2 => 0.22,
              <= 4 => 0.4,
              _ => 0.6,
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
class StagesTable extends StatelessWidget {
  const StagesTable({
    super.key,
    required this.rows,
    required this.canEdit,
    required this.onAttestation,
  });

  final List<InternshipRow> rows;
  final bool canEdit;
  final void Function(InternshipRow) onAttestation;

  @override
  Widget build(BuildContext context) => Container(
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
              _h('STAGIAIRE · ENTREPRISE', flex: 4),
              _h('PÉRIODE', flex: 3),
              _h('CONV.', flex: 1),
              _h('STATUT', flex: 2),
              _h('ATTEST.', flex: 1),
            ]),
          ),
          for (var i = 0; i < rows.length; i++)
            _Row(
                row: rows[i],
                striped: i.isOdd,
                canEdit: canEdit,
                onAttestation: onAttestation),
        ]),
      );

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

class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.striped,
    required this.canEdit,
    required this.onAttestation,
  });
  final InternshipRow row;
  final bool striped;
  final bool canEdit;
  final void Function(InternshipRow) onAttestation;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final (tone, label) = stageTone(r.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: striped ? kNavy.withValues(alpha: 0.02) : null,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.studentName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              Text(
                '${r.className ?? '—'} · ${r.companyName ?? 'entreprise non renseignée'}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: kTextMuted),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            r.startDate == null
                ? '—'
                : '${formatDate(r.startDate)} → ${formatDate(r.endDate)}',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ),
        Expanded(
          flex: 1,
          child: Icon(
              r.conventionSigned
                  ? Icons.check_circle_rounded
                  : Icons.remove_circle_outline_rounded,
              size: 16,
              color: r.conventionSigned ? kGreen : kTextMuted),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: tone)),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Align(
            alignment: Alignment.centerLeft,
            child: canEdit
                ? IconButton(
                    onPressed: () => onAttestation(r),
                    icon: Icon(
                        r.hasAttestation
                            ? Icons.verified_rounded
                            : (r.attestationOverdue
                                ? Icons.error_outline_rounded
                                : Icons.workspace_premium_outlined),
                        size: 18),
                    color: r.hasAttestation
                        ? kGreen
                        : (r.attestationOverdue ? kRed : kTextMuted),
                    tooltip: r.hasAttestation
                        ? 'Attestation délivrée'
                        : (r.attestationOverdue
                            ? 'Stage terminé — attestation à délivrer'
                            : 'Délivrer l\'attestation'),
                    visualDensity: VisualDensity.compact,
                  )
                : Icon(
                    r.hasAttestation
                        ? Icons.verified_rounded
                        : (r.attestationOverdue
                            ? Icons.error_outline_rounded
                            : Icons.remove_rounded),
                    size: 16,
                    color: r.hasAttestation
                        ? kGreen
                        : (r.attestationOverdue ? kRed : kTextMuted),
                  ),
          ),
        ),
      ]),
    );
  }
}

// ─── Cartes ───────────────────────────────────────────────────────────────────
class StagesCards extends StatelessWidget {
  const StagesCards({
    super.key,
    required this.rows,
    required this.canEdit,
    required this.onAttestation,
  });
  final List<InternshipRow> rows;
  final bool canEdit;
  final void Function(InternshipRow) onAttestation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth > 1100 ? 3 : (c.maxWidth > 720 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            mainAxisExtent: 158,
          ),
          itemCount: rows.length,
          itemBuilder: (_, i) =>
              _Card(row: rows[i], canEdit: canEdit, onAttestation: onAttestation),
        );
      });
}

class _Card extends StatelessWidget {
  const _Card({
    required this.row,
    required this.canEdit,
    required this.onAttestation,
  });
  final InternshipRow row;
  final bool canEdit;
  final void Function(InternshipRow) onAttestation;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final (tone, label) = stageTone(r.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: r.attestationOverdue ? kRed.withValues(alpha: 0.5) : kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(r.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700, color: tone)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(r.companyName ?? 'entreprise non renseignée',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: kTextMuted)),
          Text(
            '${r.className ?? '—'}'
            '${r.startDate != null ? ' · ${formatDate(r.startDate)} → ${formatDate(r.endDate)}' : ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: kTextMuted),
          ),
          const Spacer(),
          Row(children: [
            Icon(
                r.conventionSigned
                    ? Icons.description_rounded
                    : Icons.description_outlined,
                size: 15,
                color: r.conventionSigned ? kGreen : kTextMuted),
            const SizedBox(width: 4),
            Text('Convention', style: TextStyle(fontSize: 11, color: kTextMuted)),
            const Spacer(),
            if (canEdit)
              TextButton.icon(
                onPressed: () => onAttestation(r),
                icon: Icon(
                    r.hasAttestation
                        ? Icons.verified_rounded
                        : Icons.workspace_premium_outlined,
                    size: 15),
                label: Text(r.hasAttestation ? 'Attestation' : 'Délivrer',
                    style: const TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(
                  foregroundColor: r.hasAttestation
                      ? kGreen
                      : (r.attestationOverdue ? kRed : kNavy),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              )
            else
              Icon(
                  r.hasAttestation ? Icons.verified_rounded : Icons.pending_outlined,
                  size: 16,
                  color: r.hasAttestation ? kGreen : kTextMuted),
          ]),
        ],
      ),
    );
  }
}
