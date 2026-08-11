import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../providers/admin_exams_provider.dart';
import '../providers/ministry_exam_rows.dart';
import 'admin_exam_school_modal.dart';
import '../../../core/utils/message_erreur.dart';

// ════════════════════════════════════════════════════════════════════════════
//  VUES DE « EXAMENS NATIONAUX » — graphique, tableau, cartes, états vides.
//
//  Extraites de l'écran, qui dépassait 500 lignes en mêlant sa logique de
//  filtrage à cinq présentations distinctes. La coupure suit une couture
//  naturelle : l'écran décide QUOI montrer, ces widgets décident COMMENT.
// ════════════════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════════════════
//  L'ENTONNOIR DE LA CAMPAGNE — déclarés → déposés → admis.
//
//  Le graphe ne montrait qu'une série plate, « candidats par examen », qui ne
//  disait rien qu'un indicateur ne dise déjà. L'entonnoir, lui, LOCALISE la
//  perte : l'écart entre déclarés et déposés est un retard de dossier, encore
//  rattrapable avant la clôture ; l'écart entre déposés et admis est un
//  résultat, et ne se rattrape pas.
//
//  ── POURQUOI UNE RAMPE ET NON TROIS COULEURS ───────────────────────────────
//  Les trois séries ne sont pas trois identités : ce sont trois sous-ensembles
//  emboîtés d'une même population. L'encodage juste est donc SÉQUENTIEL — une
//  seule teinte, du clair au foncé —, et non catégoriel. Trois teintes
//  distinctes suggéreraient trois choses différentes.
//
//  Les pas sont validés (séparation à vision normale et sous déficience,
//  contraste sur la surface) et diffèrent en thème sombre : une rampe claire
//  sur fond sombre s'inverse, elle ne se retourne pas toute seule.
// ════════════════════════════════════════════════════════════════════════════

/// Les trois pas de la rampe, du plus large au plus étroit de l'entonnoir.
/// Le foncé porte « admis » : c'est le chiffre sur lequel on s'arrête.
({Color declared, Color submitted, Color admitted}) _funnelRamp(Brightness b) =>
    b == Brightness.dark
        ? (
            declared: const Color(0xFF456C97),
            submitted: const Color(0xFF7CA6D2),
            admitted: const Color(0xFFC2DBF7),
          )
        : (
            declared: const Color(0xFF7BA0C4),
            submitted: const Color(0xFF41719F),
            admitted: const Color(0xFF1E3A5F),
          );

class ExamChart extends StatelessWidget {
  const ExamChart({
    super.key,
    required this.bars,
    required this.yearLabel,
    this.byDepartment = false,
  });

  final List<ExamFunnelBar> bars;
  final String? yearLabel;

  /// Vrai quand un seul examen est sélectionné : l'axe porte alors les
  /// départements. Une barre unique par examen ne comparerait rien.
  final bool byDepartment;

  @override
  Widget build(BuildContext context) {
    final data = bars.where((b) => b.declared > 0).toList();
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
              'Aucun candidat déclaré sur ce périmètre — le graphique se '
              'remplira à mesure que les écoles inscrivent.',
              style: TextStyle(fontSize: 12.5, color: kTextMuted),
            ),
          ),
        ]),
      );
    }

    final ramp = _funnelRamp(Theme.of(context).brightness);
    // Étiquettes sur les trois séries tant qu'elles tiennent ; au-delà, la
    // seule qui compte — un nombre sur chaque colonne d'un graphe à quinze
    // départements ne se lit plus, il se traverse.
    final labelAll = data.length <= 5;
    // Largeur du GROUPE de trois colonnes, en fraction du créneau. Sans ce
    // réglage, un axe à une seule catégorie — le cas courant quand un seul
    // examen est ouvert — étale trois colonnes sur toute la largeur du
    // graphique : on ne lit plus un entonnoir, on lit un aplat.
    final groupWidth = switch (data.length) {
      1 => 0.30,
      2 => 0.45,
      <= 4 => 0.62,
      _ => 0.80,
    };
    final labels = DataLabelSettings(
      isVisible: true,
      textStyle: TextStyle(fontSize: 9.5, color: kTextMuted),
    );

    return Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: SfCartesianChart(
        title: ChartTitle(
          text: 'Déclarés → déposés → admis'
              '${byDepartment ? ' · par département' : ' · par examen'}'
              '${yearLabel != null ? ' · $yearLabel' : ''}',
          alignment: ChartAlignment.near,
          textStyle: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
        ),
        plotAreaBorderWidth: 0,
        // La légende est la seule chose qui nomme les trois pas : sans elle,
        // l'identité des séries reposerait sur la couleur seule.
        legend: Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          overflowMode: LegendItemOverflowMode.wrap,
          textStyle: TextStyle(fontSize: 11, color: kTextMuted),
        ),
        primaryXAxis: CategoryAxis(
          majorGridLines: const MajorGridLines(width: 0),
          labelStyle: TextStyle(fontSize: 10.5, color: kTextMuted),
          labelRotation: data.length > 8 ? -35 : 0,
          axisLine: AxisLine(color: kBorder),
        ),
        primaryYAxis: NumericAxis(
          majorGridLines: MajorGridLines(width: 0.5, color: kBorder),
          axisLine: const AxisLine(width: 0),
          labelStyle: TextStyle(fontSize: 10.5, color: kTextMuted),
        ),
        // Partagé : survoler un groupe donne l'entonnoir entier, donc
        // l'assiette. Un taux sans son dénominateur ne se commente pas.
        tooltipBehavior: TooltipBehavior(enable: true, shared: true),
        enableSideBySideSeriesPlacement: true,
        series: <CartesianSeries<ExamFunnelBar, String>>[
          ColumnSeries<ExamFunnelBar, String>(
            name: 'Déclarés',
            dataSource: data,
            xValueMapper: (b, _) => b.label,
            yValueMapper: (b, _) => b.declared,
            color: ramp.declared,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            width: groupWidth,
            spacing: 0.06, // le filet de surface entre deux colonnes voisines
            animationDuration: 700,
            dataLabelSettings: labelAll ? labels : const DataLabelSettings(),
          ),
          ColumnSeries<ExamFunnelBar, String>(
            name: 'Déposés',
            dataSource: data,
            xValueMapper: (b, _) => b.label,
            yValueMapper: (b, _) => b.submitted,
            color: ramp.submitted,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            width: groupWidth,
            spacing: 0.06,
            animationDuration: 700,
            dataLabelSettings: labelAll ? labels : const DataLabelSettings(),
          ),
          ColumnSeries<ExamFunnelBar, String>(
            name: 'Admis',
            dataSource: data,
            xValueMapper: (b, _) => b.label,
            yValueMapper: (b, _) => b.admitted,
            color: ramp.admitted,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            width: groupWidth,
            spacing: 0.06,
            animationDuration: 700,
            // Toujours étiquetée : c'est le chiffre sur lequel on s'arrête.
            dataLabelSettings: labels,
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
            const SizedBox(width: 20),
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
    // La ligne ouvre la fiche de l'établissement : « 12 candidats, aucune
    // transmission » appelle immédiatement « lesquels, à quel examen ».
    return InkWell(
      onTap: () => showSchoolExamModal(context, row),
      child: Container(
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
        SizedBox(
          width: 20,
          child: Icon(Icons.chevron_right_rounded, size: 16, color: kTextMuted),
        ),
      ]),
    ));
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
    return InkWell(
      onTap: () => showSchoolExamModal(context, row),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
    ));
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
          Text(messageErreur(message),
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

// ─── Relance groupée ─────────────────────────────────────────────────────────
/// Relance en une fois toutes les écoles qui n'ont rien transmis.
///
/// Le geste est adressant : il touche des chefs d'établissement réels. Il passe
/// donc par une confirmation nominative — combien d'écoles, combien de
/// candidats — parce qu'une relance envoyée par erreur ne se rappelle pas.
class ExamsRemindButton extends ConsumerStatefulWidget {
  const ExamsRemindButton({super.key, required this.schools});
  final List<MinistrySchoolExam> schools;

  @override
  ConsumerState<ExamsRemindButton> createState() => _RemindState();
}

class _RemindState extends ConsumerState<ExamsRemindButton> {
  bool _sending = false;

  Future<void> _run() async {
    final n = widget.schools.length;
    final candidates =
        widget.schools.fold<int>(0, (s, e) => s + e.candidates);
    final ok = await showAdminConfirm(
      context,
      icon: Icons.notifications_active_rounded,
      title: 'Relancer $n établissement(s) ?',
      message: 'Un avis part au chef de chacune de ces écoles : ensemble, '
          'elles ont déclaré $candidates candidat(s) sans aucune transmission '
          'à la DEC. L\'avis nomme le nombre de candidats propre à chaque '
          'établissement.',
      confirmLabel: 'Envoyer la relance',
      confirmIcon: Icons.send_rounded,
    );
    if (!ok || !mounted) return;

    setState(() => _sending = true);
    try {
      final sent = await ref
          .read(ministryExamActionsProvider)
          .remindSchools(widget.schools);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sent == 0
            ? 'Aucun chef d\'établissement enregistré sur ce périmètre : '
                'aucune relance n\'a pu être adressée.'
            : '$sent chef(s) d\'établissement relancé(s).'),
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
  Widget build(BuildContext context) => AdminPrimaryButton(
        label: 'Relancer ${widget.schools.length} école(s)',
        icon: Icons.notifications_active_rounded,
        color: kRed,
        saving: _sending,
        onTap: _run,
      );
}
