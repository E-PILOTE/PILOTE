import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
// Stages dépend d'Examens par nature (l'attestation est une pièce du dossier) :
// réutiliser ses briques d'affichage est cohérent, pas un raccourci.
import '../../examens/widgets/examens_widgets.dart'
    show ExamErrorCard, ExamSectionLabel, formatDate;
import '../../navigation/providers/permissions_provider.dart';
import '../../navigation/widgets/module_scaffold.dart';
import '../providers/stages_provider.dart';
import '../widgets/stage_attestation_dialog.dart';
import '../widgets/stage_form_dialog.dart';

const _kSlug = 'stages';

// ════════════════════════════════════════════════════════════════════════════
//  STAGES — espace école, offline-first.
//  L'alerte « dossiers bloqués » passe AVANT la liste : c'est la seule chose
//  qui a une échéance irrattrapable (clôture des inscriptions au bac).
// ════════════════════════════════════════════════════════════════════════════
class StagesScreen extends ConsumerWidget {
  const StagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(canProvider((slug: _kSlug, action: 'create')));
    return ModuleScaffold(
      slug: _kSlug,
      title: 'Stages',
      actions: [
        if (canCreate)
          FilledButton.icon(
            onPressed: () => showStageFormDialog(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nouveau stage'),
            style: FilledButton.styleFrom(backgroundColor: kNavy),
          ),
      ],
      child: const _Body(),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(stagesOverviewProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ExamErrorCard(message: '$e'),
      data: (o) {
        final canEdit =
            ref.watch(canProvider((slug: _kSlug, action: 'create')));
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (o.blocked.isNotEmpty) ...[
              _BlockedCard(rows: o.blocked),
              const SizedBox(height: 20),
            ],
            _Kpis(overview: o),
            const SizedBox(height: 24),
            if (o.internships.isEmpty)
              _EmptyStages(canEdit: canEdit)
            else ...[
              ExamSectionLabel('Stages',
                  trailing: '${o.internships.length} stage(s)'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  children: [
                    for (final r in o.internships)
                      _StageRow(row: r, canEdit: canEdit),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.overview});
  final StagesOverview overview;

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final cards = <(IconData, String, String, Color, String?)>[
      (Icons.engineering_rounded, 'Stages', '${o.internships.length}', kNavy,
          'toutes années'),
      (Icons.play_circle_outline_rounded, 'En cours', '${o.ongoing}', kGreen,
          'stagiaires en entreprise'),
      (
        Icons.verified_rounded,
        'Attestations',
        '${o.attestations}',
        kGreen,
        'délivrées'
      ),
      (
        Icons.report_problem_rounded,
        'Attestations dues',
        '${o.overdue}',
        o.overdue == 0 ? kTextMuted : kRed,
        o.overdue == 0 ? 'rien en retard' : 'stage fini, pièce manquante',
      ),
    ];

    return LayoutBuilder(builder: (ctx, cns) {
      final w = cns.maxWidth;
      final cols = w >= 920 ? 4 : (w >= 620 ? 2 : 1);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 176,
        ),
        itemCount: cards.length,
        itemBuilder: (_, i) {
          final (icon, label, value, color, sub) = cards[i];
          return AdminStatCard(
              label: label, value: value, icon: icon, color: color, subtitle: sub);
        },
      );
    });
  }
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
                      // Distinguer « stage fait, attestation oubliée » de
                      // « aucun stage » : ce n'est pas la même action.
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

class _StageRow extends StatelessWidget {
  const _StageRow({required this.row, required this.canEdit});
  final InternshipRow row;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final r = row;
    final tone = switch (r.status) {
      InternshipStatus.enCours => kGreen,
      InternshipStatus.valide => kGreen,
      InternshipStatus.interrompu => kRed,
      InternshipStatus.termine => kNavy,
      InternshipStatus.prevu => kTextMuted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: kBorder.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.studentName,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              Text(
                '${r.className ?? '—'} · ${r.companyName ?? 'entreprise non renseignée'}',
                style: TextStyle(fontSize: 11.5, color: kTextMuted),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            r.startDate == null
                ? '—'
                : '${formatDate(r.startDate)} → ${formatDate(r.endDate)}',
            style: TextStyle(fontSize: 11.5, color: kTextMuted),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(r.status.label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: tone)),
        ),
        const SizedBox(width: 8),
        // L'attestation n'est plus un simple voyant : c'est le bouton qui la
        // délivre. Le module signalait un blocage sans offrir de le lever.
        if (!canEdit)
          _AttestationBadge(row: r)
        else
          IconButton(
            onPressed: () => showAttestationDialog(context, row: r),
            icon: Icon(
              r.hasAttestation
                  ? Icons.verified_rounded
                  : (r.attestationOverdue
                      ? Icons.error_outline_rounded
                      : Icons.workspace_premium_outlined),
              size: 18,
            ),
            color: r.hasAttestation
                ? kGreen
                : (r.attestationOverdue ? kRed : kTextMuted),
            tooltip: r.hasAttestation
                ? 'Attestation délivrée'
                : (r.attestationOverdue
                    ? 'Stage terminé — attestation à délivrer'
                    : 'Délivrer l\'attestation'),
            visualDensity: VisualDensity.compact,
          ),
      ]),
    );
  }
}

/// Voyant seul, pour qui n'a pas le droit d'écrire.
class _AttestationBadge extends StatelessWidget {
  const _AttestationBadge({required this.row});
  final InternshipRow row;

  @override
  Widget build(BuildContext context) {
    if (row.hasAttestation) {
      return Tooltip(
        message: 'Attestation délivrée',
        child: Icon(Icons.verified_rounded, size: 17, color: kGreen),
      );
    }
    if (row.attestationOverdue) {
      return Tooltip(
        message: 'Stage terminé mais attestation non délivrée',
        child: Icon(Icons.error_outline_rounded, size: 17, color: kRed),
      );
    }
    return const SizedBox(width: 17);
  }
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
            // Un écran vide qui n'offre pas le geste attendu est un cul-de-sac.
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
