import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../navigation/providers/permissions_provider.dart';
import '../providers/exam_candidates_provider.dart';
import '../providers/exam_registration_provider.dart';
import 'exam_candidate_views.dart';

// ════════════════════════════════════════════════════════════════════════════
//  Candidats d'une session : KPI + panneau (filtres, tableau/cartes, sélection,
//  actions groupées). Les KPI passent par le chrome partagé (KpiGrid) — plus
//  d'AdminStatCard ici, pour ne pas entretenir deux systèmes de cartes.
// ════════════════════════════════════════════════════════════════════════════

class ExamKpiRow extends StatelessWidget {
  const ExamKpiRow({super.key, required this.session});
  final ExamSessionCandidates session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final n = s.candidates.length;
    final rate = s.successRate;
    return KpiGrid(items: [
      KpiData(
        label: 'Candidats',
        value: '$n',
        sub: 'inscrits à la session',
        icon: Icons.groups_rounded,
        color: kNavy,
        progressValue: n > 0 ? 1 : 0,
      ),
      KpiData(
        label: 'Dossiers complets',
        value: '${s.complete}',
        sub: 'sur $n',
        icon: Icons.fact_check_rounded,
        color: n > 0 && s.complete == n ? kGreen : kRed,
        progressValue: n > 0 ? s.complete / n : 0,
        trend: n > 0 ? '${(s.complete * 100 / n).round()}%' : '—',
        trendUp: n > 0 && s.complete == n,
      ),
      KpiData(
        label: 'Déposés',
        value: '${s.submitted}',
        sub: 'au centre d\'examen',
        icon: Icons.upload_file_rounded,
        color: s.submitted == 0 ? kTextMuted : kGreen,
        progressValue: n > 0 ? s.submitted / n : 0,
        trend: n > 0 ? '${(s.submitted * 100 / n).round()}%' : '—',
      ),
      KpiData(
        label: 'Taux de réussite',
        // Sur les résultats CONNUS : diviser par l'effectif afficherait 0 %
        // tant que rien n'est saisi — un chiffre faux et démoralisant.
        value: rate == null ? '—' : '${rate.toStringAsFixed(0)} %',
        sub: rate == null
            ? 'aucun résultat saisi'
            : '${s.admitted} admis sur ${s.withResult}',
        icon: Icons.emoji_events_rounded,
        color: rate == null ? kTextMuted : (rate >= 50 ? kGreen : kRed),
        progressValue: rate == null ? 0 : rate / 100,
        trend: rate == null ? '—' : (rate >= 50 ? 'bon' : 'à suivre'),
        trendUp: rate != null && rate >= 50,
      ),
    ]);
  }
}

/// Panneau candidats : filtres, bascule tableau/cartes, sélection + actions
/// groupées. Il possède aussi l'en-tête de résultats et le bouton « Inscrire »
/// (via `onRegister`) — l'écran ne les affiche donc plus à côté, pas de doublon.
class ExamCandidatePanel extends ConsumerStatefulWidget {
  const ExamCandidatePanel({
    super.key,
    required this.rows,
    required this.sessionId,
    required this.examCode,
    required this.scopeLabel,
    this.onRegister,
  });

  final List<ExamCandidateRow> rows;
  final String sessionId;
  final String examCode;
  final String? scopeLabel;

  /// Non null quand une classe est sélectionnée : l'inscription se fait PAR
  /// classe (un lot est dans une classe).
  final VoidCallback? onRegister;

  @override
  ConsumerState<ExamCandidatePanel> createState() => _PanelState();
}

class _PanelState extends ConsumerState<ExamCandidatePanel> {
  final _search = TextEditingController();
  String _dossier = 'tous';
  String _result = 'tous';
  bool _isTable = true;
  final _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ExamCandidateRow> _filter(List<ExamCandidateRow> rows) {
    final q = _search.text.trim().toLowerCase();
    return rows.where((c) {
      if (_dossier == 'complet' && !c.isComplete) return false;
      if (_dossier == 'incomplet' && c.isComplete) return false;
      if (_dossier == 'depose' && !c.isSubmitted) return false;
      if (_result == 'avec' && !c.hasResult) return false;
      if (_result == 'sans' && c.hasResult) return false;
      if (q.isEmpty) return true;
      return c.fullName.toLowerCase().contains(q) ||
          (c.matricule ?? '').toLowerCase().contains(q) ||
          (c.candidateNumber ?? '').toLowerCase().contains(q) ||
          (c.className ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = ref.watch(canProvider((slug: 'examens', action: 'update')));
    final filtered = _filter(widget.rows);
    // On ne garde en sélection que des ids encore visibles (le scope a pu changer).
    final visibleIds = {for (final r in widget.rows) r.id};
    _selected.retainWhere(visibleIds.contains);

    if (widget.rows.isEmpty) return const _EmptyCandidates();

    final selectedRows =
        widget.rows.where((r) => _selected.contains(r.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListFilterBar(
          searchCtrl: _search,
          searchHint: 'Rechercher un candidat, un matricule, un n°…',
          isTableView: _isTable,
          addLabel: 'Inscrire des élèves',
          addIcon: Icons.how_to_reg_rounded,
          onAdd: widget.onRegister,
          onSearchChange: (_) => setState(() {}),
          onToggleView: () => setState(() => _isTable = !_isTable),
          onReset: () => setState(() {
            _search.clear();
            _dossier = 'tous';
            _result = 'tous';
          }),
          filters: [
            ListFilterDropdown(
              icon: Icons.fact_check_rounded,
              label: 'Dossier',
              value: _dossier,
              items: const {
                'tous': 'Tous',
                'complet': 'Complets',
                'incomplet': 'Incomplets',
                'depose': 'Déposés',
              },
              onChanged: (v) => setState(() => _dossier = v),
            ),
            ListFilterDropdown(
              icon: Icons.emoji_events_rounded,
              label: 'Résultat',
              value: _result,
              items: const {
                'tous': 'Tous',
                'avec': 'Avec résultat',
                'sans': 'Sans résultat',
              },
              onChanged: (v) => setState(() => _result = v),
            ),
          ],
        ),
        if (canEdit && selectedRows.isNotEmpty) ...[
          const SizedBox(height: 10),
          _BulkBar(
            selected: selectedRows,
            onDeposit: () => _bulkDeposit(selectedRows),
            onRemove: () => _bulkRemove(selectedRows),
            onClear: () => setState(_selected.clear),
          ),
        ],
        const SizedBox(height: 16),
        ListResultHeader(
          total: widget.rows.length,
          filtered: filtered.length,
          noun: 'candidat',
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _NoMatch()
        else if (_isTable)
          ExamCandidateTable(
            rows: filtered,
            sessionId: widget.sessionId,
            examCode: widget.examCode,
            canEdit: canEdit,
            selected: _selected,
            onToggle: (id) => setState(() =>
                _selected.contains(id) ? _selected.remove(id) : _selected.add(id)),
            onToggleAll: () => setState(() {
              final allSel = filtered.every((r) => _selected.contains(r.id));
              if (allSel) {
                _selected.removeAll(filtered.map((r) => r.id));
              } else {
                _selected.addAll(filtered.map((r) => r.id));
              }
            }),
          )
        else
          ExamCandidateCards(
            rows: filtered,
            sessionId: widget.sessionId,
            examCode: widget.examCode,
            canEdit: canEdit,
            selected: _selected,
            onToggle: (id) => setState(() =>
                _selected.contains(id) ? _selected.remove(id) : _selected.add(id)),
          ),
      ],
    );
  }

  /// Action GROUPÉE : marquer déposés les dossiers COMPLETS sélectionnés. On ne
  /// dépose jamais un dossier incomplet (la DEC le refuserait au comptoir) : les
  /// candidats non éligibles sont ignorés et signalés, pas bloquants.
  Future<void> _bulkDeposit(List<ExamCandidateRow> rows) async {
    final eligible =
        rows.where((r) => r.isComplete && !r.isSubmitted).toList();
    final skipped = rows.length - eligible.length;
    if (eligible.isEmpty) {
      _snack('Aucun dossier complet non déposé dans la sélection.', kRed);
      return;
    }
    final ok = await _confirm(
      'Marquer ${eligible.length} dossier(s) déposé(s)',
      'Ces dossiers complets seront marqués comme déposés au centre d\'examen.'
          '${skipped > 0 ? '\n\n$skipped candidat(s) ignoré(s) : dossier incomplet ou déjà déposé.' : ''}',
      'Marquer déposé(s)',
      kNavy,
    );
    if (ok != true) return;
    for (final r in eligible) {
      await submitDossier(r.id);
    }
    ref.invalidate(sessionCandidatesProvider(widget.sessionId));
    setState(_selected.clear);
    _snack('${eligible.length} dossier(s) marqué(s) déposé(s).', kGreen);
  }

  /// Action GROUPÉE : retirer les candidatures NON déposées sélectionnées.
  /// Un dossier déposé est opposable et ne se retire plus — on l'ignore.
  Future<void> _bulkRemove(List<ExamCandidateRow> rows) async {
    final eligible = rows.where((r) => !r.isSubmitted).toList();
    final skipped = rows.length - eligible.length;
    if (eligible.isEmpty) {
      _snack('Aucune candidature retirable (toutes déposées).', kRed);
      return;
    }
    final ok = await _confirm(
      'Retirer ${eligible.length} candidature(s)',
      'Les candidatures sont supprimées ; les élèves ne sont pas touchés et '
          'pourront être réinscrits.'
          '${skipped > 0 ? '\n\n$skipped ignorée(s) : dossier déposé, non retirable.' : ''}',
      'Retirer',
      kRed,
    );
    if (ok != true) return;
    for (final r in eligible) {
      await unregisterCandidate(r.id);
    }
    ref.invalidate(sessionCandidatesProvider(widget.sessionId));
    setState(_selected.clear);
    _snack('${eligible.length} candidature(s) retirée(s).', kGreen);
  }

  Future<bool?> _confirm(
          String title, String body, String action, Color tone) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary)),
          content: Text(body,
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Annuler', style: TextStyle(color: kTextMuted)),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: tone),
              child: Text(action),
            ),
          ],
        ),
      );

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }
}

// ─── Barre d'actions groupées ─────────────────────────────────────────────────
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.selected,
    required this.onDeposit,
    required this.onRemove,
    required this.onClear,
  });

  final List<ExamCandidateRow> selected;
  final VoidCallback onDeposit, onRemove, onClear;

  @override
  Widget build(BuildContext context) {
    final depositable =
        selected.where((r) => r.isComplete && !r.isSubmitted).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kNavy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNavy.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(Icons.checklist_rounded, size: 18, color: kNavy),
        const SizedBox(width: 10),
        Text('${selected.length} sélectionné(s)',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const Spacer(),
        TextButton.icon(
          onPressed: depositable > 0 ? onDeposit : null,
          icon: const Icon(Icons.upload_file_rounded, size: 16),
          label: Text('Marquer déposé(s)'
              '${depositable > 0 ? ' ($depositable)' : ''}'),
          style: TextButton.styleFrom(foregroundColor: kNavy),
        ),
        const SizedBox(width: 4),
        TextButton.icon(
          onPressed: onRemove,
          icon: const Icon(Icons.person_remove_outlined, size: 16),
          label: const Text('Retirer'),
          style: TextButton.styleFrom(foregroundColor: kRed),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded, size: 16),
          color: kTextMuted,
          tooltip: 'Vider la sélection',
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}

class _NoMatch extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Center(
          child: Text('Aucun candidat ne correspond au filtre.',
              style: TextStyle(fontSize: 13, color: kTextMuted)),
        ),
      );
}

class _EmptyCandidates extends StatelessWidget {
  const _EmptyCandidates();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Column(children: [
          Icon(Icons.person_off_outlined, size: 36, color: kTextMuted),
          const SizedBox(height: 12),
          Text('Aucun candidat',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(height: 6),
          Text('Inscrivez les élèves classe par classe.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
}
