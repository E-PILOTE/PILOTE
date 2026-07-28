import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/admin_ui.dart';
import '../../../core/widgets/list_chrome.dart';
import '../../../core/widgets/pdf_preview_dialog.dart';
import '../providers/admin_dashboard_provider.dart';
import '../providers/passage_merit_provider.dart';
import '../providers/student_dossier_provider.dart' show DossierDistinction;
import '../services/passage_merit_pdf_service.dart';
import 'merit_error_view.dart';
import 'merit_passage_table.dart';
import 'merit_podium.dart';
import 'student_dossier_dialog.dart';

// ════════════════════════════════════════════════════════════════════════════
//  MEILLEURS ÉLÈVES DES CLASSES DE PASSAGE.
//
//  La base que la plateforme produit elle-même (cf. passage_merit_provider).
//  Cinq choix commandent la lecture, et tous sont écrits à l'écran comme dans
//  le PDF — un rang sans son périmètre n'est pas opposable :
//    • le TRIMESTRE — une moyenne n'existe pas hors d'une période ;
//    • le NIVEAU — comparer une 6e à une Terminale n'a pas de sens ;
//    • le DÉPARTEMENT — une bourse départementale ne se décide pas sur un
//      classement national qu'un seul chef-lieu occupe ;
//    • la FILIÈRE — l'axe de pilotage propre à un ministère technique ;
//    • la taille du palmarès.
//
//  ⚠️ Département et filière filtrent EN BASE (migration 0064), avant la coupe
//  du classement. Les appliquer ici donnerait « les meilleurs du Niari parmi
//  les 200 meilleurs du pays ».
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
        final scope = _scopeLabel(filter, trimesters);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Intro(scope: scope),
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
                        r.rank == p.rank && r.entry.fullName == p.fullName),
                    scope),
              ),
              const SizedBox(height: 20),
            ],
            _Filters(filter: filter, trimesters: trimesters, data: d),
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
                      'évalué${d.entries.length > 1 ? 's' : ''} — $scope',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                ),
                AdminPdfButton(
                  label: 'Classement officiel',
                  onTap: () =>
                      _openPdf(context, ref, rows, d, scope, filter.levelCode),
                ),
              ]),
              const SizedBox(height: 12),
              MeritPassageTable(
                  rows: rows, onTap: (r) => _open(context, r, scope)),
            ],
            const SizedBox(height: 24),
            const _ScopeNote(),
          ],
        );
      },
    );
  }

  static String _scopeLabel(PassageFilter f, List<Trimester> trimesters) {
    final period = f.trimesterId == null
        ? 'année entière'
        : trimesters
                .where((x) => x.id == f.trimesterId)
                .map((x) => x.label)
                .firstOrNull ??
            'trimestre sélectionné';
    // Un seul endroit compose le périmètre : l'écran et le PDF ne peuvent pas
    // en donner deux versions différentes.
    return f.scopeLabel(period);
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

  /// Ouvre le dossier de l'élève en lui attachant SON rang.
  ///
  /// Le bandeau porte trois choses indissociables : le rang, le périmètre qui
  /// lui donne un sens, et la base du calcul. Ce rang repose sur le contrôle
  /// continu — le dire évite qu'un dossier imprimé ne se lise, plus tard et
  /// ailleurs, comme une distinction d'examen d'État.
  void _open(BuildContext context, RankedPassage r, String scope) {
    showStudentDossierDialog(
      context,
      r.entry.studentId,
      distinction: DossierDistinction(
        rank: r.rank,
        average: r.entry.average,
        mention: r.entry.mention,
        scope: 'classes de passage · $scope',
        basis: 'Contrôle continu, calculé par l\'établissement',
        exAequo: r.exAequo,
        classAverage: r.entry.classAverage,
      ),
    );
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
    required this.data,
  });

  final PassageFilter filter;
  final List<Trimester> trimesters;
  final PassageData data;

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
                for (final l in data.levels) l: l,
              },
              onChanged: (v) =>
                  update(filter.copyWith(levelCode: v == _kAll ? null : v)),
            ),
          ),
          // Territoire — une bourse départementale ne se décide pas sur un
          // classement national.
          if (data.departments.length > 1)
            SizedBox(
              width: 210,
              height: 40,
              child: ListFilterDropdown(
                icon: Icons.map_rounded,
                label: 'Département',
                value: filter.department ?? _kAll,
                items: {
                  _kAll: 'Tout le réseau',
                  for (final d in data.departments) d: d,
                },
                onChanged: (v) =>
                    update(filter.copyWith(department: v == _kAll ? null : v)),
              ),
            ),
          // Filière — l'axe de pilotage propre à un ministère technique.
          if (data.filieres.length > 1)
            SizedBox(
              width: 230,
              height: 40,
              child: ListFilterDropdown(
                icon: Icons.category_rounded,
                label: 'Filière',
                value: filter.filiere ?? _kAll,
                items: {
                  _kAll: 'Toutes filières',
                  for (final f in data.filieres) f: f,
                },
                onChanged: (v) =>
                    update(filter.copyWith(filiere: v == _kAll ? null : v)),
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
            'Les classes d\'examen (CM2, 3e, Terminale) ne figurent pas ici, et '
            'ne peuvent pas y figurer : leur passage se joue à l\'examen '
            'd\'État. La plateforme transmet la liste des candidats à la DEC, '
            'qui proclame en retour une liste d\'ADMIS — sans notes. « Admis » '
            'ne se classe pas : on ne départage pas soixante admis entre eux.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text(
            'Le suivi des examens d\'État — taux de réussite, admis, '
            'transmission des dossiers, par filière et par département — se lit '
            'sur la page « Examens nationaux », qui ne demande que l\'admission.',
            style: TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.5),
          ),
        ]),
      );
}
