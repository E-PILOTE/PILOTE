import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/routes.dart';
import '../../../core/widgets/admin_ui.dart';
import '../providers/admin_exams_provider.dart';
import '../providers/ministry_exam_rows.dart';

// ════════════════════════════════════════════════════════════════════════════
//  SECTION EXAMENS & STAGES DU RÉSEAU — sur le tableau de bord du ministère.
//
//  Le cockpit complet vit sur /admin/examens ; ICI on ne montre que le pouls :
//  couverture réseau, dépôts à la DEC, écoles à risque, dossiers de bac bloqués.
//  Ce sont les chiffres qu'un ministre demande en premier, donc ils remontent
//  sur l'écran d'accueil. La section s'efface entièrement pour un groupe qui
//  n'utilise pas le module (aucun candidat, aucune session, aucun stage) : pas
//  de carte vide sur les dashboards des autres groupes scolaires.
// ════════════════════════════════════════════════════════════════════════════
class AdminExamsDashboardSection extends ConsumerWidget {
  const AdminExamsDashboardSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminExamsProvider);
    final d = async.valueOrNull;

    // Rien tant qu'on n'a pas de valeur (le reste du dashboard porte déjà le
    // chargement) ; rien non plus si le groupe n'exploite pas le module.
    if (d == null) return const SizedBox.shrink();
    final used = d.totalCandidates > 0 ||
        d.sessionCount > 0 ||
        d.internshipsTotal > 0;
    if (!used) return const SizedBox.shrink();

    final rate = d.totalCandidates == 0
        ? 0
        : (d.totalComplete / d.totalCandidates * 100).round();
    final transmitted =
        d.schools.where((s) => s.transmissions > 0).length;
    final success = d.successRate;
    void open() => context.go(Routes.adminExamens);

    // ── LES SIX CHIFFRES SE LISENT DANS L'ORDRE DE LA CAMPAGNE ─────────────
    // Déclarés → complets → transmis → proclamés, puis les deux alertes. Le
    // tableau de bord montrait les transmissions et les stages mais PAS la
    // réussite : le premier chiffre qu'un ministre demande manquait à l'écran
    // d'accueil, et « Transmissions DEC : 10 » ne disait pas 10 sur combien.
    final cards = <Widget>[
      AdminStatCard(
        label: 'Candidats déclarés',
        value: '${d.totalCandidates}',
        subtitle: '${d.schoolsWithCandidates} école(s) · '
            '${d.examOptions.length} examen(s)',
        icon: Icons.workspace_premium_rounded,
        color: kNavy,
        onTap: open,
      ),
      AdminStatCard(
        label: 'Dossiers complets',
        value: '$rate%',
        subtitle: '${d.totalComplete}/${d.totalCandidates} candidats',
        icon: Icons.fact_check_rounded,
        color: kGreen,
        onTap: open,
      ),
      AdminStatCard(
        label: 'Écoles ayant transmis',
        value: '$transmitted/${d.schoolsWithCandidates}',
        subtitle: '${d.transmissionCount} dépôt(s) · '
            '${d.transmissionsAcknowledged} accusé(s)',
        icon: Icons.outbox_rounded,
        color: const Color(0xFF0EA5E9),
        onTap: open,
      ),
      // Le taux ne s'affiche JAMAIS sans son assiette, et « en attente » n'est
      // pas « 0 % » : tant que la DEC n'a rien proclamé, il n'y a pas de taux.
      AdminStatCard(
        label: 'Réussite du réseau',
        value: success == null ? '—' : '${success.toStringAsFixed(1)} %',
        subtitle: success == null
            ? 'en attente de la DEC'
            : '${d.totalAdmitted} admis / ${d.totalWithResult} connus',
        icon: Icons.emoji_events_rounded,
        color: const Color(0xFF7C3AED),
        onTap: open,
      ),
      AdminStatCard(
        label: 'Écoles à risque',
        value: '${d.schoolsAtRisk}',
        subtitle: 'candidats, rien de transmis',
        icon: Icons.warning_amber_rounded,
        color: d.schoolsAtRisk > 0 ? kRed : kTextMuted,
        onTap: open,
      ),
      AdminStatCard(
        label: 'Bacs bloqués',
        value: '${d.bacBlocked}',
        subtitle: 'stage manquant · dossier irrecevable',
        icon: Icons.block_rounded,
        color: d.bacBlocked > 0 ? kRed : kTextMuted,
        onTap: open,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: AdminCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AdminSectionTitle(
          'Examens nationaux & Stages',
          icon: Icons.workspace_premium_rounded,
          subtitle: d.yearLabel == null
              ? 'Pilotage du réseau'
              : 'Session ${d.yearLabel}',
          trailing: TextButton.icon(
            onPressed: () => context.go(Routes.adminExamens),
            icon: const Icon(Icons.open_in_new_rounded, size: 15),
            label: const Text('Cockpit'),
            style: TextButton.styleFrom(foregroundColor: kNavy),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (ctx, c) {
          // Le nombre de colonnes se déduit d'une LARGEUR MINIMALE de carte,
          // pas d'un palier d'écran. Six colonnes au-delà de 900 px donnaient,
          // sur un écran de 1280, des cartes de 140 px où le libellé et le
          // sous-titre passaient chacun sur deux lignes — la grille débordait
          // alors de 6 px. Une largeur plancher règle la cause : les colonnes
          // se retirent d'elles-mêmes avant que le texte n'étouffe.
          var cross = (c.maxWidth / 200).floor().clamp(1, 6);
          // Et une dernière rangée à moitié vide se lit comme une carte
          // manquante : à largeur égale, on préfère le plus grand nombre de
          // colonnes qui divise le lot (six cartes sur quatre colonnes → 4+2 ;
          // sur trois → deux rangées pleines).
          while (cross > 2 && cards.length % cross != 0) {
            cross--;
          }
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cross,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 196,
            ),
            itemCount: cards.length,
            itemBuilder: (_, i) => cards[i],
          );
        }),
        if (d.examOptions.isNotEmpty) ...[
          const SizedBox(height: 20),
          _ExamBars(bars: d.examOptions),
        ],
        // Les stages quittent la bande de KPI : au niveau ministériel, le
        // compteur brut est du détail de cockpit — c'est « Bacs bloqués » qui
        // appelle une décision. Il reste lisible, en une ligne.
        if (d.internshipsTotal > 0) ...[
          const SizedBox(height: 14),
          _StagesLine(
            total: d.internshipsTotal,
            attested: d.attestationsTotal,
          ),
        ],
      ]),
    ),
    );
  }
}

// ─── Stages du réseau, en une ligne ──────────────────────────────────────────
class _StagesLine extends StatelessWidget {
  const _StagesLine({required this.total, required this.attested});
  final int total;
  final int attested;

  @override
  Widget build(BuildContext context) {
    final missing = total - attested;
    return Row(children: [
      Icon(Icons.engineering_rounded, size: 15, color: kTextMuted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Stages du réseau : $total convention(s) · '
          '$attested attestation(s) délivrée(s)'
          '${missing > 0 ? ' · $missing en attente' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11.5, color: kTextMuted),
        ),
      ),
    ]);
  }
}

// ─── Candidats par examen (barres horizontales) ───────────────────────────────
class _ExamBars extends StatelessWidget {
  const _ExamBars({required this.bars});
  final List<ExamOption> bars;

  @override
  Widget build(BuildContext context) {
    final maxV = bars.fold<int>(0, (m, b) => b.candidates > m ? b.candidates : m);
    if (maxV == 0) return const SizedBox.shrink();
    // MEPSA (général) vs METP (technique/pro) : la tutelle colore la barre.
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Candidats par examen',
          style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const SizedBox(height: 12),
      for (final b in bars)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Row(children: [
            SizedBox(
              width: 74,
              child: Text(b.shortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: b.candidates / maxV),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (ctx, v, _) => Stack(children: [
                    Container(
                        height: 12,
                        color: couleurTutelle(b.tutelle).withValues(alpha: 0.10)),
                    FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: couleurTutelle(b.tutelle),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 34,
              child: Text('${b.candidates}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: couleurTutelle(b.tutelle))),
            ),
          ]),
        ),
    ]);
  }
}
