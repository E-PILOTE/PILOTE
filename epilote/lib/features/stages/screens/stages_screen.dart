import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
// Stages dépend d'Examens par nature (l'attestation est une pièce du dossier) :
// réutiliser ses briques d'affichage est cohérent, pas un raccourci.
import '../../examens/widgets/examens_widgets.dart' show ExamErrorCard;
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/stage_actions.dart' show issueAttestation;
import '../providers/stages_provider.dart';
import '../widgets/stage_attestation_dialog.dart';
import '../widgets/stage_form_dialog.dart';
import '../widgets/stages_views.dart';

const _kSlug = 'stages';

// ════════════════════════════════════════════════════════════════════════════
//  STAGES — espace école, offline-first. Style page Administrateurs :
//  alerte (échéance irrattrapable) → KPI → graphique → filtres (avec « + ») →
//  tableau OU cartes. Le chrome est partagé (`core/widgets/list_chrome.dart`).
//
//  L'alerte « dossiers bloqués » reste AVANT tout : c'est la seule chose qui a
//  une échéance irrattrapable (clôture des inscriptions au bac).
// ════════════════════════════════════════════════════════════════════════════
class StagesScreen extends ConsumerWidget {
  const StagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const ModuleScaffold(
        slug: _kSlug,
        title: 'Stages',
        child: _Body(),
      );
}

class _Body extends ConsumerStatefulWidget {
  const _Body();

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _search = TextEditingController();
  String _status = 'tous';
  String _attest = 'toutes';
  bool _isTable = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<InternshipRow> _filter(List<InternshipRow> rows) {
    final q = _search.text.trim().toLowerCase();
    return rows.where((r) {
      if (_status != 'tous' && r.status.name != _status) return false;
      if (_attest == 'delivrees' && !r.hasAttestation) return false;
      if (_attest == 'dues' && !r.attestationOverdue) return false;
      if (q.isEmpty) return true;
      return r.studentName.toLowerCase().contains(q) ||
          (r.companyName ?? '').toLowerCase().contains(q) ||
          (r.className ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(stagesOverviewProvider);
    final canEdit = ref.watch(canProvider((slug: _kSlug, action: 'create')));

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const ListShimmer(kpiCount: 4, rowCount: 5),
      error: (e, _) => ExamErrorCard(message: '$e'),
      data: (o) {
        final filtered = _filter(o.internships);
        final convSigned = o.internships.where((i) => i.conventionSigned).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (o.blocked.isNotEmpty) ...[
                _BlockedCard(rows: o.blocked),
                const SizedBox(height: 20),
              ],
              KpiGrid(items: _kpis(o, convSigned)),
              const SizedBox(height: 20),
              StagesStatusChart(internships: o.internships),
              const SizedBox(height: 20),
              if (o.internships.isEmpty)
                _EmptyStages(canEdit: canEdit)
              else ...[
                ListFilterBar(
                  searchCtrl: _search,
                  searchHint: 'Rechercher un élève, une entreprise…',
                  isTableView: _isTable,
                  addLabel: 'Nouveau stage',
                  addIcon: Icons.add_rounded,
                  onAdd: canEdit ? () => showStageFormDialog(context) : null,
                  onSearchChange: (_) => setState(() {}),
                  onToggleView: () => setState(() => _isTable = !_isTable),
                  onReset: () => setState(() {
                    _search.clear();
                    _status = 'tous';
                    _attest = 'toutes';
                  }),
                  filters: [
                    ListFilterDropdown(
                      icon: Icons.flag_rounded,
                      label: 'Statut',
                      value: _status,
                      items: const {
                        'tous': 'Tous',
                        'prevu': 'Prévu',
                        'enCours': 'En cours',
                        'termine': 'Terminé',
                        'valide': 'Validé',
                        'interrompu': 'Interrompu',
                      },
                      onChanged: (v) => setState(() => _status = v),
                    ),
                    ListFilterDropdown(
                      icon: Icons.verified_rounded,
                      label: 'Attestation',
                      value: _attest,
                      items: const {
                        'toutes': 'Toutes',
                        'delivrees': 'Délivrées',
                        'dues': 'Dues (en retard)',
                      },
                      onChanged: (v) => setState(() => _attest = v),
                    ),
                  ],
                ),
                // Action GROUPÉE : lever d'un coup toutes les attestations dues.
                if (canEdit && o.overdue > 0) ...[
                  const SizedBox(height: 10),
                  _BulkAction(count: o.overdue, onTap: () => _bulkIssue(o)),
                ],
                const SizedBox(height: 16),
                ListResultHeader(
                    total: o.internships.length,
                    filtered: filtered.length,
                    noun: 'stage'),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  _NoMatch()
                else if (_isTable)
                  StagesTable(
                      rows: filtered,
                      canEdit: canEdit,
                      onAttestation: (r) => showAttestationDialog(context, row: r))
                else
                  StagesCards(
                      rows: filtered,
                      canEdit: canEdit,
                      onAttestation: (r) => showAttestationDialog(context, row: r)),
              ],
            ],
          ),
        );
      },
    );
  }

  List<KpiData> _kpis(StagesOverview o, int convSigned) {
    final n = o.internships.length;
    return [
      KpiData(
        label: 'Stages',
        value: '$n',
        sub: 'toutes années',
        icon: Icons.engineering_rounded,
        color: kNavy,
        progressValue: n > 0 ? 1 : 0,
        trend: '$convSigned convention(s)',
      ),
      KpiData(
        label: 'En cours',
        value: '${o.ongoing}',
        sub: 'stagiaires en entreprise',
        icon: Icons.play_circle_outline_rounded,
        color: kGreen,
        progressValue: n > 0 ? o.ongoing / n : 0,
        trend: n > 0 ? '${(o.ongoing * 100 / n).round()}%' : '—',
      ),
      KpiData(
        label: 'Attestations',
        value: '${o.attestations}',
        sub: 'délivrées',
        icon: Icons.verified_rounded,
        color: kGreen,
        progressValue: n > 0 ? o.attestations / n : 0,
        trend: n > 0 ? '${(o.attestations * 100 / n).round()}%' : '—',
      ),
      KpiData(
        label: 'Attestations dues',
        value: '${o.overdue}',
        sub: o.overdue == 0 ? '✅ rien en retard' : 'stage fini, pièce manquante',
        icon: Icons.report_problem_rounded,
        color: o.overdue == 0 ? kGreen : kRed,
        progressValue: n > 0 ? 1 - (o.overdue / n) : 1,
        trend: o.overdue == 0 ? 'à jour' : '⚠ à délivrer',
        trendUp: o.overdue == 0,
      ),
      KpiData(
        label: 'Conventions',
        value: '$convSigned',
        sub: '${n - convSigned} sans convention',
        icon: Icons.description_rounded,
        color: convSigned == n ? kGreen : kListOrange,
        progressValue: n > 0 ? convSigned / n : 0,
        trend: n > 0 ? '${(convSigned * 100 / n).round()}% signées' : '—',
        trendUp: convSigned == n,
      ),
      KpiData(
        label: 'Dossiers bloqués',
        value: '${o.blocked.length}',
        // Élèves de bac technique/pro sans attestation : dossier irrecevable.
        sub: o.blocked.isEmpty ? '✅ aucun blocage' : 'bac sans attestation',
        icon: Icons.gpp_maybe_rounded,
        color: o.blocked.isEmpty ? kGreen : kRed,
        progressValue: o.blocked.isEmpty ? 1 : 0,
        trend: o.blocked.isEmpty ? 'OK' : '⚠ irrecevable',
        trendUp: o.blocked.isEmpty,
      ),
    ];
  }

  Future<void> _bulkIssue(StagesOverview o) async {
    final due = o.internships.where((i) => i.attestationOverdue).toList();
    if (due.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Délivrer ${due.length} attestation(s)',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
        content: Text(
          'Les ${due.length} stages terminés sans attestation en recevront une, '
          'datée d\'aujourd\'hui. Vous pourrez ensuite ajuster chacune au besoin.',
          style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Annuler', style: TextStyle(color: kTextMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: kNavy),
            child: const Text('Délivrer tout'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final now = DateTime.now();
    for (final r in due) {
      await issueAttestation(r.id, issuedAt: now);
    }
    ref.invalidate(stagesOverviewProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: kGreen,
        content: Text('${due.length} attestation(s) délivrée(s).'),
      ));
    }
  }
}

// ─── Action groupée ───────────────────────────────────────────────────────────
class _BulkAction extends StatelessWidget {
  const _BulkAction({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kRed.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline_rounded, size: 18, color: kRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count attestation(s) due(s) : stage terminé, pièce manquante.',
              style: TextStyle(fontSize: 12.5, color: kTextPrimary),
            ),
          ),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.done_all_rounded, size: 16),
            label: const Text('Délivrer toutes'),
            style: FilledButton.styleFrom(
                backgroundColor: kRed, visualDensity: VisualDensity.compact),
          ),
        ]),
      );
}

/// L'alerte qui justifie le module : un dossier de bac technique/pro sans
/// attestation de stage est irrecevable. Le dire APRÈS la clôture ne sert à rien.
class _BlockedCard extends StatelessWidget {
  const _BlockedCard({required this.rows});
  final List<BlockedCandidate> rows;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kRed.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRed.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.gpp_maybe_rounded, color: kRed, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${rows.length} dossier(s) de baccalauréat bloqué(s)',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
              'L\'attestation de stage est une pièce obligatoire du dossier de '
              'baccalauréat technique et professionnel (note METP). Ces élèves '
              'sont en classe d\'examen sans attestation délivrée : leur dossier '
              'sera refusé.',
              style: TextStyle(fontSize: 12, color: kTextMuted, height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in rows)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        '${r.studentName} · ${r.className ?? '—'} · ${r.examShortName}',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        r.hasInternship ? 'attestation à délivrer' : 'aucun stage',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: r.hasInternship ? kAccent : kRed),
                      ),
                    ]),
                  ),
              ],
            ),
          ],
        ),
      );
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
          child: Text('Aucun stage ne correspond au filtre.',
              style: TextStyle(fontSize: 13, color: kTextMuted)),
        ),
      );
}

class _EmptyStages extends StatelessWidget {
  const _EmptyStages({required this.canEdit});
  final bool canEdit;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.engineering_outlined, size: 44, color: kTextMuted),
            const SizedBox(height: 14),
            Text('Aucun stage enregistré',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 8),
            Text(
              'Enregistrez les stages en entreprise de vos élèves : convention, '
              'tuteurs, évaluation et attestation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
            ),
            if (canEdit) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => showStageFormDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Enregistrer un stage'),
                style: FilledButton.styleFrom(backgroundColor: kNavy),
              ),
            ],
          ]),
        ),
      );
}
