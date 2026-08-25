import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/app_shell.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/exam_sessions_admin_provider.dart';
import '../../../core/widgets/list_chrome.dart';
import '../widgets/exam_sessions_views.dart';
import 'exam_session_form_dialog.dart';
import '../../../core/utils/message_erreur.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CALENDRIER DES SESSIONS D'EXAMEN — écran du MINISTÈRE (admin_groupe).
//
//  ── LE TROU QUE CET ÉCRAN COMBLE ───────────────────────────────────────────
//  Les sessions 2025-2026 avaient été semées par une MIGRATION (0050) : à
//  l'ouverture de 2026-2027, personne n'aurait pu en créer une sans écrire du
//  SQL. Et sans session ouverte, AUCUNE école du pays n'inscrit de candidat.
//
//  ── QUI ÉCRIT ICI ──────────────────────────────────────────────────────────
//  Le calendrier vient d'un ARRÊTÉ MINISTÉRIEL : une école n'invente pas la
//  date du BET. C'est donc le MINISTÈRE qui le saisit — pas l'opérateur SaaS,
//  qui n'a ni les arrêtés ni la légitimité pour les transcrire (même décision
//  que pour le référentiel d'examens). La RLS l'autorise aux deux :
//  `exam_sessions_write = is_super_admin() OR is_admin_groupe()`.
//  ⚠️ Cet en-tête a dit « administration super_admin » jusqu'au 2026-08-12,
//  soit l'inverse de la règle en vigueur et de la place de la page dans le menu.
//  Ce qu'on saisit ici est une COPIE DE RÉFÉRENCE — la DEC reste la source.
//
//  ── FORME ──────────────────────────────────────────────────────────────────
//  Même grammaire que la page Administrateurs, la référence du projet :
//  KPI animés → graphique → barre de filtres (qui porte le bouton « + ») →
//  en-tête de résultats → tableau OU cartes. Le chrome est partagé
//  (`widgets/list_chrome.dart`) et non recopié.
// ════════════════════════════════════════════════════════════════════════════
class ExamSessionsScreen extends ConsumerWidget {
  const ExamSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      const AppShell(title: 'Calendrier des sessions', child: _Body());
}

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _search = TextEditingController();
  String _tutelle = 'toutes';
  String _status = 'tous';
  String _year = 'toutes';
  bool _isTable = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ExamSessionAdminRow> _filter(List<ExamSessionAdminRow> rows) {
    final q = _search.text.trim().toLowerCase();
    return rows.where((r) {
      if (_tutelle != 'toutes' && r.tutelle != _tutelle) return false;
      if (_status != 'tous' && r.status != _status) return false;
      if (_year != 'toutes' && r.yearLabel != _year) return false;
      if (q.isEmpty) return true;
      return r.examShortName.toLowerCase().contains(q) ||
          r.examCode.toLowerCase().contains(q) ||
          (r.yearLabel ?? '').toLowerCase().contains(q) ||
          (r.notes ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(examSessionsAdminProvider);

    return async.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const ListShimmer(),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: kRed, size: 40),
          const SizedBox(height: 12),
          Text(messageErreur(e),
              textAlign: TextAlign.center, style: TextStyle(color: kTextMuted)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => ref.invalidate(examSessionsAdminProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ]),
      ),
      data: (rows) {
        final filtered = _filter(rows);
        final years = {
          for (final r in rows)
            if (r.yearLabel != null) r.yearLabel!
        }.toList()
          ..sort((a, b) => b.compareTo(a));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KpiGrid(items: _kpis(rows)),
              const SizedBox(height: 20),
              _CandidatesChart(rows: rows),
              const SizedBox(height: 20),
              ListFilterBar(
                searchCtrl: _search,
                searchHint: 'Rechercher un examen, une année, un arrêté…',
                isTableView: _isTable,
                addLabel: 'Nouvelle session',
                addIcon: Icons.event_available_rounded,
                onSearchChange: (_) => setState(() {}),
                onToggleView: () => setState(() => _isTable = !_isTable),
                onAdd: () => showExamSessionForm(context),
                onReset: () => setState(() {
                  _search.clear();
                  _tutelle = 'toutes';
                  _status = 'tous';
                  _year = 'toutes';
                }),
                filters: [
                  ListFilterDropdown(
                    icon: Icons.account_balance_rounded,
                    label: 'Tutelle',
                    value: _tutelle,
                    items: const {
                      'toutes': 'Toutes',
                      'metp': 'METP',
                      'mepsa': 'MEPSA',
                    },
                    onChanged: (v) => setState(() => _tutelle = v),
                  ),
                  ListFilterDropdown(
                    icon: Icons.flag_rounded,
                    label: 'Statut',
                    value: _status,
                    items: const {
                      'tous': 'Tous',
                      'draft': 'Brouillon',
                      'open': 'Inscriptions ouvertes',
                      'closed': 'Clôturée',
                      'running': 'Épreuves en cours',
                      'published': 'Résultats publiés',
                      'cancelled': 'Annulée',
                    },
                    onChanged: (v) => setState(() => _status = v),
                  ),
                  ListFilterDropdown(
                    icon: Icons.calendar_month_rounded,
                    label: 'Année',
                    value: _year,
                    items: {
                      'toutes': 'Toutes',
                      for (final y in years) y: y,
                    },
                    onChanged: (v) => setState(() => _year = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListResultHeader(
                  total: rows.length,
                  filtered: filtered.length,
                  noun: 'session'),
              const SizedBox(height: 12),
              if (_isTable)
                SessionsTableView(
                    rows: filtered, onEdit: _edit, onDelete: _delete)
              else
                SessionsCardGrid(
                    rows: filtered, onEdit: _edit, onDelete: _delete),
            ],
          ),
        );
      },
    );
  }

  List<KpiData> _kpis(List<ExamSessionAdminRow> rows) {
    final n = rows.length;
    final open = rows.where((r) => r.isOpen).length;
    final candidates =
        rows.fold<int>(0, (s, r) => s + r.candidateCount);
    final incomplete = rows.where((r) => r.missingDates).length;
    final metp = rows.where((r) => r.tutelle == 'metp').length;

    // L'échéance la plus proche parmi les sessions ouvertes : c'est la seule
    // information irrattrapable du module (clôture = année perdue pour un
    // candidat oublié). Elle mérite sa propre carte.
    final upcoming = rows
        .where((r) => r.isOpen)
        .map(daysToClose)
        .whereType<int>()
        .where((d) => d >= 0)
        .fold<int?>(null, (min, d) => min == null || d < min ? d : min);

    return [
      KpiData(
        label: 'Sessions',
        value: '$n',
        sub: '$open ouverte(s) · ${n - open} autre(s)',
        icon: Icons.event_note_rounded,
        color: kNavy,
        progressValue: n > 0 ? open / n : 0,
        trend: n > 0 ? '${(open * 100 / n).round()}% ouvertes' : '—',
      ),
      KpiData(
        label: 'Inscriptions ouvertes',
        value: '$open',
        sub: open > 0 ? 'les écoles peuvent inscrire' : 'aucune école ne peut inscrire',
        icon: Icons.how_to_reg_rounded,
        color: open > 0 ? kGreen : kRed,
        progressValue: n > 0 ? open / n : 0,
        trend: open > 0 ? '✅ Opérationnel' : '⚠ Bloqué',
        trendUp: open > 0,
      ),
      KpiData(
        label: 'Prochaine clôture',
        value: upcoming == null ? '—' : (upcoming == 0 ? "Aujourd'hui" : '$upcoming j'),
        sub: upcoming == null
            ? 'aucune échéance en cours'
            : 'après, plus aucun ajout possible',
        icon: Icons.hourglass_bottom_rounded,
        color: upcoming == null
            ? kTextMuted
            : (upcoming <= 15 ? kRed : (upcoming <= 30 ? kListOrange : kGreen)),
        trend: upcoming == null ? '—' : (upcoming <= 15 ? '⚠ Urgent' : 'Sous contrôle'),
        trendUp: upcoming == null || upcoming > 15,
        progressValue: upcoming == null ? null : (1 - (upcoming / 90)).clamp(0.0, 1.0),
      ),
      KpiData(
        label: 'Candidats déclarés',
        value: '$candidates',
        sub: 'toutes écoles confondues',
        icon: Icons.groups_rounded,
        color: kListPurple,
        trend: candidates > 0 ? 'en préparation' : 'aucun',
        trendUp: candidates > 0,
        progressValue: candidates > 0 ? 1 : 0,
      ),
      KpiData(
        label: 'Dates à compléter',
        value: '$incomplete',
        // Pas une erreur : l'arrêté ouvre souvent les inscriptions AVANT de
        // publier le calendrier des épreuves (cas réel de CAP et CQP).
        sub: incomplete > 0 ? 'épreuves non publiées' : '✅ calendrier complet',
        icon: Icons.event_busy_rounded,
        color: incomplete > 0 ? kListOrange : kGreen,
        progressValue: n > 0 ? (n - incomplete) / n : 1,
        trend: incomplete > 0 ? 'à compléter' : '✅ OK',
        trendUp: incomplete == 0,
      ),
      KpiData(
        label: 'Répartition',
        value: '$metp',
        sub: 'METP · ${n - metp} MEPSA',
        icon: Icons.account_balance_rounded,
        color: kAccent,
        progressValue: n > 0 ? metp / n : 0,
        trend: n > 0 ? '${(metp * 100 / n).round()}% technique' : '—',
      ),
    ];
  }

  void _edit(ExamSessionAdminRow r) => showExamSessionForm(context, existing: r);

  Future<void> _delete(ExamSessionAdminRow r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Supprimer la session ${r.examShortName} ?',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
        content: Text(
          'Elle disparaîtra de toutes les écoles à la prochaine synchronisation.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: kRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteExamSession(ref.read(supabaseClientProvider), r.id);
      ref.invalidate(examSessionsAdminProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

/// Candidats par examen. ⚠️ Piège Syncfusion du projet : `CategoryAxis` en X
/// (String) et `NumericAxis` en Y (num). Inverser plante à l'exécution
/// (« String is not a subtype of num »).
class _CandidatesChart extends StatelessWidget {
  const _CandidatesChart({required this.rows});
  final List<ExamSessionAdminRow> rows;

  @override
  Widget build(BuildContext context) {
    // Une seule année à la fois : empiler 2025-2026 et 2024-2025 sur le même
    // libellé d'examen produirait deux colonnes muettes côte à côte.
    final years = rows.map((r) => r.yearLabel).whereType<String>().toList()
      ..sort();
    final latest = years.isEmpty ? null : years.last;
    final data = rows
        .where((r) => r.yearLabel == latest && r.candidateCount > 0)
        .toList()
      ..sort((a, b) => b.candidateCount.compareTo(a.candidateCount));

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
              'Aucun candidat déclaré${latest != null ? ' pour $latest' : ''} — '
              'le graphique se remplira à mesure que les écoles inscrivent.',
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
          text: 'Candidats par examen${latest != null ? ' · $latest' : ''}',
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
        series: <CartesianSeries<ExamSessionAdminRow, String>>[
          ColumnSeries<ExamSessionAdminRow, String>(
            name: 'Candidats',
            dataSource: data,
            xValueMapper: (r, _) => r.examShortName,
            yValueMapper: (r, _) => r.candidateCount,
            pointColorMapper: (r, _) => sessionTone(r.status).$1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            // `width` est une FRACTION du créneau de catégorie : avec une seule
            // barre, 0.55 lui donne 55 % du graphique entier — un pavé. On la
            // rétrécit quand les points sont rares, sinon les colonnes filent.
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
