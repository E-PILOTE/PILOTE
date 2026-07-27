import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/passage_merit_provider.dart';
import '../services/passage_merit_pdf_service.dart';
import 'merit_error_view.dart';
import 'merit_passage_table.dart';
import 'merit_podium.dart';
import 'student_dossier_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MEILLEURS ÉLÈVES DES CLASSES DE PASSAGE.
//
//  La base que la plateforme produit elle-même (cf. passage_merit_provider).
//  Trois choix commandent la lecture, et chacun est écrit à l'écran :
//    • le TRIMESTRE — une moyenne n'existe pas hors d'une période ;
//    • le NIVEAU — comparer une 6e à une Terminale n'a pas de sens ;
//    • la taille du palmarès.
//
//  La moyenne de la classe accompagne toujours celle de l'élève : 16/20 dans
//  une classe à 15 n'est pas 16/20 dans une classe à 9, et une commission de
//  bourses qui l'ignore se trompe de candidat.
// ════════════════════════════════════════════════════════════════════════════
class MeritPassageView extends ConsumerWidget {
  const MeritPassageView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(passageMeritProvider);
    final filter = ref.watch(passageFilterProvider);
    final trimesters = ref.watch(trimestersProvider).valueOrNull ?? const [];

    return async.when(
      skipLoadingOnReload: true,
      loading: () => const ListShimmer(),
      error: (e, _) => MeritErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(passageMeritProvider),
      ),
      data: (d) {
        final rows = rankPassage(d.entries, filter.topN);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Intro(scope: _scopeLabel(filter, trimesters)),
            const SizedBox(height: 18),
            KpiGrid(items: _kpis(rows, d)),
            const SizedBox(height: 20),
            if (rows.isNotEmpty) ...[
              MeritPodium(
                rows: [
                  for (final r in rows.where((r) => r.rank <= 3))
                    PodiumItem(
                      rank: r.rank,
                      fullName: r.entry.fullName,
                      schoolName: r.entry.schoolName,
                      average: r.entry.average,
                      subtitle: '${r.entry.className}'
                          '${r.entry.filiere == null ? '' : ' · ${r.entry.filiere}'}',
                      caption: r.exAequo ? 'ex æquo' : r.entry.mention,
                      exAequo: r.exAequo,
                    ),
                ],
                subtitle: 'Cliquez un élève pour ouvrir son dossier',
                onTap: (p) => _open(
                    context,
                    rows.firstWhere((r) =>
                        r.rank == p.rank && r.entry.fullName == p.fullName)),
              ),
              const SizedBox(height: 20),
            ],
            _Filters(filter: filter, trimesters: trimesters, levels: d.levels),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              const AdminEmptyState(
                icon: Icons.workspace_premium_outlined,
                title: 'Aucun élève classé sur ce périmètre',
                message: 'Le classement se construit à partir des évaluations '
                    'PUBLIÉES des classes de passage. Il apparaîtra dès que les '
                    'établissements auront publié les notes du trimestre '
                    'sélectionné.',
              )
            else ...[
              Row(children: [
                Expanded(
                  child: Text(
                      '${rows.length} élève${rows.length > 1 ? 's' : ''} classé'
                      '${rows.length > 1 ? 's' : ''} sur ${d.entries.length} '
                      'évalué${d.entries.length > 1 ? 's' : ''}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                ),
                AdminPdfButton(
                  label: 'Classement officiel',
                  onTap: () => _openPdf(context, ref, rows, d,
                      _scopeLabel(filter, trimesters), filter.levelCode),
                ),
              ]),
              const SizedBox(height: 12),
              MeritPassageTable(
                  rows: rows, onTap: (r) => _open(context, r)),
            ],
            const SizedBox(height: 24),
            const _ScopeNote(),
          ],
        );
      },
    );
  }

  static String _scopeLabel(PassageFilter f, List<Trimester> trimesters) {
    final t = f.trimesterId == null
        ? 'année entière'
        : trimesters
            .where((x) => x.id == f.trimesterId)
            .map((x) => x.label)
            .firstOrNull ?? 'trimestre sélectionné';
    return f.levelCode == null ? t : '$t · niveau ${f.levelCode}';
  }

  void _openPdf(
    BuildContext context,
    WidgetRef ref,
    List<RankedPassage> rows,
    PassageData d,
    String period,
    String? levelCode,
  ) {
    final groupName = ref.read(adminDashboardProvider).valueOrNull?.groupName ??
        'Groupe scolaire';
    showPdfPreviewDialog(
      context,
      title: 'Meilleurs élèves des classes de passage',
      subtitle: period,
      pdfFileName: 'meilleurs_eleves_passage.pdf',
      build: (_) => PassageMeritPdfService.buildPdf(
        groupName: groupName,
        rows: rows,
        periodLabel: period,
        evaluatedTotal: d.entries.length,
        levelCode: levelCode,
      ),
      onDownload: () => PassageMeritPdfService.download(
        groupName: groupName,
        rows: rows,
        periodLabel: period,
        evaluatedTotal: d.entries.length,
        levelCode: levelCode,
      ),
    );
  }

  void _open(BuildContext context, RankedPassage r) {
    // Pas de bandeau de distinction ici : ce rang repose sur le contrôle
    // continu, qui n'est pas comparable entre établissements. L'afficher comme
    // une distinction nationale serait le sur-vendre.
    showStudentDossierDialog(context, r.entry.studentId);
  }

  List<KpiData> _kpis(List<RankedPassage> rows, PassageData d) {
    final best = rows.isEmpty ? null : rows.first.entry;
    final share = passageFemaleShare(rows);
    final schools = rows.map((r) => r.entry.schoolName).toSet().length;

    return [
      KpiData(
        label: 'Élèves classés',
        value: '${rows.length}',
        sub: 'sur ${d.entries.length} évalués en classe de passage',
        icon: Icons.workspace_premium_rounded,
        color: kNavy,
      ),
      KpiData(
        label: 'Meilleure moyenne',
        value: best == null ? '—' : best.average.toStringAsFixed(2),
        sub: best?.schoolName,
        icon: Icons.star_rounded,
        color: const Color(0xFFD4AF37),
      ),
      KpiData(
        label: 'Établissements représentés',
        value: '$schools',
        sub: schools > 1
            ? 'le mérite n\'est pas concentré'
            : 'un seul établissement',
        icon: Icons.account_balance_rounded,
        color: kGreen,
      ),
      KpiData(
        label: 'Part de filles',
        value: share == null ? '—' : '${share.toStringAsFixed(0)} %',
        sub: 'parité du classement',
        icon: Icons.female_rounded,
        color: const Color(0xFF7C3AED),
        progressValue: share == null ? null : share / 100,
      ),
    ];
  }
}

// ─── Bandeau d'intention ────────────────────────────────────────────────────
class _Intro extends StatelessWidget {
  const _Intro({required this.scope});
  final String scope;

  @override
  Widget build(BuildContext context) => AdminCard(
        accent: kGreen,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.workspace_premium_rounded, size: 26, color: kGreen),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Meilleurs élèves des classes de passage — $scope',
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary),
              ),
              const SizedBox(height: 5),
              Text(
                'Les classes de passage sont celles dont le passage au niveau '
                'supérieur se décide sur le travail de l\'année, et non sur une '
                'épreuve nationale. C\'est là que la plateforme calcule '
                'elle-même les moyennes : évaluations publiées, absences '
                'exclues, notes ramenées sur 20, pondération par coefficient.',
                style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.45),
              ),
            ]),
          ),
        ]),
      );
}

// ─── Filtres ────────────────────────────────────────────────────────────────
class _Filters extends ConsumerWidget {
  const _Filters({
    required this.filter,
    required this.trimesters,
    required this.levels,
  });

  final PassageFilter filter;
  final List<Trimester> trimesters;
  final List<String> levels;

  static const _kYear = '__annee__';
  static const _kAll = '__all__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(PassageFilter f) =>
        ref.read(passageFilterProvider.notifier).state = f;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.tune_rounded, size: 16, color: kTextMuted),
          const SizedBox(width: 8),
          Text('Périmètre du classement',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(
            width: 230,
            height: 40,
            child: ListFilterDropdown(
              icon: Icons.event_note_rounded,
              label: 'Période',
              value: filter.trimesterId ?? _kYear,
              // « Année entière » est un CHOIX, pas une absence de filtre : la
              // moyenne annuelle est ce qu'un conseil de fin d'année regarde.
              items: {
                _kYear: 'Année entière',
                for (final t in trimesters)
                  t.id: t.isCurrent ? '${t.label} (en cours)' : t.label,
              },
              onChanged: (v) => update(
                  filter.copyWith(trimesterId: v == _kYear ? null : v)),
            ),
          ),
          SizedBox(
            width: 190,
            height: 40,
            child: ListFilterDropdown(
              icon: Icons.stairs_rounded,
              label: 'Niveau',
              value: filter.levelCode ?? _kAll,
              items: {
                _kAll: 'Tous',
                for (final l in levels) l: l,
              },
              onChanged: (v) =>
                  update(filter.copyWith(levelCode: v == _kAll ? null : v)),
            ),
          ),
          SizedBox(
            width: 175,
            height: 40,
            child: ListFilterDropdown(
              icon: Icons.format_list_numbered_rounded,
              label: 'Taille',
              value: '${filter.topN}',
              items: const {
                '5': 'Top 5',
                '10': 'Top 10',
                '20': 'Top 20',
                '50': 'Top 50',
              },
              onChanged: (v) =>
                  update(filter.copyWith(topN: int.tryParse(v) ?? 10)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── Portée du classement ───────────────────────────────────────────────────
class _ScopeNote extends StatelessWidget {
  const _ScopeNote();

  @override
  Widget build(BuildContext context) => AdminCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AdminSectionTitle(
            'Portée de ce classement',
            icon: Icons.info_outline_rounded,
            subtitle: 'Ce qu\'il permet de décider, et ce qu\'il ne permet pas',
          ),
          const SizedBox(height: 12),
          Text(
            'Ces moyennes sont calculées par les établissements eux-mêmes. '
            'Enseignants, sujets et exigences diffèrent d\'une école à l\'autre : '
            'un même 16/20 n\'y a pas partout la même valeur. La moyenne de la '
            'classe est donc affichée à côté de chaque élève, et le classement '
            'peut être restreint à un niveau — deux précautions sans lesquelles '
            'la comparaison serait trompeuse.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            'Les classes d\'examen (CM2, 3e, Terminale) ne figurent pas ici : '
            'leur passage se joue à l\'examen d\'État, dont la plateforme '
            'transmet la liste des candidats à la DEC sans en calculer les '
            'résultats. Ces lauréats-là relèvent de l\'autre onglet.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
          ),
        ]),
      );
}
